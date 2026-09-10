-- 020_monthly_activation_tokens.sql
-- Enhances member_activation_tokens with monthly token lifecycle support:
-- 1. token_type ('monthly' vs 'single_use')
-- 2. month_key ('YYYY-MM')
-- 3. raw_token for deterministic / persistent retrieval
-- 4. Unique partial index to ensure exactly one active monthly QR per gym per calendar month.

alter table public.member_activation_tokens
  add column if not exists token_type text not null default 'monthly',
  add column if not exists month_key text,
  add column if not exists raw_token text;

-- Exactly one active, non-revoked monthly activation token per gym per month
create unique index if not exists idx_monthly_active_token
  on public.member_activation_tokens (gym_id, month_key)
  where token_type = 'monthly' and revoked_at is null;

-- Index for month_key lookup
create index if not exists idx_activation_tokens_month_key
  on public.member_activation_tokens (gym_id, token_type, month_key);
