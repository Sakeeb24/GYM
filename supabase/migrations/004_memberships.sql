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
