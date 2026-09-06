-- 018_owner_onboarding.sql
-- Owner registration / gym onboarding.
-- The registerOwner Edge Function handles all owner creation server-side using
-- service_role credentials and OWNER_SETUP_SECRET env var validation.
-- No new tables are required: gyms, gym_settings, auth.users, profiles all exist.
--
-- Security invariants enforced by the Edge Function:
--   • OWNER_SETUP_SECRET validated before any DB writes.
--   • role='owner' written only by service_role — never by the Flutter anon client.
--   • Gym creation + user creation are atomic with rollback.
--   • Duplicate gym slug / username / phone return 409 before any write.
--
-- Required Supabase Edge Function environment variable (set in Supabase Dashboard
-- → Edge Functions → registerOwner → Secrets):
--   OWNER_SETUP_SECRET=<strong-random-value>
--
-- Belt-and-suspenders: deny any authenticated client from inserting into gyms.
-- Service_role bypasses RLS and is the only writer (via the Edge Function).

-- Gyms: clients may not insert directly.
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename  = 'gyms'
      and policyname = 'gyms insert denied for client'
  ) then
    execute $p$
      create policy "gyms insert denied for client"
        on public.gyms for insert with check (false)
    $p$;
  end if;
end $$;

-- Gym settings: clients may not insert directly.
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename  = 'gym_settings'
      and policyname = 'gym_settings insert denied for client'
  ) then
    execute $p$
      create policy "gym_settings insert denied for client"
        on public.gym_settings for insert with check (false)
    $p$;
  end if;
end $$;

-- Gym settings: clients may not delete directly.
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename  = 'gym_settings'
      and policyname = 'gym_settings delete denied for client'
  ) then
    execute $p$
      create policy "gym_settings delete denied for client"
        on public.gym_settings for delete using (false)
    $p$;
  end if;
end $$;
