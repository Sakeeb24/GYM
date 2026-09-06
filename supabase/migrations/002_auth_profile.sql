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
