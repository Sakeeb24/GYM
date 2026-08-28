-- 005_attendance.sql
-- QR check-in records + streak tracking.
-- Client never writes here directly; the recordAttendance edge function does.

create table attendance (
  id                uuid primary key default gen_random_uuid(),
  gym_id            uuid not null references gyms on delete cascade,
  member_id         uuid not null references members on delete cascade,
  check_in_at       timestamptz not null default now(),
  source            text not null check (source in ('qr_self','qr_assisted','manual')),
  staff_id          uuid references profiles on delete set null,
  idempotency_key   text unique,          -- dedup duplicate scans (rule 52.1)
  created_at        timestamptz not null default now()
);

create index idx_attendance_gym_member_time on attendance(gym_id, member_id, check_in_at desc);
create index idx_attendance_gym_time on attendance(gym_id, check_in_at desc);
create index idx_attendance_idempotency on attendance(idempotency_key);

create table streaks (
  member_id         uuid primary key references members on delete cascade,
  gym_id            uuid not null references gyms on delete cascade,
  current_streak    int not null default 0,
  longest_streak    int not null default 0,
  last_check_in_at  timestamptz,
  last_updated      timestamptz not null default now()
);
create index idx_streaks_gym on streaks(gym_id);

alter table attendance enable row level security;
create policy "attendance tenant isolation"
  on attendance for all
  using (gym_id = auth.gym_id())
  with check (gym_id = auth.gym_id());

alter table streaks enable row level security;
create policy "streaks tenant isolation"
  on streaks for all
  using (gym_id = auth.gym_id())
  with check (gym_id = auth.gym_id());
