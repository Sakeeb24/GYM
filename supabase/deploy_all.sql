-- Consolidated deploy_all.sql generated from supabase/migrations/
-- Migrations included: 001_setup.sql, 002_auth_profile.sql, 003_members.sql, 004_memberships.sql, 005_attendance.sql, 006_no_show.sql, 007_followups.sql, 008_payments.sql, 009_notifications.sql, 010_audit_logs.sql, 011_username.sql, 012_security_and_rls_hardening.sql, 013_fix_auth_trigger.sql, 014_seed_test_data.sql, 015_production_audit_fixes.sql

-- ==========================================
-- File: 001_setup.sql
-- ==========================================
-- 001_setup.sql
-- Foundation: extensions, gyms, per-gym settings.
-- This engagement targets Supabase Postgres (pgcrypto + supabase-realtime provided by Supabase).

create extension if not exists "pgcrypto";

-- Shared helper: auto-update updated_at on every row update.
create or replace function trigger_set_updated()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

-- Foundation: extensions, gyms, per-gym settings.
create table gyms (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  slug       text not null unique,
  timezone   text not null default 'UTC',
  is_active  boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger set_updated before update on gyms
  for each row execute function trigger_set_updated();

-- Helper used by auth hook + RLS to read the caller's gym from the JWT claim.
-- Resides in public schema (application-owned) to satisfy Supabase security model.
create or replace function public.gym_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select nullif(current_setting('request.jwt.claim.gym_id', true), '')::uuid;
$$;

-- Per-gym configuration. Every business rule reads thresholds from here.
create table gym_settings (
  gym_id                       uuid primary key references gyms on delete cascade,
  inactivity_threshold_days    int not null default 7   check (inactivity_threshold_days >= 0),
  streak_required_consecutive  int not null default 1   check (streak_required_consecutive >= 1),
  qr_mode                      text not null default 'static' check (qr_mode in ('static','dynamic')),
  qr_session_grace_minutes     int not null default 5   check (qr_session_grace_minutes >= 0),
  reminder_windows_days        int[] not null default array[14,7,3],
  renewal_post_expiry_days     int not null default 3   check (renewal_post_expiry_days >= 0),
  notification_channels        text[] not null default array['push','email'],
  daily_summary_time           text not null default '08:00',
  stripe_secret_key            text,          -- stored server-side; never in Flutter
  created_at                   timestamptz not null default now(),
  updated_at                   timestamptz not null default now()
);

create trigger set_updated before update on gym_settings
  for each row execute function trigger_set_updated();


-- ==========================================
-- File: 002_auth_profile.sql
-- ==========================================
-- 002_auth_profile.sql
-- Identity layer: profiles (one per Supabase auth user), gym-scoped + role.
-- auth.users is provided by Supabase Auth. We add the profile table + a trigger
-- that materialises a profile from app_metadata (written by the signup edge function,
-- which authorises gym assignment server-side).

create table profiles (
  user_id   uuid primary key references auth.users on delete cascade,
  gym_id    uuid not null references gyms on delete cascade,
  full_name text,
  phone     text,
  email     text,
  avatar_url text,
  role      text not null check (role in ('owner','front_desk','trainer','member')),
  status    text not null default 'active' check (status in ('active','inactive')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_profiles_gym on profiles(gym_id);
create index idx_profiles_user on profiles(user_id);

create or replace function handle_new_user()
returns trigger
language plpgsql
security definer
as $$
begin
  insert into profiles (user_id, gym_id, full_name, email, phone, role)
  values (
    new.id,
    (new.app_metadata ->> 'gym_id')::uuid,
    new.raw_user_meta_data ->> 'full_name',
    new.email,
    new.phone,
    coalesce(new.app_metadata ->> 'role', 'member')
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- RLS: the tenant boundary.
alter table profiles enable row level security;

-- Own profile always visible to the authenticated user.
create policy "profiles select own or gym-scoped"
  on profiles for select
  using (
    user_id = auth.uid()
    or gym_id = public.gym_id()
  );

-- Profiles are created only by the auth trigger / edge functions (service_role).
-- Authenticated users may update their own profile basics.
create policy "profiles update own"
  on profiles for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- INSERT/DELETE on profiles are denied for any client role (managed by the
-- auth trigger / Edge Functions). Fine-grained role authz (who may create a
-- member vs. staff) is enforced server-side in Edge Functions (rule 10);
-- RLS here enforces tenant isolation + deny-by-default for the anon role.
create policy "profiles insert denied for client"
  on profiles for insert with check (false);
create policy "profiles delete denied for client"
  on profiles for delete using (false);

create trigger set_updated before update on profiles
  for each row execute function trigger_set_updated();


-- ==========================================
-- File: 003_members.sql
-- ==========================================
-- 003_members.sql
-- Gym member roster. A member with an auth account links to profiles.user_id.

create table members (
  id            uuid primary key default gen_random_uuid(),
  gym_id        uuid not null references gyms on delete cascade,
  profile_id    uuid unique references profiles(user_id) on delete set null,
  member_number text not null,
  full_name     text not null,
  phone         text,
  email         text,
  dob           date,
  tags          text[],
  status        text not null default 'active' check (status in ('active','inactive')),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  constraint member_unique_per_gym_number unique (gym_id, member_number)
);

create index idx_members_gym on members(gym_id);
create index idx_members_profile on members(profile_id);
create index idx_members_phone on members(gym_id, phone);
create index idx_members_status on members(gym_id, status);

alter table members enable row level security;

-- Tenant isolation: only rows in the caller's gym.
create policy "members tenant isolation"
  on members for all
  using (gym_id = public.gym_id())
  with check (gym_id = public.gym_id());

-- A member may select their own row (by profile link) even if claim is unset.
create policy "members select own via profile"
  on members for select
  using (profile_id = auth.uid());

create trigger set_updated before update on members
  for each row execute function trigger_set_updated();


-- ==========================================
-- File: 004_memberships.sql
-- ==========================================
-- 004_memberships.sql
-- Membership plans + membership instances.
-- A member has at most one ACTIVE/paused/frozen membership (partial unique index).

create table membership_plans (
  id                uuid primary key default gen_random_uuid(),
  gym_id            uuid not null references gyms on delete cascade,
  name              text not null,
  description       text,
  duration_days     int not null check (duration_days > 0),
  price_cents       int not null check (price_cents >= 0),
  currency          text not null default 'USD',
  billing_interval  text not null default 'one_time' check (billing_interval in ('one_time','monthly','annual')),
  max_checkins      int check (max_checkins >= 0),
  grace_period_days int not null default 3 check (grace_period_days >= 0),
  is_active         boolean not null default true,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  constraint plan_unique_per_gym_name unique (gym_id, name)
);
create index idx_plans_gym on membership_plans(gym_id);

create table memberships (
  id            uuid primary key default gen_random_uuid(),
  gym_id        uuid not null references gyms on delete cascade,
  member_id     uuid not null references members on delete cascade,
  plan_id       uuid not null references membership_plans on delete restrict,
  status        text not null default 'active'
                 check (status in ('active','paused','frozen','expired','canceled')),
  started_at    timestamptz not null default now(),
  expires_at    timestamptz,
  paused_at     timestamptz,
  paused_until  timestamptz,
  canceled_at   timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- One active membership per member: at most one row with these statuses.
create unique index idx_memberships_one_active
  on memberships(member_id)
  where status in ('active','paused','frozen');

create index idx_memberships_status on memberships(gym_id, status);
create index idx_memberships_expiry on memberships(gym_id, expires_at);
create index idx_memberships_member on memberships(member_id);

-- Status is derived by a single function (BUSINESS_RULES.md) so it is not
-- duplicated across Dart / TS / SQL.
create or replace function membership_status(mem memberships)
returns text
language sql
as $$
  select case
    when $1.canceled_at is not null then 'canceled'
    when $1.paused_until is not null and $1.paused_until > now() then 'paused'
    when $1.expires_at is not null and $1.expires_at <= now() then 'expired'
    when $1.expires_at is not null and $1.expires_at <= now() + interval '1 day' then 'expiring'
    else 'active'
  end;
$$;

alter table memberships enable row level security;
-- Reuse the gym-scoped helper view: we expose status via a SQL function, not a column.
create policy "memberships tenant isolation"
  on memberships for all
  using (gym_id = public.gym_id())
  with check (gym_id = public.gym_id());

create trigger set_updated before update on memberships
  for each row execute function trigger_set_updated();


-- ==========================================
-- File: 005_attendance.sql
-- ==========================================
-- 005_attendance.sql
-- QR check-in records + streak tracking.
-- Client never writes here directly; the recordAttendance edge function does.

create table attendance (
  id                uuid primary key default gen_random_uuid(),
  gym_id            uuid not null references gyms on delete cascade,
  member_id         uuid not null references members on delete cascade,
  check_in_at       timestamptz not null default now(),
  source            text not null check (source in ('qr_self','qr_assisted','manual')),
  staff_id          uuid references profiles on delete set null,
  idempotency_key   text unique,          -- dedup duplicate scans (rule 52.1)
  created_at        timestamptz not null default now()
);

create index idx_attendance_gym_member_time on attendance(gym_id, member_id, check_in_at desc);
create index idx_attendance_gym_time on attendance(gym_id, check_in_at desc);
create index idx_attendance_idempotency on attendance(idempotency_key);

create table streaks (
  member_id         uuid primary key references members on delete cascade,
  gym_id            uuid not null references gyms on delete cascade,
  current_streak    int not null default 0,
  longest_streak    int not null default 0,
  last_check_in_at  timestamptz,
  last_updated      timestamptz not null default now()
);
create index idx_streaks_gym on streaks(gym_id);

alter table attendance enable row level security;
create policy "attendance tenant isolation"
  on attendance for all
  using (gym_id = public.gym_id())
  with check (gym_id = public.gym_id());

alter table streaks enable row level security;
create policy "streaks tenant isolation"
  on streaks for all
  using (gym_id = public.gym_id())
  with check (gym_id = public.gym_id());


-- ==========================================
-- File: 006_no_show.sql
-- ==========================================
-- 006_no_show.sql
-- Inactivity detection results. One OPEN case per member (partial unique index).

create table no_show_cases (
  id             uuid primary key default gen_random_uuid(),
  gym_id         uuid not null references gyms on delete cascade,
  member_id      uuid not null references members on delete cascade,
  status         text not null default 'open'
                 check (status in ('open','in_progress','resolved','dismissed')),
  reason         text,
  assigned_to    uuid references profiles on delete set null,
  assigned_at    timestamptz,
  last_seen_at   timestamptz,        -- last attendance before inactivity
  created_at     timestamptz not null default now(),
  resolved_at    timestamptz,
  resolved_outcome text
);

-- Prevent duplicate OPEN cases for the same member (partial unique index).
create unique index if not exists idx_no_show_one_open_per_member
  on no_show_cases(gym_id, member_id)
  where status = 'open';

create index idx_no_show_gym_status_seen on no_show_cases(gym_id, status, last_seen_at);
create index idx_no_show_gym_assigned on no_show_cases(gym_id, assigned_to);

alter table no_show_cases enable row level security;
create policy "no_show tenant isolation"
  on no_show_cases for all
  using (gym_id = public.gym_id())
  with check (gym_id = public.gym_id());


-- ==========================================
-- File: 007_followups.sql
-- ==========================================
-- 007_followups.sql
-- Red List follow-up actions tied to a no-show case.

create table follow_ups (
  id              uuid primary key default gen_random_uuid(),
  gym_id          uuid not null references gyms on delete cascade,
  no_show_case_id uuid not null references no_show_cases on delete cascade,
  member_id       uuid not null references members on delete cascade,
  assigned_to     uuid references profiles on delete set null,
  status          text not null default 'open'
                 check (status in ('open','contacted','will_return','returning',
                                   'not_interested','paused','wrong_number',
                                   'no_response','resolved')),
  next_action_at  timestamptz,
  outcome         text,
  notes           text,
  created_by      uuid references profiles on delete set null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  completed_at    timestamptz
);

create index idx_followups_gym_status on follow_ups(gym_id, status);
create index idx_followups_gym_next on follow_ups(gym_id, next_action_at);
create index idx_followups_case on follow_ups(no_show_case_id);

alter table follow_ups enable row level security;
create policy "follow_ups tenant isolation"
  on follow_ups for all
  using (gym_id = public.gym_id())
  with check (gym_id = public.gym_id());

create trigger set_updated before update on follow_ups
  for each row execute function trigger_set_updated();


-- ==========================================
-- File: 008_payments.sql
-- ==========================================
-- 008_payments.sql
-- Payments + renewal orders + add-ons. Payments are NEVER trusted from the client
-- (rule 8); success is driven by the verified provider webhook.

create table renewal_orders (
  id              uuid primary key default gen_random_uuid(),
  gym_id          uuid not null references gyms on delete cascade,
  member_id       uuid not null references members on delete cascade,
  membership_id   uuid references memberships on delete set null,
  plan_id         uuid not null references membership_plans on delete restrict,
  due_at          timestamptz not null,        -- membership expiry that triggers renewal
  status          text not null default 'pending'
                 check (status in ('pending','sent','paid','failed','canceled','completed')),
  reminder_stage  text,                       -- which window already sent (idempotency)
  amount_cents    int not null check (amount_cents >= 0),
  currency        text not null default 'USD',
  idempotency_key text unique,                -- prevent duplicate campaigns
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index idx_renewal_orders_gym_status on renewal_orders(gym_id, status);
create index idx_renewal_orders_member on renewal_orders(member_id);
create index idx_renewal_orders_due on renewal_orders(gym_id, due_at);
create trigger set_updated before update on renewal_orders for each row execute function trigger_set_updated();

create table payments (
  id                uuid primary key default gen_random_uuid(),
  gym_id            uuid not null references gyms on delete cascade,
  member_id         uuid not null references members on delete cascade,
  renewal_order_id  uuid references renewal_orders on delete set null,
  provider          text not null check (provider in ('stripe','manual','cash')),
  provider_reference text unique,              -- provider charge/intent id; unique prevents dup
  amount_cents      int not null check (amount_cents >= 0),
  currency          text not null default 'USD',
  status            text not null default 'created'
                   check (status in ('created','pending','succeeded','failed','canceled','refunded','reversed')),
  idempotency_key   text unique,
  metadata          jsonb,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);
create index idx_payments_gym_status on payments(gym_id, status);
create index idx_payments_provider_ref on payments(gym_id, provider_reference);

create table add_ons (
  id          uuid primary key default gen_random_uuid(),
  gym_id      uuid not null references gyms on delete cascade,
  name        text not null,
  description text,
  price_cents int not null check (price_cents >= 0),
  unit_label  text not null default 'per_period',
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint addon_unique_per_gym_name unique (gym_id, name)
);
create index idx_addons_gym on add_ons(gym_id);

create table add_on_orders (
  id            uuid primary key default gen_random_uuid(),
  gym_id        uuid not null references gyms on delete cascade,
  member_id     uuid not null references members on delete cascade,
  add_on_id     uuid not null references add_ons on delete restrict,
  quantity      int not null check (quantity > 0),
  status        text not null default 'pending'
               check (status in ('pending','active','canceled')),
  started_at    timestamptz,
  ended_at      timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index idx_addon_orders_gym_member on add_on_orders(gym_id, member_id);

create trigger set_updated before update on payments for each row execute function trigger_set_updated();
create trigger set_updated before update on add_ons for each row execute function trigger_set_updated();
create trigger set_updated before update on add_on_orders for each row execute function trigger_set_updated();

-- RLS: all tenant-scoped, denied for client writes except via edge functions (service_role).
alter table renewal_orders enable row level security;
create policy "renewal_orders tenant isolation" on renewal_orders for all
  using (gym_id = public.gym_id()) with check (gym_id = public.gym_id());

alter table payments enable row level security;
create policy "payments tenant isolation" on payments for all
  using (gym_id = public.gym_id()) with check (gym_id = public.gym_id());

alter table add_ons enable row level security;
create policy "add_ons tenant isolation" on add_ons for all
  using (gym_id = public.gym_id()) with check (gym_id = public.gym_id());

alter table add_on_orders enable row level security;
create policy "add_on_orders tenant isolation" on add_on_orders for all
  using (gym_id = public.gym_id()) with check (gym_id = public.gym_id());


-- ==========================================
-- File: 009_notifications.sql
-- ==========================================
-- 009_notifications.sql
-- Notification queue (push/email/sms/whatsapp), respecting opt-out.

create table notifications (
  id                uuid primary key default gen_random_uuid(),
  gym_id            uuid not null references gyms on delete cascade,
  member_id         uuid references members on delete cascade,
  type              text not null
                   check (type in ('renewal_due','renewal_overdue','no_show',
                                   'payment_failed','daily_summary','welcome')),
  channel           text not null check (channel in ('push','email','sms','whatsapp')),
  status            text not null default 'queued'
                   check (status in ('queued','sent','delivered','failed','canceled')),
  subject           text,
  body              text,
  scheduled_at      timestamptz not null default now(),
  sent_at           timestamptz,
  idempotency_key   text unique,        -- prevent duplicate sends (rule 52.6)
  retry_count       int not null default 0,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);
create index idx_notifications_gym_status on notifications(gym_id, status, scheduled_at);
create index idx_notifications_member on notifications(member_id);

create table communication_preferences (
  member_id  uuid primary key references members on delete cascade,
  channel    text not null check (channel in ('email','sms','whatsapp','push')),
  opted_in   boolean not null default true,
  updated_at timestamptz not null default now()
);
create index idx_comm_prefs_member on communication_preferences(member_id);

alter table notifications enable row level security;
create policy "notifications tenant isolation" on notifications for all
  using (gym_id = public.gym_id()) with check (gym_id = public.gym_id());

alter table communication_preferences enable row level security;
create policy "comm_prefs tenant isolation" on communication_preferences for all
  using (exists (select 1 from members m where m.id = communication_preferences.member_id and m.gym_id = public.gym_id()))
  with check (exists (select 1 from members m where m.id = communication_preferences.member_id and m.gym_id = public.gym_id()));

create trigger set_updated before update on notifications for each row execute function trigger_set_updated();
create trigger set_updated before update on communication_preferences for each row execute function trigger_set_updated();


-- ==========================================
-- File: 010_audit_logs.sql
-- ==========================================
-- 010_audit_logs.sql
-- Immutable audit trail of business actions (rule 34).

create table audit_logs (
  id          uuid primary key default gen_random_uuid(),
  gym_id      uuid references gyms on delete set null,   -- null = system action
  actor_user_id uuid references profiles on delete set null,
  action      text not null,
  entity      text,
  entity_id   text,
  detail      jsonb,
  ip_address  inet,
  created_at  timestamptz not null default now()
);
-- No updated_at: audit rows are append-only.
create index idx_audit_gym_time on audit_logs(gym_id, created_at);
create index idx_audit_actor on audit_logs(actor_user_id);
create index idx_audit_action on audit_logs(action);

-- Audit rows are written only by edge functions (service_role). The authenticated
-- role can SELECT its own gym's audit (read-only) for transparency.
alter table audit_logs enable row level security;
create policy "audit_logs tenant isolation" on audit_logs for select
  using (gym_id = public.gym_id() or gym_id is null);
create policy "audit_logs no client write" on audit_logs for insert with check (false);
create policy "audit_logs no client update" on audit_logs for update using (false);
create policy "audit_logs no client delete" on audit_logs for delete using (false);

-- Helper to append an audit row from SQL (used by triggers/functions).
create or replace function audit_log(
  p_gym_id uuid, p_actor uuid, p_action text, p_entity text, p_entity_id text, p_detail jsonb default '{}'
) returns void language plpgsql as $$
begin
  insert into audit_logs(gym_id, actor_user_id, action, entity, entity_id, detail)
  values (p_gym_id, p_actor, p_action, p_entity, p_entity_id, p_detail);
end;
$$;


-- ==========================================
-- File: 011_username.sql
-- ==========================================
-- 009_username.sql
-- Adds username + phone_verified to profiles for the username+password auth flow.
-- A synthetic email ({username}@liftflow.internal) is stored in auth.users for
-- Supabase compatibility; the username column is the human-facing login identifier.

alter table profiles
  add column if not exists username       text unique,
  add column if not exists phone_verified boolean not null default false;

-- Enforce lowercase alphanumeric + underscores, 3-30 chars.
alter table profiles
  add constraint username_format
    check (username ~ '^[a-z0-9_]{3,30}$');

create unique index if not exists idx_profiles_username on profiles(username)
  where username is not null;

comment on column profiles.username       is 'Human-facing login identifier. Immutable after creation.';
comment on column profiles.phone_verified is 'True once phone OTP has been verified during registration.';


-- ==========================================
-- File: 012_security_and_rls_hardening.sql
-- ==========================================
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


-- ==========================================
-- File: 013_fix_auth_trigger.sql
-- ==========================================
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


-- ==========================================
-- File: 014_seed_test_data.sql
-- ==========================================
-- 014_seed_test_data.sql
-- Seeds default Apex Gym, membership plans, and pre-enrolled test members for end-to-end verification.

insert into public.gyms (id, name, slug)
values ('a0000000-0000-0000-0000-000000000001', 'Apex Performance Gym', 'apex-gym')
on conflict (id) do update set name = excluded.name, slug = excluded.slug;

insert into public.gym_settings (gym_id, inactivity_threshold_days, qr_session_grace_minutes, reminder_windows_days)
values ('a0000000-0000-0000-0000-000000000001', 7, 5, ARRAY[14, 7, 3])
on conflict (gym_id) do nothing;

-- Membership plans
insert into public.membership_plans (id, gym_id, name, duration_days, price_cents, billing_interval, is_active)
values
  ('b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'Monthly Unlimited', 30, 4900, 'monthly', true),
  ('b0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001', 'Annual Pro Pass', 365, 49900, 'annual', true)
on conflict (id) do nothing;

-- Pre-enrolled test members
insert into public.members (id, gym_id, member_number, full_name, phone)
values
  ('c0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'APEX-101', 'Sakeeb', '+917019707247'),
  ('c0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001', 'APEX-102', 'Alex Rivera', '+919876543210'),
  ('c0000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000001', 'APEX-103', 'Demo Athlete', '+15555550100'),
  ('c0000000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-000000000001', 'APEX-104', 'Test Athlete', '+919999999999')
on conflict (gym_id, member_number) do update set
  full_name = excluded.full_name,
  phone = excluded.phone;

-- Active memberships for the pre-enrolled test members
insert into public.memberships (id, gym_id, member_id, plan_id, started_at, expires_at, status)
values
  ('d0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', now() - interval '5 days', now() + interval '25 days', 'active'),
  ('d0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001', now() - interval '10 days', now() + interval '20 days', 'active'),
  ('d0000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000001', now() - interval '2 days', now() + interval '28 days', 'active'),
  ('d0000000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000004', 'b0000000-0000-0000-0000-000000000001', now() - interval '1 day', now() + interval '29 days', 'active')
on conflict (id) do nothing;


-- ==========================================
-- File: 015_production_audit_fixes.sql
-- ==========================================
-- 015_production_audit_fixes.sql
-- Production hardening: unique constraints, server-side dashboard aggregation RPCs, and analytics RPCs.

-- 1. Ensure username uniqueness on profiles
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'profiles_username_key'
  ) then
    alter table public.profiles add constraint profiles_username_key unique (username);
  end if;
end $$;

-- 2. Add QR signing secret to gym_settings (server-only)
alter table public.gym_settings
  add column if not exists qr_signing_secret text;

-- 3. Consolidated Dashboard Stats RPC (Zero N+1 queries, performant single-roundtrip aggregation)
create or replace function public.get_dashboard_stats(p_gym_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_today_start timestamptz;
  v_month_start timestamptz;
  v_total_members int;
  v_checked_in_today int;
  v_expiring_members int;
  v_red_list_count int;
  v_renewals_due int;
  v_monthly_revenue_cents bigint;
  v_recent_activity jsonb;
begin
  -- Validate caller has access to p_gym_id or is service_role
  if nullif(current_setting('request.jwt.claim.gym_id', true), '') is not null and
     current_setting('request.jwt.claim.gym_id', true)::uuid <> p_gym_id and
     coalesce(current_setting('request.jwt.claim.role', true), '') <> 'service_role' then
    raise exception 'Unauthorized gym access' using errcode = '42501';
  end if;

  v_today_start := date_trunc('day', now() at time zone 'UTC');
  v_month_start := date_trunc('month', now() at time zone 'UTC');

  -- Active members
  select count(*)::int into v_total_members
  from public.members
  where gym_id = p_gym_id and status = 'active';

  -- Checked in today
  select count(*)::int into v_checked_in_today
  from public.attendance
  where gym_id = p_gym_id and check_in_at >= v_today_start;

  -- Expiring in next 7 days
  select count(*)::int into v_expiring_members
  from public.memberships
  where gym_id = p_gym_id
    and status = 'active'
    and expires_at is not null
    and expires_at >= now()
    and expires_at <= (now() + interval '7 days');

  -- Open Red List cases
  select count(*)::int into v_red_list_count
  from public.no_show_cases
  where gym_id = p_gym_id and status = 'open';

  -- Pending renewals
  select count(*)::int into v_renewals_due
  from public.renewal_orders
  where gym_id = p_gym_id and status = 'pending';

  -- Month-to-date revenue
  select coalesce(sum(amount_cents), 0)::bigint into v_monthly_revenue_cents
  from public.payments
  where gym_id = p_gym_id
    and status = 'succeeded'
    and created_at >= v_month_start;

  -- Recent check-in activity (last 5)
  select coalesce(jsonb_agg(act), '[]'::jsonb) into v_recent_activity
  from (
    select
      a.id,
      a.check_in_at,
      a.source,
      coalesce(m.full_name, 'Member') as member_name,
      coalesce(m.member_number, '—') as member_number
    from public.attendance a
    left join public.members m on m.id = a.member_id
    where a.gym_id = p_gym_id
    order by a.check_in_at desc
    limit 5
  ) act;

  return jsonb_build_object(
    'total_members', coalesce(v_total_members, 0),
    'checked_in_today', coalesce(v_checked_in_today, 0),
    'expiring_members', coalesce(v_expiring_members, 0),
    'red_list_count', coalesce(v_red_list_count, 0),
    'renewals_due', coalesce(v_renewals_due, 0),
    'monthly_revenue_cents', coalesce(v_monthly_revenue_cents, 0),
    'recent_activity', coalesce(v_recent_activity, '[]'::jsonb)
  );
end;
$$;

-- 4. Analytics Aggregation RPC (Calculates real attendance volume & hour breakdown)
create or replace function public.get_analytics_trends(p_gym_id uuid, p_days int default 30)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_start_date timestamptz;
  v_daily_trend jsonb;
  v_hourly_dist jsonb;
  v_total_checkins int;
  v_active_members int;
  v_retention_rate numeric;
begin
  v_start_date := date_trunc('day', now() - (coalesce(p_days, 30) || ' days')::interval);

  -- Daily check-in volume
  select coalesce(jsonb_agg(day_stat order by day_stat.check_date), '[]'::jsonb) into v_daily_trend
  from (
    select
      to_char(date_trunc('day', check_in_at), 'YYYY-MM-DD') as check_date,
      count(*)::int as count
    from public.attendance
    where gym_id = p_gym_id and check_in_at >= v_start_date
    group by date_trunc('day', check_in_at)
  ) day_stat;

  -- Hourly distribution for peak hours
  select coalesce(jsonb_agg(h_stat order by h_stat.hour), '[]'::jsonb) into v_hourly_dist
  from (
    select
      extract(hour from check_in_at)::int as hour,
      count(*)::int as count
    from public.attendance
    where gym_id = p_gym_id and check_in_at >= v_start_date
    group by extract(hour from check_in_at)
  ) h_stat;

  -- Summary counts
  select count(*)::int into v_total_checkins
  from public.attendance
  where gym_id = p_gym_id and check_in_at >= v_start_date;

  select count(*)::int into v_active_members
  from public.members
  where gym_id = p_gym_id and status = 'active';

  -- Approximate retention rate: active members / (active + canceled/expired in period)
  select case
    when (count(*) filter (where status = 'active') + count(*) filter (where status in ('canceled', 'expired'))) > 0 then
      round((count(*) filter (where status = 'active')::numeric /
             (count(*) filter (where status = 'active') + count(*) filter (where status in ('canceled', 'expired')))::numeric) * 100.0, 1)
    else 100.0
  end into v_retention_rate
  from public.memberships
  where gym_id = p_gym_id;

  return jsonb_build_object(
    'total_checkins', coalesce(v_total_checkins, 0),
    'active_members', coalesce(v_active_members, 0),
    'retention_rate', coalesce(v_retention_rate, 100.0),
    'daily_trend', coalesce(v_daily_trend, '[]'::jsonb),
    'hourly_distribution', coalesce(v_hourly_dist, '[]'::jsonb)
  );
end;
$$;

-- Grant execution conditionally if roles exist
do $$
begin
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    grant execute on function public.get_dashboard_stats(uuid) to authenticated;
    grant execute on function public.get_analytics_trends(uuid, int) to authenticated;
  end if;
  if exists (select 1 from pg_roles where rolname = 'service_role') then
    grant execute on function public.get_dashboard_stats(uuid) to service_role;
    grant execute on function public.get_analytics_trends(uuid, int) to service_role;
  end if;
end $$;


