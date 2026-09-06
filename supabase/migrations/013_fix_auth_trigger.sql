-- 013_fix_auth_trigger.sql
-- Fixes handle_new_user trigger to safely inspect raw_app_meta_data / app_metadata
-- and search_path = public, gracefully handling OTP users without gym_id.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_gym_id uuid;
  v_role text;
  v_new_json jsonb;
  v_app_meta jsonb;
  v_user_meta jsonb;
begin
  v_new_json := to_jsonb(new);
  v_app_meta := coalesce(v_new_json -> 'raw_app_meta_data', v_new_json -> 'app_metadata', '{}'::jsonb);
  v_user_meta := coalesce(v_new_json -> 'raw_user_meta_data', v_new_json -> 'user_metadata', '{}'::jsonb);

  v_gym_id := nullif(coalesce(v_app_meta ->> 'gym_id', v_user_meta ->> 'gym_id'), '')::uuid;

  if v_gym_id is null then
    -- Safe return for intermediate OTP / pre-registration users
    return new;
  end if;

  v_role := coalesce(v_app_meta ->> 'role', v_user_meta ->> 'role', 'member');

  insert into public.profiles (user_id, gym_id, full_name, email, phone, role)
  values (
    new.id,
    v_gym_id,
    coalesce(v_user_meta ->> 'full_name', v_app_meta ->> 'full_name'),
    new.email,
    new.phone,
    v_role
  )
  on conflict (user_id) do update set
    gym_id = excluded.gym_id,
    full_name = coalesce(excluded.full_name, public.profiles.full_name),
    email = coalesce(excluded.email, public.profiles.email),
    phone = coalesce(excluded.phone, public.profiles.phone),
    role = excluded.role,
    updated_at = now();

  return new;
end;
$$;
