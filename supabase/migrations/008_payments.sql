-- 008_payments.sql
-- Payments + renewal orders + add-ons. Payments are NEVER trusted from the client
-- (rule 8); success is driven by the verified provider webhook.

create table renewal_orders (
  id              uuid primary key default gen_random_uuid(),
  gym_id          uuid not null references gyms on delete cascade,
  member_id       uuid not null references members on delete cascade,
  membership_id   uuid references memberships on delete set null,
  plan_id         uuid not null references membership_plans on delete restrict,
  due_at          timestamptz not null,        -- membership expiry that triggers renewal
  status          text not null default 'pending'
                 check (status in ('pending','sent','paid','failed','canceled','completed')),
  reminder_stage  text,                       -- which window already sent (idempotency)
  amount_cents    int not null check (amount_cents >= 0),
  currency        text not null default 'USD',
  idempotency_key text unique,                -- prevent duplicate campaigns
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index idx_renewal_orders_gym_status on renewal_orders(gym_id, status);
create index idx_renewal_orders_member on renewal_orders(member_id);
create index idx_renewal_orders_due on renewal_orders(gym_id, due_at);
create trigger set_updated before update on renewal_orders for each row execute function trigger_set_updated();

create table payments (
  id                uuid primary key default gen_random_uuid(),
  gym_id            uuid not null references gyms on delete cascade,
  member_id         uuid not null references members on delete cascade,
  renewal_order_id  uuid references renewal_orders on delete set null,
  provider          text not null check (provider in ('stripe','manual','cash')),
  provider_reference text unique,              -- provider charge/intent id; unique prevents dup
  amount_cents      int not null check (amount_cents >= 0),
  currency          text not null default 'USD',
  status            text not null default 'created'
                   check (status in ('created','pending','succeeded','failed','canceled','refunded','reversed')),
  idempotency_key   text unique,
  metadata          jsonb,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);
create index idx_payments_gym_status on payments(gym_id, status);
create index idx_payments_provider_ref on payments(gym_id, provider_reference);

create table add_ons (
  id          uuid primary key default gen_random_uuid(),
  gym_id      uuid not null references gyms on delete cascade,
  name        text not null,
  description text,
  price_cents int not null check (price_cents >= 0),
  unit_label  text not null default 'per_period',
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint addon_unique_per_gym_name unique (gym_id, name)
);
create index idx_addons_gym on add_ons(gym_id);

create table add_on_orders (
  id            uuid primary key default gen_random_uuid(),
  gym_id        uuid not null references gyms on delete cascade,
  member_id     uuid not null references members on delete cascade,
  add_on_id     uuid not null references add_ons on delete restrict,
  quantity      int not null check (quantity > 0),
  status        text not null default 'pending'
               check (status in ('pending','active','canceled')),
  started_at    timestamptz,
  ended_at      timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index idx_addon_orders_gym_member on add_on_orders(gym_id, member_id);

create trigger set_updated before update on payments for each row execute function trigger_set_updated();
create trigger set_updated before update on add_ons for each row execute function trigger_set_updated();
create trigger set_updated before update on add_on_orders for each row execute function trigger_set_updated();

-- RLS: all tenant-scoped, denied for client writes except via edge functions (service_role).
alter table renewal_orders enable row level security;
create policy "renewal_orders tenant isolation" on renewal_orders for all
  using (gym_id = public.gym_id()) with check (gym_id = public.gym_id());

alter table payments enable row level security;
create policy "payments tenant isolation" on payments for all
  using (gym_id = public.gym_id()) with check (gym_id = public.gym_id());

alter table add_ons enable row level security;
create policy "add_ons tenant isolation" on add_ons for all
  using (gym_id = public.gym_id()) with check (gym_id = public.gym_id());

alter table add_on_orders enable row level security;
create policy "add_on_orders tenant isolation" on add_on_orders for all
  using (gym_id = public.gym_id()) with check (gym_id = public.gym_id());
