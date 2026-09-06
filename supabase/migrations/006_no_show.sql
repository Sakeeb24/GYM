-- 006_no_show.sql
-- Inactivity detection results. One OPEN case per member (partial unique index).

create table no_show_cases (
  id             uuid primary key default gen_random_uuid(),
  gym_id         uuid not null references gyms on delete cascade,
  member_id      uuid not null references members on delete cascade,
  status         text not null default 'open'
                 check (status in ('open','in_progress','resolved','dismissed')),
  reason         text,
  assigned_to    uuid references profiles on delete set null,
  assigned_at    timestamptz,
  last_seen_at   timestamptz,        -- last attendance before inactivity
  created_at     timestamptz not null default now(),
  resolved_at    timestamptz,
  resolved_outcome text
);

-- Prevent duplicate OPEN cases for the same member (partial unique index).
create unique index if not exists idx_no_show_one_open_per_member
  on no_show_cases(gym_id, member_id)
  where status = 'open';

create index idx_no_show_gym_status_seen on no_show_cases(gym_id, status, last_seen_at);
create index idx_no_show_gym_assigned on no_show_cases(gym_id, assigned_to);

alter table no_show_cases enable row level security;
create policy "no_show tenant isolation"
  on no_show_cases for all
  using (gym_id = public.gym_id())
  with check (gym_id = public.gym_id());
