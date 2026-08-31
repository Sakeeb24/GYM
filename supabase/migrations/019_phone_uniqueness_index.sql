-- 019_phone_uniqueness_index.sql
-- Enforces phone uniqueness on profiles at the database layer (preventing duplicate accounts/race conditions).

create unique index if not exists idx_profiles_phone_unique
  on public.profiles (phone)
  where phone is not null and phone <> '';
