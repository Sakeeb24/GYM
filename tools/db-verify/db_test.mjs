// tools/db-verify/db_test.mjs
// Verifies the Supabase migrations against an IN-MEMORY PostgreSQL (PGLite).
// No Docker. Loads every supabase/migrations/*.sql in order, then asserts
// tenant isolation, constraints, and idempotency.
// Run: `node db_test.mjs` (after `npm install` in tools/db-verify).

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { PGlite } from '@electric-sql/pglite';
import { pgcrypto } from '@electric-sql/pglite/contrib/pgcrypto';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const MIGRATIONS_DIR = path.resolve(__dirname, '../../supabase/migrations');

// Deterministic test UUIDs.
const Gyms = {
  A: '00000000-0000-0000-0000-00000000000A',
  B: '00000000-0000-0000-0000-00000000000B',
};
const Users = {
  ownerA: '10000000-0000-0000-0000-000000000001',
  memberA1: '10000000-0000-0000-0000-000000000002',
  ownerB: '10000000-0000-0000-0000-000000000003',
  memberB1: '10000000-0000-0000-0000-000000000004',
};

let PASS = 0;
let FAIL = 0;
function assert(name, cond, detail = '') {
  if (cond) { PASS++; console.log('  PASS ' + name); }
  else { FAIL++; console.log('  FAIL ' + name + (detail ? ' -> ' + detail : '')); }
}
async function expectReject(db, name, fn) {
  try { await fn(); assert(name + ' (denied)', false, 'unexpectedly allowed'); }
  catch (e) { assert(name + ' (denied)', true); }
}

