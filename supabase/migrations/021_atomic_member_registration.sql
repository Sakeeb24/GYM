-- 021_atomic_member_registration.sql
-- Fixes partial-registration / stuck-token vulnerability by encapsulating all database-side
-- member registration mutations (token validation, single-use token claim, member enrollment,
-- profile upsert, member-profile linking, and default membership assignment) into one atomic
-- PostgreSQL transaction via complete_member_registration RPC.
--
-- Concurrency & Safety Guarantee:
-- If any database operation fails, PostgreSQL rolls back the entire transaction.
-- Single-use tokens claimed during the transaction revert to unconsumed state automatically.
-- Supabase Auth user deletion is the sole manual compensation step required in TypeScript.

create or replace function public.complete_member_registration(
  p_user_id uuid,
  p_full_name text,
  p_phone text,
  p_username text,
  p_email text,
  p_activation_token text,
  p_token_hash text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_token_record record;
  v_gym_id uuid;
  v_token_id uuid := null;
  v_token_type text := 'monthly';
  v_member_id uuid;
  v_existing_member record;
  v_plan_id uuid;
  v_duration_days int;
  v_parts text[];
  v_slug text;
  v_token_year int;
  v_token_month int;
  v_current_year int;
  v_current_month int;
  v_claimed_token_id uuid;
begin
  -- 1. Check if phone is already registered on another active profile
  if exists (
    select 1 from public.profiles
    where phone = p_phone and user_id <> p_user_id
  ) then
    raise exception 'PHONE_ALREADY_REGISTERED' using errcode = 'P0001';
  end if;

  -- 2. Check if username is already taken on another profile
  if exists (
    select 1 from public.profiles
    where username = p_username and user_id <> p_user_id
  ) then
    raise exception 'USERNAME_ALREADY_TAKEN' using errcode = 'P0002';
  end if;

  -- 3. Activation token validation & atomic claim
  select id, gym_id, created_by, token_type, month_key, expires_at, used_at, revoked_at
  into v_token_record
  from public.member_activation_tokens
  where token_hash = p_token_hash;

  if found then
    v_token_id := v_token_record.id;
    v_token_type := coalesce(v_token_record.token_type, 'monthly');
    v_gym_id := v_token_record.gym_id;

    if v_token_record.revoked_at is not null then
      raise exception 'TOKEN_REVOKED' using errcode = 'P0003';
    end if;

    if v_token_type = 'single_use' and v_token_record.used_at is not null then
      raise exception 'TOKEN_ALREADY_USED' using errcode = 'P0004';
    end if;

    if v_token_record.expires_at <= now() then
      raise exception 'TOKEN_EXPIRED' using errcode = 'P0005';
    end if;

    -- Atomic consumption for single_use token
    if v_token_type = 'single_use' then
      update public.member_activation_tokens
      set used_at = now(),
          updated_at = now()
      where id = v_token_id
        and used_at is null
        and revoked_at is null
        and expires_at > now()
      returning id into v_claimed_token_id;

      if v_claimed_token_id is null then
        raise exception 'TOKEN_ALREADY_USED' using errcode = 'P0004';
      end if;
    end if;

  elsif starts_with(p_activation_token, 'act_') then
    -- Legacy/Deterministic monthly token fallback: act_<slug>_<year>_<month>
    v_parts := string_to_array(p_activation_token, '_');
    if array_length(v_parts, 1) >= 4 then
      v_slug := array_to_string(v_parts[2:array_length(v_parts, 1) - 2], '_');

      -- Safe numeric validation before casting to integer to prevent 22P02 exceptions
      if v_parts[array_length(v_parts, 1) - 1] ~ '^[0-9]{4}$' and v_parts[array_length(v_parts, 1)] ~ '^[0-9]{1,2}$' then
        v_token_year := v_parts[array_length(v_parts, 1) - 1]::int;
        v_token_month := v_parts[array_length(v_parts, 1)]::int;

        v_current_year := extract(year from now() at time zone 'UTC')::int;
        v_current_month := extract(month from now() at time zone 'UTC')::int;

        if v_token_year < v_current_year or (v_token_year = v_current_year and v_token_month < v_current_month) then
          raise exception 'TOKEN_EXPIRED' using errcode = 'P0005';
        elsif v_token_year <> v_current_year or v_token_month <> v_current_month then
          raise exception 'TOKEN_INVALID_MONTH' using errcode = 'P0006';
        end if;
      else
        raise exception 'TOKEN_INVALID' using errcode = 'P0007';
      end if;

      select id into v_gym_id
      from public.gyms
      where slug = v_slug and is_active = true;

      if v_gym_id is null then
        raise exception 'TOKEN_INVALID' using errcode = 'P0007';
      end if;
      v_token_type := 'monthly';
    else
      raise exception 'TOKEN_INVALID' using errcode = 'P0007';
    end if;
  else
    raise exception 'TOKEN_INVALID' using errcode = 'P0007';
  end if;

  -- 4. Resolve or create member row for this gym + phone
  select id, gym_id, profile_id, full_name
  into v_existing_member
  from public.members
  where gym_id = v_gym_id and phone = p_phone;

  if found then
    if v_existing_member.profile_id is not null and v_existing_member.profile_id <> p_user_id then
      raise exception 'PHONE_ALREADY_REGISTERED' using errcode = 'P0001';
    end if;
    v_member_id := v_existing_member.id;
  else
    insert into public.members (
      gym_id,
      member_number,
      full_name,
      phone,
      status
    ) values (
      v_gym_id,
      'M-' || floor(1000 + random() * 9000)::text,
      trim(p_full_name),
      p_phone,
      'active'
    )
    returning id into v_member_id;
  end if;

  -- 5. Upsert profile
  insert into public.profiles (
    user_id,
    gym_id,
    username,
    full_name,
    phone,
    email,
    role,
    status,
    phone_verified,
    updated_at
  ) values (
    p_user_id,
    v_gym_id,
    p_username,
    trim(p_full_name),
    p_phone,
    p_email,
    'member',
    'active',
    true,
    now()
  )
  on conflict (user_id) do update set
    gym_id = excluded.gym_id,
    username = excluded.username,
    full_name = excluded.full_name,
    phone = excluded.phone,
    email = excluded.email,
    role = excluded.role,
    status = excluded.status,
    phone_verified = excluded.phone_verified,
    updated_at = now();

  -- 5b. Populate used_by_profile_id on single-use token now that profile exists
  if v_claimed_token_id is not null then
    update public.member_activation_tokens
    set used_by_profile_id = p_user_id
    where id = v_claimed_token_id;
  end if;

  -- 6. Link member row to profile
  update public.members
  set profile_id = p_user_id,
      status = 'active',
      updated_at = now()
  where id = v_member_id;

  -- 7. Assign default membership if none active
  if not exists (
    select 1 from public.memberships
    where member_id = v_member_id and status = 'active'
  ) then
    select id, duration_days into v_plan_id, v_duration_days
    from public.membership_plans
    where gym_id = v_gym_id and is_active = true
    limit 1;

    if v_plan_id is not null then
      insert into public.memberships (
        gym_id,
        member_id,
        plan_id,
        started_at,
        expires_at,
        status
      ) values (
        v_gym_id,
        v_member_id,
        v_plan_id,
        now(),
        now() + (coalesce(v_duration_days, 30) || ' days')::interval,
        'active'
      );
    end if;
  end if;

  return jsonb_build_object(
    'gym_id', v_gym_id,
    'member_id', v_member_id,
    'token_id', v_token_id,
    'token_type', v_token_type
  );
end;
$$;

-- Security & Privileges:
-- Only service_role can call complete_member_registration directly.
revoke all on function public.complete_member_registration(uuid, text, text, text, text, text, text) from public, anon, authenticated;
grant execute on function public.complete_member_registration(uuid, text, text, text, text, text, text) to service_role;

-- -----------------------------------------------------------------------------
-- SQL CONCURRENCY & TRANSACTION SANITY CHECK DOCUMENTATION
-- -----------------------------------------------------------------------------
-- Scenario A: Concurrent Claims on Single-Use Token
--   Session 1: calls complete_member_registration(user1, ..., token_hash)
--              -> Locks & updates member_activation_tokens (used_at = now())
--              -> Succeeds and commits.
--   Session 2: calls complete_member_registration(user2, ..., token_hash)
--              -> Attempts UPDATE WHERE used_at IS NULL
--              -> Returns 0 rows -> Raises 'TOKEN_ALREADY_USED' (P0004).
--              -> Transaction rolls back completely.
--
-- Scenario B: Database Error After Single-Use Token Claim
--   Session 1: calls complete_member_registration(...)
--              -> Updates member_activation_tokens (in-flight transaction)
--              -> Subsequent step raises an exception (e.g. duplicate constraint)
--              -> PostgreSQL rolls back the entire transaction.
--              -> member_activation_tokens.used_at remains NULL.
--              -> Token is NOT permanently consumed.
-- -----------------------------------------------------------------------------
