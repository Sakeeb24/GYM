-- 015_production_audit_fixes.sql
-- Production hardening: unique constraints, server-side dashboard aggregation RPCs, and analytics RPCs.

-- 1. Ensure username uniqueness on profiles
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'profiles_username_key'
  ) then
    alter table public.profiles add constraint profiles_username_key unique (username);
  end if;
end $$;

-- 2. Add QR signing secret to gym_settings (server-only)
alter table public.gym_settings
  add column if not exists qr_signing_secret text;

-- 3. Consolidated Dashboard Stats RPC (Zero N+1 queries, performant single-roundtrip aggregation)
create or replace function public.get_dashboard_stats(p_gym_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_today_start timestamptz;
  v_month_start timestamptz;
  v_total_members int;
  v_checked_in_today int;
  v_expiring_members int;
  v_red_list_count int;
  v_renewals_due int;
  v_monthly_revenue_cents bigint;
  v_recent_activity jsonb;
begin
  -- Validate caller has access to p_gym_id or is service_role
  if nullif(current_setting('request.jwt.claim.gym_id', true), '') is not null and
     current_setting('request.jwt.claim.gym_id', true)::uuid <> p_gym_id and
     coalesce(current_setting('request.jwt.claim.role', true), '') <> 'service_role' then
    raise exception 'Unauthorized gym access' using errcode = '42501';
  end if;

  v_today_start := date_trunc('day', now() at time zone 'UTC');
  v_month_start := date_trunc('month', now() at time zone 'UTC');

  -- Active members
  select count(*)::int into v_total_members
  from public.members
  where gym_id = p_gym_id and status = 'active';

  -- Checked in today
  select count(*)::int into v_checked_in_today
  from public.attendance
  where gym_id = p_gym_id and check_in_at >= v_today_start;

  -- Expiring in next 7 days
  select count(*)::int into v_expiring_members
  from public.memberships
  where gym_id = p_gym_id
    and status = 'active'
    and expires_at is not null
    and expires_at >= now()
    and expires_at <= (now() + interval '7 days');

  -- Open Red List cases
  select count(*)::int into v_red_list_count
  from public.no_show_cases
  where gym_id = p_gym_id and status = 'open';

  -- Pending renewals
  select count(*)::int into v_renewals_due
  from public.renewal_orders
  where gym_id = p_gym_id and status = 'pending';

  -- Month-to-date revenue
  select coalesce(sum(amount_cents), 0)::bigint into v_monthly_revenue_cents
  from public.payments
  where gym_id = p_gym_id
    and status = 'succeeded'
    and created_at >= v_month_start;

  -- Recent check-in activity (last 5)
  select coalesce(jsonb_agg(act), '[]'::jsonb) into v_recent_activity
  from (
    select
      a.id,
      a.check_in_at,
      a.source,
      coalesce(m.full_name, 'Member') as member_name,
      coalesce(m.member_number, '—') as member_number
    from public.attendance a
    left join public.members m on m.id = a.member_id
    where a.gym_id = p_gym_id
    order by a.check_in_at desc
    limit 5
  ) act;

  return jsonb_build_object(
    'total_members', coalesce(v_total_members, 0),
    'checked_in_today', coalesce(v_checked_in_today, 0),
    'expiring_members', coalesce(v_expiring_members, 0),
    'red_list_count', coalesce(v_red_list_count, 0),
    'renewals_due', coalesce(v_renewals_due, 0),
    'monthly_revenue_cents', coalesce(v_monthly_revenue_cents, 0),
    'recent_activity', coalesce(v_recent_activity, '[]'::jsonb)
  );
end;
$$;

-- 4. Analytics Aggregation RPC (Calculates real attendance volume & hour breakdown)
create or replace function public.get_analytics_trends(p_gym_id uuid, p_days int default 30)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_start_date timestamptz;
  v_daily_trend jsonb;
  v_hourly_dist jsonb;
  v_total_checkins int;
  v_active_members int;
  v_retention_rate numeric;
begin
  v_start_date := date_trunc('day', now() - (coalesce(p_days, 30) || ' days')::interval);

  -- Daily check-in volume
  select coalesce(jsonb_agg(day_stat order by day_stat.check_date), '[]'::jsonb) into v_daily_trend
  from (
    select
      to_char(date_trunc('day', check_in_at), 'YYYY-MM-DD') as check_date,
      count(*)::int as count
    from public.attendance
    where gym_id = p_gym_id and check_in_at >= v_start_date
    group by date_trunc('day', check_in_at)
  ) day_stat;

  -- Hourly distribution for peak hours
  select coalesce(jsonb_agg(h_stat order by h_stat.hour), '[]'::jsonb) into v_hourly_dist
  from (
    select
      extract(hour from check_in_at)::int as hour,
      count(*)::int as count
    from public.attendance
    where gym_id = p_gym_id and check_in_at >= v_start_date
    group by extract(hour from check_in_at)
  ) h_stat;

  -- Summary counts
  select count(*)::int into v_total_checkins
  from public.attendance
  where gym_id = p_gym_id and check_in_at >= v_start_date;

  select count(*)::int into v_active_members
  from public.members
  where gym_id = p_gym_id and status = 'active';

  -- Approximate retention rate: active members / (active + canceled/expired in period)
  select case
    when (count(*) filter (where status = 'active') + count(*) filter (where status in ('canceled', 'expired'))) > 0 then
      round((count(*) filter (where status = 'active')::numeric /
             (count(*) filter (where status = 'active') + count(*) filter (where status in ('canceled', 'expired')))::numeric) * 100.0, 1)
    else 100.0
  end into v_retention_rate
  from public.memberships
  where gym_id = p_gym_id;

  return jsonb_build_object(
    'total_checkins', coalesce(v_total_checkins, 0),
    'active_members', coalesce(v_active_members, 0),
    'retention_rate', coalesce(v_retention_rate, 100.0),
    'daily_trend', coalesce(v_daily_trend, '[]'::jsonb),
    'hourly_distribution', coalesce(v_hourly_dist, '[]'::jsonb)
  );
end;
$$;

-- Grant execution conditionally if roles exist
do $$
begin
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    grant execute on function public.get_dashboard_stats(uuid) to authenticated;
    grant execute on function public.get_analytics_trends(uuid, int) to authenticated;
  end if;
  if exists (select 1 from pg_roles where rolname = 'service_role') then
    grant execute on function public.get_dashboard_stats(uuid) to service_role;
    grant execute on function public.get_analytics_trends(uuid, int) to service_role;
  end if;
end $$;
