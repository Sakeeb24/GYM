-- 011_security_and_rls_hardening.sql
-- Hardens RLS across all tables: replaces overly broad "FOR ALL" policies with
-- fine-grained role-based policies (owner, front_desk, trainer, member),
-- secures gyms and gym_settings tables, and fixes the handle_new_user trigger.

-- 1. Helper function to read the user role
create or replace function public.app_role()
returns text
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  claim_role text;
begin
  claim_role := nullif(current_setting('request.jwt.claim.role', true), '');
  if claim_role is not null then
    return claim_role;
  end if;
  select role into claim_role from profiles where user_id = auth.uid() limit 1;
  return coalesce(claim_role, 'member');
end;
$$;

-- 2. Helper function to read the member_id for the current user in this gym
create or replace function public.member_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select id from members
  where profile_id = auth.uid()
    and (gym_id = public.gym_id() or public.gym_id() is null)
  limit 1;
$$;

-- 3. Fix handle_new_user trigger to safely handle users without gym_id (e.g. OTP intermediate users)
create or replace function handle_new_user()
returns trigger
language plpgsql
security definer
as $$
declare
  v_gym_id uuid;
  v_role text;
begin
  v_gym_id := nullif(new.app_metadata ->> 'gym_id', '')::uuid;
  if v_gym_id is null then
    -- Safe return for intermediate/unprovisioned auth users
    return new;
  end if;
  v_role := coalesce(new.app_metadata ->> 'role', 'member');

  insert into profiles (user_id, gym_id, full_name, email, phone, role)
  values (
    new.id,
    v_gym_id,
    new.raw_user_meta_data ->> 'full_name',
    new.email,
    new.phone,
    v_role
  )
  on conflict (user_id) do update set
    gym_id = excluded.gym_id,
    full_name = coalesce(excluded.full_name, profiles.full_name),
    phone = coalesce(excluded.phone, profiles.phone),
    role = excluded.role,
    updated_at = now();

  return new;
end;
$$;

-- 4. Enable RLS on gyms and gym_settings
alter table gyms enable row level security;
drop policy if exists "gyms read public or tenant" on gyms;
drop policy if exists "gyms update owner" on gyms;

create policy "gyms read public or tenant"
  on gyms for select
  using (is_active = true or id = public.gym_id());

create policy "gyms update owner"
  on gyms for update
  using (id = public.gym_id() and public.app_role() = 'owner')
  with check (id = public.gym_id() and public.app_role() = 'owner');

alter table gym_settings enable row level security;
drop policy if exists "gym_settings read staff" on gym_settings;
drop policy if exists "gym_settings update owner" on gym_settings;

create policy "gym_settings read staff"
  on gym_settings for select
  using (gym_id = public.gym_id());

create policy "gym_settings update owner"
  on gym_settings for update
  using (gym_id = public.gym_id() and public.app_role() = 'owner')
  with check (gym_id = public.gym_id() and public.app_role() = 'owner');

-- 5. Hardened RLS for members
drop policy if exists "members tenant isolation" on members;
drop policy if exists "members select own via profile" on members;
drop policy if exists "members select" on members;
drop policy if exists "members insert staff" on members;
drop policy if exists "members update" on members;
drop policy if exists "members delete owner" on members;

create policy "members select"
  on members for select
  using (
    (gym_id = public.gym_id() and public.app_role() in ('owner', 'front_desk', 'trainer'))
    or profile_id = auth.uid()
  );

create policy "members insert staff"
  on members for insert
  with check (gym_id = public.gym_id() and public.app_role() in ('owner', 'front_desk'));

create policy "members update"
  on members for update
  using (
    (gym_id = public.gym_id() and public.app_role() in ('owner', 'front_desk'))
    or profile_id = auth.uid()
  )
  with check (
    (gym_id = public.gym_id() and public.app_role() in ('owner', 'front_desk'))
    or profile_id = auth.uid()
  );

create policy "members delete owner"
  on members for delete
  using (gym_id = public.gym_id() and public.app_role() = 'owner');

-- 6. Hardened RLS for memberships & plans
drop policy if exists "memberships tenant isolation" on memberships;
drop policy if exists "memberships select" on memberships;
drop policy if exists "memberships write staff" on memberships;

