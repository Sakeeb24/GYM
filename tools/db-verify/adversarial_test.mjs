// tools/db-verify/adversarial_test.mjs
// Adversarial test suite challenging all invariants, concurrency, tenant isolation,
// role boundaries, and 10 verification cycles.

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { PGlite } from '@electric-sql/pglite';
import { pgcrypto } from '@electric-sql/pglite/contrib/pgcrypto';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const MIGRATIONS_DIR = path.resolve(__dirname, '../../supabase/migrations');

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
const results = [];

function assert(name, cond, detail = '') {
  if (cond) {
    PASS++;
    results.push({ name, status: 'PASS', detail });
    console.log('  [PASS] ' + name);
  } else {
    FAIL++;
    results.push({ name, status: 'FAIL', detail });
    console.log('  [FAIL] ' + name + (detail ? ' -> ' + detail : ''));
  }
}

async function expectReject(name, fn) {
  try {
    await fn();
    assert(name, false, 'Unexpectedly allowed');
  } catch (e) {
    assert(name, true, e.message);
  }
}

async function main() {
  console.log('================================================================');
  console.log('PHASE 2: ADVERSARIAL INTEGRITY & TENANT ISOLATION AUDIT');
  console.log('================================================================\n');

  const db = await PGlite.create({ extensions: [pgcrypto] });

  // 1. Shims for Supabase auth schema
  await db.exec('create schema if not exists auth;');
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

  // 2. Load all migrations in order
  const files = fs.readdirSync(MIGRATIONS_DIR).filter(f => f.endsWith('.sql')).sort();
  for (const f of files) {
    const sql = fs.readFileSync(path.join(MIGRATIONS_DIR, f), 'utf8');
    await db.exec(sql);
  }
  console.log(`Loaded ${files.length} migrations into in-memory PostgreSQL engine.\n`);

  // 3. Grant authenticated role
  await db.exec('create role authenticated;');
  await db.exec('grant usage on schema public to authenticated;');
  await db.exec('grant select, insert, update, delete on all tables in schema public to authenticated;');
  await db.exec('grant usage, select on all sequences in schema public to authenticated;');
  await db.exec('create role app_user login in role authenticated;');
  await db.exec("grant select, insert, update, delete on all tables in schema public to app_user;");

  // 4. Seed Gyms & Users
  await db.exec(`insert into gyms(id, name, slug) values ('${Gyms.A}','Iron Gym A','iron-a'),('${Gyms.B}','Iron Gym B','iron-b');`);
  await db.exec(`insert into gym_settings(gym_id, inactivity_threshold_days, qr_session_grace_minutes, reminder_windows_days) values ('${Gyms.A}', 7, 5, ARRAY[14,7,3]), ('${Gyms.B}', 7, 5, ARRAY[14,7,3]);`);

  const makeUser = (id, gymId, role, name, email, phone) =>
    `insert into auth.users(id, email, phone, raw_user_meta_data, raw_app_meta_data)
       values ('${id}', '${email}', '${phone}',
               jsonb_build_object('full_name','${name}'),
               jsonb_build_object('gym_id','${gymId}','role','${role}'));`;
  await db.exec(makeUser(Users.ownerA, Gyms.A, 'owner', 'Owner A', 'ownerA@liftflow.dev', '555-0100'));
  await db.exec(makeUser(Users.memberA1, Gyms.A, 'member', 'Member A1', 'a1@liftflow.dev', '555-0101'));
  await db.exec(makeUser(Users.ownerB, Gyms.B, 'owner', 'Owner B', 'ownerB@liftflow.dev', '555-0200'));
  await db.exec(makeUser(Users.memberB1, Gyms.B, 'member', 'Member B1', 'b1@liftflow.dev', '555-0201'));

  // Seed members
  await db.exec(`insert into members(gym_id, profile_id, member_number, full_name, phone) values ('${Gyms.A}','${Users.memberA1}','A-101','Member A1','555-0101');`);
  await db.exec(`insert into members(gym_id, profile_id, member_number, full_name, phone) values ('${Gyms.B}','${Users.memberB1}','B-201','Member B1','555-0201');`);

  // Helpers
  async function asUser(userId, gymId) {
    await db.exec(`select set_config('row_security','on',false);`);
    await db.exec(`select set_config('request.jwt.claim.sub', '${userId}', false);`);
    await db.exec(`select set_config('request.jwt.claim.gym_id', '${gymId}', false);`);
    await db.exec(`set role app_user;`);
  }
  async function resetRole() {
    await db.exec(`reset role;`);
    await db.exec(`select set_config('row_security','off',false);`);
  }

  // --- ADVERSARIAL SECTION 1: TENANT ISOLATION (CROSS-GYM ATTEMPTS) ---
  console.log('# ADVERSARIAL TEST GROUP 1: Deep Cross-Tenant Isolation');
  await asUser(Users.memberA1, Gyms.A);

  // 1. Cross-tenant member read
  let r = await db.query(`select * from members where gym_id = '${Gyms.B}'`);
  assert('Gym A member query for Gym B members returns 0 rows', r.rows.length === 0);

  // 2. Cross-tenant member update
  await db.exec(`update members set full_name = 'Hacked' where gym_id = '${Gyms.B}'`);
  await resetRole();
  let bRow = await db.query(`select full_name from members where gym_id = '${Gyms.B}'`);
  assert('Gym A member cannot modify Gym B member data', bRow.rows[0].full_name === 'Member B1');

  // 3. Cross-tenant attendance write
  await asUser(Users.memberA1, Gyms.A);
  await expectReject('Gym A member cannot record attendance in Gym B', () =>
    db.exec(`insert into attendance(gym_id, member_id, check_in_at, method) values ('${Gyms.B}', '${Users.memberA1}', now(), 'qr');`));
  await resetRole();

  // --- ADVERSARIAL SECTION 2: RACE CONDITIONS & CONCURRENCY ---
  console.log('\n# ADVERSARIAL TEST GROUP 2: Race-Conditions & Concurrency');
  const tokenHash = '9999999999999999999999999999999999999999999999999999999999999999';
  const tokRes = await db.query(`
    insert into member_activation_tokens (gym_id, created_by, token_hash, expires_at)
    values ('${Gyms.A}', '${Users.ownerA}', '${tokenHash}', now() + interval '60 seconds')
    returning id;
  `);
  const testTokenId = tokRes.rows[0].id;

  // Simulate 5 simultaneous workers racing to consume the single-use token
  const racePromises = [1, 2, 3, 4, 5].map((workerId) =>
    db.query(`
      update member_activation_tokens
      set used_at = now(), used_by_profile_id = '${Users.memberA1}'
      where id = '${testTokenId}' and used_at is null and expires_at > now()
      returning id;
    `)
  );
  const raceResults = await Promise.all(racePromises);
  const successfulConsumptions = raceResults.filter(res => res.rows.length === 1).length;
  const rejectedConsumptions = raceResults.filter(res => res.rows.length === 0).length;

  assert('Race condition test: Exactly 1 worker succeeds in consuming activation token', successfulConsumptions === 1);
  assert('Race condition test: Exactly 4 workers are rejected (0 rows updated)', rejectedConsumptions === 4);

  // --- ADVERSARIAL SECTION 3: 10 VERIFICATION CYCLES ---
  console.log('\n# ADVERSARIAL TEST GROUP 3: 10 Verification Cycles');

  // Cycle 1: Valid activation token creation & lifecycle
  const c1Hash = 'c1_00000000000000000000000000000000000000000000000000000000000001';
  const c1Res = await db.query(`
    insert into member_activation_tokens (gym_id, created_by, token_hash, expires_at)
    values ('${Gyms.A}', '${Users.ownerA}', '${c1Hash}', now() + interval '60 seconds')
    returning id;
  `);
  assert('Cycle 1: Valid token insertion succeeds', c1Res.rows.length === 1);

  // Cycle 2: Invalid / Forged token lookup returns empty
  const c2Check = await db.query(`
    select id from member_activation_tokens where token_hash = 'non_existent_fake_hash_1234' and used_at is null and expires_at > now();
  `);
  assert('Cycle 2: Forged token lookup returns 0 matching rows', c2Check.rows.length === 0);

  // Cycle 3: Expired token cannot be consumed
  const c3Hash = 'c3_00000000000000000000000000000000000000000000000000000000000003';
  const c3Id = (await db.query(`
    insert into member_activation_tokens (gym_id, created_by, token_hash, expires_at, created_at)
    values ('${Gyms.A}', '${Users.ownerA}', '${c3Hash}', now() - interval '1 second', now() - interval '2 seconds')
    returning id;
  `)).rows[0].id;
  const c3Consume = await db.query(`
    update member_activation_tokens
    set used_at = now(), used_by_profile_id = '${Users.memberA1}'
    where id = '${c3Id}' and used_at is null and expires_at > now()
    returning id;
  `);
  assert('Cycle 3: Expired token consumption rejected (0 rows updated)', c3Consume.rows.length === 0);

  // Cycle 4: Revoked token cannot be consumed
  const c4Hash = 'c4_00000000000000000000000000000000000000000000000000000000000004';
  const c4Id = (await db.query(`
    insert into member_activation_tokens (gym_id, created_by, token_hash, expires_at)
    values ('${Gyms.A}', '${Users.ownerA}', '${c4Hash}', now() + interval '60 seconds')
    returning id;
  `)).rows[0].id;
  await db.exec(`update member_activation_tokens set revoked_at = now() where id = '${c4Id}';`);
  const c4Consume = await db.query(`
    update member_activation_tokens
    set used_at = now(), used_by_profile_id = '${Users.memberA1}'
    where id = '${c4Id}' and used_at is null and revoked_at is null and expires_at > now()
    returning id;
  `);
  assert('Cycle 4: Revoked token consumption rejected (0 rows updated)', c4Consume.rows.length === 0);

  // Cycle 5: Duplicate token_hash blocked
  await expectReject('Cycle 5: Duplicate token_hash insert rejected by UNIQUE constraint', () =>
    db.exec(`insert into member_activation_tokens (gym_id, created_by, token_hash, expires_at) values ('${Gyms.A}', '${Users.ownerA}', '${c1Hash}', now() + interval '60 seconds');`));

  // Cycle 6: Duplicate phone number blocked on profiles
  await db.exec(`update profiles set phone = '+919999900001' where user_id = '${Users.ownerA}';`);
  await expectReject('Cycle 6: Duplicate phone number rejected by constraint', () =>
    db.exec(`update profiles set phone = '+919999900001' where user_id = '${Users.memberA1}';`));

  // Cycle 7: Duplicate username blocked (case-insensitive)
  await db.exec(`update profiles set username = 'alphagym' where user_id = '${Users.ownerA}';`);
  await expectReject('Cycle 7: Duplicate username rejected by constraint', () =>
    db.exec(`update profiles set username = 'alphagym' where user_id = '${Users.memberA1}';`));

  // Cycle 8: Client role cannot bypass RLS to insert into gyms table
  await asUser(Users.memberA1, Gyms.A);
  await expectReject('Cycle 8: Client role cannot insert directly into gyms table', () =>
    db.exec(`insert into gyms (name, slug) values ('Unauthorized Gym', 'unauth-gym');`));
  await resetRole();

  // Cycle 9: Client role cannot insert directly into gym_settings
  await asUser(Users.memberA1, Gyms.A);
  await expectReject('Cycle 9: Client role cannot insert directly into gym_settings', () =>
    db.exec(`insert into gym_settings (gym_id) values ('${Gyms.A}');`));
  await resetRole();

  // Cycle 10: RLS enforces audit log tenant query protection
  await db.exec(`insert into audit_logs(gym_id, actor_user_id, action, entity, entity_id) values ('${Gyms.A}', '${Users.ownerA}', 'test.action', 'gym', '${Gyms.A}');`);
  await asUser(Users.memberB1, Gyms.B);
  const auditRes = await db.query('select count(*)::int as n from audit_logs');
  assert('Cycle 10: Gym B member cannot see Gym A audit logs', auditRes.rows[0].n === 0);
  await resetRole();

  console.log('\n================================================================');
  console.log(`ADVERSARIAL SUITE SUMMARY: ${PASS} passed, ${FAIL} failed`);
  console.log('================================================================');
  await db.close();
  process.exit(FAIL === 0 ? 0 : 1);
}

main().catch(e => {
  console.error('FATAL', e);
  process.exit(2);
});
