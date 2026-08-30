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