create policy "memberships select"
  on memberships for select
  using (
    (gym_id = public.gym_id() and public.app_role() in ('owner', 'front_desk', 'trainer'))
    or member_id = public.member_id()
  );

create policy "memberships write staff"
  on memberships for all
  using (gym_id = public.gym_id() and public.app_role() in ('owner', 'front_desk'))
  with check (gym_id = public.gym_id() and public.app_role() in ('owner', 'front_desk'));

-- 7. Hardened RLS for attendance & streaks (client-mutation denied; Edge Functions only)
drop policy if exists "attendance tenant isolation" on attendance;
drop policy if exists "attendance select" on attendance;
drop policy if exists "attendance client write denied" on attendance;

create policy "attendance select"
  on attendance for select
  using (
    (gym_id = public.gym_id() and public.app_role() in ('owner', 'front_desk', 'trainer'))
    or member_id = public.member_id()
  );

create policy "attendance client insert denied" on attendance for insert with check (false);
create policy "attendance client update denied" on attendance for update using (false);
create policy "attendance client delete denied" on attendance for delete using (false);

drop policy if exists "streaks tenant isolation" on streaks;
drop policy if exists "streaks select" on streaks;
drop policy if exists "streaks client write denied" on streaks;

create policy "streaks select"
  on streaks for select
  using (
    (gym_id = public.gym_id() and public.app_role() in ('owner', 'front_desk', 'trainer'))
    or member_id = public.member_id()
  );

create policy "streaks client insert denied" on streaks for insert with check (false);
create policy "streaks client update denied" on streaks for update using (false);
create policy "streaks client delete denied" on streaks for delete using (false);

-- 8. Hardened RLS for Red List (no_show_cases & follow_ups: staff only)
drop policy if exists "no_show tenant isolation" on no_show_cases;
drop policy if exists "no_show staff only" on no_show_cases;

create policy "no_show staff only"
  on no_show_cases for all
  using (gym_id = public.gym_id() and public.app_role() in ('owner', 'front_desk', 'trainer'))
  with check (gym_id = public.gym_id() and public.app_role() in ('owner', 'front_desk', 'trainer'));

drop policy if exists "follow_ups tenant isolation" on follow_ups;
drop policy if exists "follow_ups staff only" on follow_ups;

create policy "follow_ups staff only"
  on follow_ups for all
  using (gym_id = public.gym_id() and public.app_role() in ('owner', 'front_desk', 'trainer'))
  with check (gym_id = public.gym_id() and public.app_role() in ('owner', 'front_desk', 'trainer'));

-- 9. Hardened RLS for payments & renewal_orders
drop policy if exists "payments tenant isolation" on payments;
drop policy if exists "payments select" on payments;
drop policy if exists "payments client write denied" on payments;

create policy "payments select"
  on payments for select
  using (
    (gym_id = public.gym_id() and public.app_role() in ('owner', 'front_desk'))
    or member_id = public.member_id()
  );

create policy "payments client insert denied" on payments for insert with check (false);
create policy "payments client update denied" on payments for update using (false);
create policy "payments client delete denied" on payments for delete using (false);

drop policy if exists "renewal_orders tenant isolation" on renewal_orders;
drop policy if exists "renewal_orders select" on renewal_orders;
drop policy if exists "renewal_orders write staff" on renewal_orders;

create policy "renewal_orders select"
  on renewal_orders for select
  using (
    (gym_id = public.gym_id() and public.app_role() in ('owner', 'front_desk'))
    or member_id = public.member_id()
  );

create policy "renewal_orders write staff"
  on renewal_orders for all
  using (gym_id = public.gym_id() and public.app_role() in ('owner', 'front_desk'))
  with check (gym_id = public.gym_id() and public.app_role() in ('owner', 'front_desk'));

-- 10. Hardened RLS for notifications
drop policy if exists "notifications tenant isolation" on notifications;
drop policy if exists "notifications select" on notifications;
drop policy if exists "notifications client write denied" on notifications;

create policy "notifications select"
  on notifications for select
  using (
    (gym_id = public.gym_id() and public.app_role() in ('owner', 'front_desk'))
    or member_id = public.member_id()
  );

create policy "notifications client insert denied" on notifications for insert with check (false);
create policy "notifications client update denied" on notifications for update using (false);
create policy "notifications client delete denied" on notifications for delete using (false);