async function main() {
  const db = await PGlite.create({ extensions: [pgcrypto] });

  // --- Shims for things Supabase provides (not in stock Postgres) ---
  await db.exec('create schema if not exists auth;');
  // Mock auth.users (Supabase-managed table).
  await db.exec(`
    create table auth.users (
      id uuid primary key,
      email text,
      phone text,
      raw_user_meta_data jsonb,
      raw_app_meta_data jsonb,
      app_metadata jsonb,
      created_at timestamptz default now(),
      updated_at timestamptz default now()
    );
  `);
  await db.exec("create function auth.uid() returns uuid language sql stable as $$ select current_setting('request.jwt.claim.sub')::uuid $$;");
  // Shims for gen_random_uuid / pgcrypto (Supabase has pgcrypto by default).

  // --- Load real migrations in filename order ---
  const files = fs.readdirSync(MIGRATIONS_DIR).filter(f => f.endsWith('.sql')).sort();
  for (const f of files) {
    const sql = fs.readFileSync(path.join(MIGRATIONS_DIR, f), 'utf8');
    try { await db.exec(sql); console.log('  MIG  ' + f); }
    catch (e) { console.log('  ERR  ' + f + ' -> ' + e.message); throw e; }
  }
  console.log('Migrations loaded: ' + files.length);

  // --- Grant the `authenticated` role the privileges Supabase grants by default ---
  await db.exec('create role authenticated;');
  await db.exec('grant usage on schema public to authenticated;');
  await db.exec('grant select, insert, update, delete on all tables in schema public to authenticated;');
  await db.exec('grant usage, select on all sequences in schema public to authenticated;');
  await db.exec('grant insert, update on all tables in schema public to authenticated;');

  // A non-owner, non-superuser role that is a member of `authenticated`.
  await db.exec('create role app_user login in role authenticated;');
  await db.exec("grant select, insert, update, delete on all tables in schema public to app_user;");

  // --- Seed two gyms ---
  await db.exec(`insert into gyms(id, name, slug) values ('${Gyms.A}','Gym A','gym-a'),('${Gyms.B}','Gym B','gym-b');`);
  await db.exec(`insert into gym_settings(gym_id, inactivity_threshold_days, qr_session_grace_minutes, reminder_windows_days) values ('${Gyms.A}', 7, 5, ARRAY[14,7,3]), ('${Gyms.B}', 7, 5, ARRAY[14,7,3]);`);

  // --- Create auth users (fires handle_new_user trigger -> profiles) ---
  const makeUser = (id, gymId, role, name, email, phone) =>
    `insert into auth.users(id, email, phone, raw_user_meta_data, raw_app_meta_data)
       values ('${id}', '${email}', '${phone}',
               jsonb_build_object('full_name','${name}'),
               jsonb_build_object('gym_id','${gymId}','role','${role}'));`;
  await db.exec(makeUser(Users.ownerA, Gyms.A, 'owner', 'Owner A', 'ownerA@liftflow.dev', '555-0100'));
  await db.exec(makeUser(Users.memberA1, Gyms.A, 'member', 'Member A1', 'a1@liftflow.dev', '555-0101'));
  await db.exec(makeUser(Users.ownerB, Gyms.B, 'owner', 'Owner B', 'ownerB@liftflow.dev', '555-0200'));
  await db.exec(makeUser(Users.memberB1, Gyms.B, 'member', 'Member B1', 'b1@liftflow.dev', '555-0201'));

  // --- Create members linking to profiles ---
  await db.exec(`insert into members(gym_id, profile_id, member_number, full_name, phone)
    select '${Gyms.A}', '${Users.memberA1}', 'A-1001', 'Member A1', '555-1'
    where exists (select 1 from profiles where user_id='${Users.memberA1}');`);
  await db.exec(`insert into members(gym_id, profile_id, member_number, full_name, phone)
    select '${Gyms.B}', '${Users.memberB1}', 'B-2001', 'Member B1', '555-2'
    where exists (select 1 from profiles where user_id='${Users.memberB1}');`);

  // helper: run a query as a tenant (sets JWT claims + role + row_security)
  async function asGym(gymId) {
    await db.exec(`select set_config('row_security','on',false);`);
    await db.exec(`select set_config('request.jwt.claim.sub', '${Users.memberA1}', false);`);
    await db.exec(`select set_config('request.jwt.claim.gym_id', '${gymId}', false);`);
    await db.exec(`set role app_user;`);
  }
  async function resetRole() {
    await db.exec(`reset role;`);
    await db.exec(`select set_config('row_security','off',false);`);
  }

  console.log('\n# TEST GROUP: tenant isolation (rule 5/10)');
  await asGym(Gyms.A);
  let r = await db.query('select count(*)::int as n from members');
  assert('Gym A sees only its members', r.rows[0].n === 1, 'got ' + r.rows[0].n);
  await db.exec(`select set_config('request.jwt.claim.gym_id','${Gyms.B}', true);`);
  r = await db.query('select count(*)::int as n from members');
  assert('Gym B sees only its members', r.rows[0].n === 1, 'got ' + r.rows[0].n);
  await resetRole();

  console.log('\n# TEST GROUP: cross-tenant write denied');
  await asGym(Gyms.A);
  await expectReject(db, 'Gym A cannot insert into Gym B members', () =>
    db.exec(`insert into members(gym_id, member_number, full_name) values ('${Gyms.B}','x','X');`));
  await resetRole();

  console.log('\n# TEST GROUP: one active membership per member');
  const memRow = await db.query(`select id, gym_id from members where gym_id='${Gyms.A}' limit 1`);
  const memberAId = memRow.rows[0].id;
  const planA = (await db.query(`insert into membership_plans(gym_id,name,duration_days,price_cents) values ('${Gyms.A}','Basic',30,1500) returning id`)).rows[0].id;
  await db.exec(`insert into memberships(gym_id, member_id, plan_id, status, started_at, expires_at)
    values ('${Gyms.A}','${memberAId}','${planA}','active',now(),now()+interval '30 days');`);
  await expectReject(db, 'second active membership blocked', () =>
    db.exec(`insert into memberships(gym_id, member_id, plan_id, status, started_at, expires_at)
      values ('${Gyms.A}','${memberAId}','${planA}','active',now(),now()+interval '30 days');`));
  await db.exec(`update memberships set status='canceled', canceled_at=now() where member_id='${memberAId}';`);
  // after canceling, a new active one is allowed
  let ok = true;
  try { await db.exec(`insert into memberships(gym_id, member_id, plan_id, status, started_at, expires_at) values ('${Gyms.A}','${memberAId}','${planA}','active',now(),now()+interval '30 days');`); }
  catch { ok = false; }
  assert('replaced after canceling previous', ok);
  await resetRole();

  console.log('\n# TEST GROUP: no-show duplicate prevention');
  await db.exec(`insert into no_show_cases(gym_id, member_id, status, reason, last_seen_at)
    values ('${Gyms.A}','${memberAId}','open','inactive',now()-interval '10 days');`);
  await expectReject(db, 'duplicate open no-show case blocked', () =>
    db.exec(`insert into no_show_cases(gym_id, member_id, status, reason) values ('${Gyms.A}','${memberAId}','open','inactive');`));
  await resetRole();

  console.log('\n# TEST GROUP: duplicate payment reference');
  const memberBRow = await db.query(`select id, gym_id from members where gym_id='${Gyms.B}' limit 1`);
  const memberBId = memberBRow.rows[0].id;
  await db.exec(`insert into payments(gym_id, member_id, provider, provider_reference, amount_cents, currency)
    values ('${Gyms.B}','${memberBId}','stripe','ch_100',1500,'USD');`);
  await expectReject(db, 'duplicate provider_reference blocked', () =>
    db.exec(`insert into payments(gym_id, member_id, provider, provider_reference, amount_cents, currency)
      values ('${Gyms.B}','${memberBId}','stripe','ch_100',1500,'USD');`));
  await resetRole();

  console.log('\n# TEST GROUP: idempotency keys');
  await db.exec(`insert into renewal_orders(gym_id, member_id, plan_id, due_at, amount_cents, currency, idempotency_key) values ('${Gyms.A}','${memberAId}','${planA}',now(),1500,'USD','ord-dup');`);
  await expectReject(db, 'duplicate renewal_order idempotency_key blocked', () =>
    db.exec(`insert into renewal_orders(gym_id, member_id, plan_id, due_at, amount_cents, currency, idempotency_key) values ('${Gyms.A}','${memberAId}','${planA}',now(),1500,'USD','ord-dup');`));
  // a different idempotency_key for the same member/cycle is allowed
  let okDistinct = true;
  try { await db.exec(`insert into renewal_orders(gym_id, member_id, plan_id, due_at, amount_cents, currency, idempotency_key) values ('${Gyms.A}','${memberAId}','${planA}',now(),1500,'USD','ord-dup-2');`); }
  catch { okDistinct = false; }
  assert('distinct idempotency_key allowed', okDistinct);
  await resetRole();

  console.log('\n# TEST GROUP: business rule - membership_status');
  // Make the active membership expired by backdating expiry.
  await db.exec(`update memberships set expires_at = now() - interval '1 day' where member_id='${memberAId}' and status='active';`);
  const st = await db.query(`select membership_status(m) as s from memberships m where m.member_id='${memberAId}' and m.status='active' limit 1`);
  assert('expired membership -> status expired', st.rows[0]?.s === 'expired', JSON.stringify(st.rows));

  console.log('\n# TEST GROUP: deny-by-default for role not in gym (wrong tenant)');
  // Switch JWT to gym B but attempt to read Gym A attendance (no data yet, but policy denies cross-gym)
  await asGym(Gyms.B);
  let att = await db.query(`select count(*)::int as n from attendance`);
  assert('Gym B sees 0 attendance (none in its tenant)', att.rows[0].n === 0, 'got ' + att.rows[0].n);
  await resetRole();

  console.log('\n# TEST GROUP: username uniqueness enforcement');
  await db.exec(`update profiles set username = 'owner_a' where user_id = '${Users.ownerA}';`);
  await expectReject(db, 'duplicate username is blocked by database constraint', () =>
    db.exec(`update profiles set username = 'owner_a' where user_id = '${Users.memberA1}';`));

  console.log('\n# TEST GROUP: server-side get_dashboard_stats RPC');
  await asGym(Gyms.A);
  const dashStats = await db.query(`select get_dashboard_stats('${Gyms.A}') as stats;`);
  assert('get_dashboard_stats returns valid json object', typeof dashStats.rows[0].stats === 'object');
  assert('dashboard stats includes total_members', typeof dashStats.rows[0].stats.total_members === 'number');
  assert('dashboard stats includes monthly_revenue_cents', typeof dashStats.rows[0].stats.monthly_revenue_cents === 'number');

  // Verify Gym A cannot fetch Gym B dashboard stats
  await expectReject(db, 'cross-tenant dashboard stats access is blocked', () =>
    db.query(`select get_dashboard_stats('${Gyms.B}') as stats;`));

  console.log('\n# TEST GROUP: server-side get_analytics_trends RPC');
  const analyticsTrends = await db.query(`select get_analytics_trends('${Gyms.A}', 30) as trends;`);
  assert('get_analytics_trends returns valid json object', typeof analyticsTrends.rows[0].trends === 'object');
  assert('analytics trends includes retention_rate', typeof analyticsTrends.rows[0].trends.retention_rate === 'number');
  assert('analytics trends includes daily_trend array', Array.isArray(analyticsTrends.rows[0].trends.daily_trend));
  await resetRole();

  console.log('\n# TEST GROUP: member_activation_tokens schema & constraints');
  // 1. Insert valid activation token
  const tokenHashA1 = 'a1b2c3d4e5f60000000000000000000000000000000000000000000000000001';
  const tokenHashA2 = 'a1b2c3d4e5f60000000000000000000000000000000000000000000000000002';
  const insertTokenRes = await db.query(`
    insert into member_activation_tokens (gym_id, created_by, token_hash, expires_at)
    values ('${Gyms.A}', '${Users.ownerA}', '${tokenHashA1}', now() + interval '60 seconds')
    returning id, gym_id, expires_at;
  `);
  assert('insert valid activation token succeeds', insertTokenRes.rows.length === 1);
  const tokenId1 = insertTokenRes.rows[0].id;

  // 2. Duplicate token_hash constraint rejected
  await expectReject(db, 'duplicate token_hash is rejected', () =>
    db.exec(`insert into member_activation_tokens (gym_id, created_by, token_hash, expires_at)
      values ('${Gyms.A}', '${Users.ownerA}', '${tokenHashA1}', now() + interval '60 seconds');`));

  // 3. Past expires_at check constraint rejected
  await expectReject(db, 'expires_at in the past is rejected by constraint', () =>
    db.exec(`insert into member_activation_tokens (gym_id, created_by, token_hash, expires_at, created_at)
      values ('${Gyms.A}', '${Users.ownerA}', '${tokenHashA2}', now() - interval '10 seconds', now());`));

  console.log('\n# TEST GROUP: member_activation_tokens atomic consumption & single-use');
  // 4. Atomic token consumption
  const consumeRes1 = await db.query(`
    update member_activation_tokens
    set used_at = now(), used_by_profile_id = '${Users.memberA1}'
    where id = '${tokenId1}' and used_at is null and expires_at > now()
    returning id;
  `);
  assert('first consumption attempt consumes exactly 1 token', consumeRes1.rows.length === 1);

  // 5. Race-condition / double consumption rejected (0 rows updated)
  const consumeRes2 = await db.query(`
    update member_activation_tokens
    set used_at = now(), used_by_profile_id = '${Users.memberA1}'
    where id = '${tokenId1}' and used_at is null and expires_at > now()
    returning id;
  `);
  assert('second consumption attempt consumes 0 rows (single-use enforced)', consumeRes2.rows.length === 0);

  // 6. Expired token consumption rejected (0 rows updated)
  const expiredTokenHash = 'a1b2c3d4e5f60000000000000000000000000000000000000000000000000003';
  const expToken = (await db.query(`
    insert into member_activation_tokens (gym_id, created_by, token_hash, expires_at, created_at)
    values ('${Gyms.A}', '${Users.ownerA}', '${expiredTokenHash}', now() + interval '1 second', now() - interval '2 seconds')
    returning id;
  `)).rows[0].id;
  // Update expires_at to past to simulate expiry
  await db.exec(`update member_activation_tokens set expires_at = now() - interval '1 second' where id = '${expToken}';`);
  const expConsumeRes = await db.query(`
    update member_activation_tokens
    set used_at = now(), used_by_profile_id = '${Users.memberA1}'
    where id = '${expToken}' and used_at is null and expires_at > now()
    returning id;
  `);
  assert('expired token consumption attempt consumes 0 rows', expConsumeRes.rows.length === 0);

  // 7. Revoked token handling
  const revokedTokenHash = 'a1b2c3d4e5f60000000000000000000000000000000000000000000000000004';
  const revToken = (await db.query(`
    insert into member_activation_tokens (gym_id, created_by, token_hash, expires_at)
    values ('${Gyms.A}', '${Users.ownerA}', '${revokedTokenHash}', now() + interval '60 seconds')
    returning id;
  `)).rows[0].id;
  await db.exec(`update member_activation_tokens set revoked_at = now() where id = '${revToken}';`);
  const revConsumeRes = await db.query(`
    update member_activation_tokens
    set used_at = now(), used_by_profile_id = '${Users.memberA1}'
    where id = '${revToken}' and used_at is null and revoked_at is null and expires_at > now()
    returning id;
  `);
  assert('revoked token consumption attempt consumes 0 rows', revConsumeRes.rows.length === 0);

  console.log('\n# TEST GROUP: member_activation_tokens tenant isolation & RLS');
  await asGym(Gyms.A);
  // Direct client insert denied by RLS
  await expectReject(db, 'client role cannot insert activation tokens directly', () =>
    db.exec(`insert into member_activation_tokens (gym_id, created_by, token_hash, expires_at)
      values ('${Gyms.A}', '${Users.memberA1}', 'fakehash', now() + interval '60 seconds');`));
  await resetRole();

  console.log('\n=========================================');
  console.log('DB TEST SUMMARY: ' + PASS + ' passed, ' + FAIL + ' failed');
  console.log('=========================================');
  await db.close();
  process.exit(FAIL === 0 ? 0 : 1);
}

main().catch(e => { console.log('FATAL ' + e.message); process.exit(2); });
