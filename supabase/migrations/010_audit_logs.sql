-- 010_audit_logs.sql
-- Immutable audit trail of business actions (rule 34).

create table audit_logs (
  id          uuid primary key default gen_random_uuid(),
  gym_id      uuid references gyms on delete set null,   -- null = system action
  actor_user_id uuid references profiles on delete set null,
  action      text not null,
  entity      text,
  entity_id   text,
  detail      jsonb,
  ip_address  inet,
  created_at  timestamptz not null default now()
);
-- No updated_at: audit rows are append-only.
create index idx_audit_gym_time on audit_logs(gym_id, created_at);
create index idx_audit_actor on audit_logs(actor_user_id);
create index idx_audit_action on audit_logs(action);

-- Audit rows are written only by edge functions (service_role). The authenticated
-- role can SELECT its own gym's audit (read-only) for transparency.
alter table audit_logs enable row level security;
create policy "audit_logs tenant isolation" on audit_logs for select
  using (gym_id = public.gym_id() or gym_id is null);
create policy "audit_logs no client write" on audit_logs for insert with check (false);
create policy "audit_logs no client update" on audit_logs for update using (false);
create policy "audit_logs no client delete" on audit_logs for delete using (false);

-- Helper to append an audit row from SQL (used by triggers/functions).
create or replace function audit_log(
  p_gym_id uuid, p_actor uuid, p_action text, p_entity text, p_entity_id text, p_detail jsonb default '{}'
) returns void language plpgsql as $$
begin
  insert into audit_logs(gym_id, actor_user_id, action, entity, entity_id, detail)
  values (p_gym_id, p_actor, p_action, p_entity, p_entity_id, p_detail);
end;
$$;
