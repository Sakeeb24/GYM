-- 017_member_activation_tokens.sql
-- Database-backed owner-generated short-lived QR activation tokens for new member onboarding.
-- Replaces SMS/phone OTP with single-use, cryptographically hashed, gym-scoped QR activation.

create table if not exists public.member_activation_tokens (
  id                  uuid primary key default gen_random_uuid(),
  gym_id              uuid not null references public.gyms(id) on delete cascade,
  created_by          uuid not null references auth.users(id) on delete cascade,
  token_hash          text not null unique,
  expires_at          timestamptz not null,
  used_at             timestamptz,
  used_by_profile_id  uuid references public.profiles(user_id) on delete set null,
  revoked_at          timestamptz,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  constraint check_activation_expires_future check (expires_at > created_at)
);

-- Performance & Lookup Indexes
create index if not exists idx_activation_tokens_gym on public.member_activation_tokens(gym_id);
create index if not exists idx_activation_tokens_hash on public.member_activation_tokens(token_hash);
create index if not exists idx_activation_tokens_expires on public.member_activation_tokens(expires_at);
create index if not exists idx_activation_tokens_used on public.member_activation_tokens(used_at);

-- Updated-at trigger
create trigger set_updated_activation_tokens
  before update on public.member_activation_tokens
  for each row execute function public.trigger_set_updated();

-- Enable Row Level Security
alter table public.member_activation_tokens enable row level security;

-- RLS: Tenant isolation. Owner & authorized staff can view tokens belonging to their own gym.
create policy "activation_tokens select gym_scoped"
  on public.member_activation_tokens for select
  using (
    gym_id = public.gym_id()
    and (select role from public.profiles where user_id = auth.uid()) in ('owner', 'front_desk')
  );

-- Direct client mutations (insert/update/delete) are forbidden; creation and atomic consumption
-- are handled strictly server-side by Edge Functions via service_role.
create policy "activation_tokens insert denied for client"
  on public.member_activation_tokens for insert with check (false);

create policy "activation_tokens update denied for client"
  on public.member_activation_tokens for update using (false);

create policy "activation_tokens delete denied for client"
  on public.member_activation_tokens for delete using (false);
