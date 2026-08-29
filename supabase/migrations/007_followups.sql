-- 007_followups.sql
-- Red List follow-up actions tied to a no-show case.

create table follow_ups (
  id              uuid primary key default gen_random_uuid(),
  gym_id          uuid not null references gyms on delete cascade,
  no_show_case_id uuid not null references no_show_cases on delete cascade,
  member_id       uuid not null references members on delete cascade,
  assigned_to     uuid references profiles on delete set null,
  status          text not null default 'open'
                 check (status in ('open','contacted','will_return','returning',
                                   'not_interested','paused','wrong_number',
                                   'no_response','resolved')),
  next_action_at  timestamptz,
  outcome         text,
  notes           text,
  created_by      uuid references profiles on delete set null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  completed_at    timestamptz
);

create index idx_followups_gym_status on follow_ups(gym_id, status);
create index idx_followups_gym_next on follow_ups(gym_id, next_action_at);
create index idx_followups_case on follow_ups(no_show_case_id);

alter table follow_ups enable row level security;
create policy "follow_ups tenant isolation"
  on follow_ups for all
  using (gym_id = public.gym_id())
  with check (gym_id = public.gym_id());

create trigger set_updated before update on follow_ups
  for each row execute function trigger_set_updated();
