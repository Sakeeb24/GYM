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
-- The Supabase `auth` schema is managed by Supabase; we add a helper here.
create function auth.gym_id()
returns uuid
language sql
stable
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
