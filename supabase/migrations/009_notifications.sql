-- 009_notifications.sql
-- Notification queue (push/email/sms/whatsapp), respecting opt-out.

create table notifications (
  id                uuid primary key default gen_random_uuid(),
  gym_id            uuid not null references gyms on delete cascade,
  member_id         uuid references members on delete cascade,
  type              text not null
                   check (type in ('renewal_due','renewal_overdue','no_show',
                                   'payment_failed','daily_summary','welcome')),
  channel           text not null check (channel in ('push','email','sms','whatsapp')),
  status            text not null default 'queued'
                   check (status in ('queued','sent','delivered','failed','canceled')),
  subject           text,
  body              text,
  scheduled_at      timestamptz not null default now(),
  sent_at           timestamptz,
  idempotency_key   text unique,        -- prevent duplicate sends (rule 52.6)
  retry_count       int not null default 0,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);
create index idx_notifications_gym_status on notifications(gym_id, status, scheduled_at);
create index idx_notifications_member on notifications(member_id);

create table communication_preferences (
  member_id  uuid primary key references members on delete cascade,
  channel    text not null check (channel in ('email','sms','whatsapp','push')),
  opted_in   boolean not null default true,
  updated_at timestamptz not null default now()
);
create index idx_comm_prefs_member on communication_preferences(member_id);

alter table notifications enable row level security;
create policy "notifications tenant isolation" on notifications for all
  using (gym_id = public.gym_id()) with check (gym_id = public.gym_id());

alter table communication_preferences enable row level security;
create policy "comm_prefs tenant isolation" on communication_preferences for all
  using (exists (select 1 from members m where m.id = communication_preferences.member_id and m.gym_id = public.gym_id()))
  with check (exists (select 1 from members m where m.id = communication_preferences.member_id and m.gym_id = public.gym_id()));

create trigger set_updated before update on notifications for each row execute function trigger_set_updated();
create trigger set_updated before update on communication_preferences for each row execute function trigger_set_updated();
