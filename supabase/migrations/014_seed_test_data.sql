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
