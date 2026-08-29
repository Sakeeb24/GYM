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
