// e2e/test_activation_qr_lifecycle.mjs
// Dedicated Test Suite for QR Activation Token Lifecycle, Atomicity & Concurrency

import assert from 'assert';

const SUPABASE_URL = 'https://qwnxbdqzmxyukrbeqrcj.supabase.co';

async function sha256Hex(str) {
  const data = new TextEncoder().encode(str);
  const digest = await crypto.subtle.digest('SHA-256', data);
  return Array.from(new Uint8Array(digest))
    .map(b => b.toString(16).padStart(2, '0'))
    .join('');
}

function generateRandomToken() {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  return Array.from(bytes)
    .map(b => b.toString(16).padStart(2, '0'))
    .join('');
}

async function validateToken(token) {
  const res = await fetch(`${SUPABASE_URL}/functions/v1/validateMemberActivation`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ token }),
  });
  return { status: res.status, data: await res.json() };
}

async function registerMember(payload) {
  const res = await fetch(`${SUPABASE_URL}/functions/v1/registerMember`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });
  return { status: res.status, data: await res.json() };
}

async function runLifecycleTests() {
  console.log('================================================================');
  console.log('QR ACTIVATION TOKEN LIFECYCLE, ATOMICITY & CONCURRENCY AUDIT');
  console.log('Target:', SUPABASE_URL);
  console.log('================================================================\n');

  const results = {};

  // ── TEST 1: Invalid QR rejection ───────────────────────────────────────────
  console.log('TEST 1: Invalid QR rejection...');
  const invalidRes = await validateToken('invalid_nonexistent_qr_code_123456');
  assert.strictEqual(invalidRes.status, 404, 'Invalid token must return 404');
  console.log('  [PASS] Invalid token rejected with HTTP 404.');
  results.test1_invalidToken = 'PASS';

  // ── TEST 2: Month-scoped / fallback Gym token validation ───────────────────
  console.log('\nTEST 2: Month-scoped Gym token validation...');
  const monthToken = 'act_solo-fitness_2026_09';
  const monthRes = await validateToken(monthToken);
  assert.strictEqual(monthRes.status, 200, 'Month token must be valid');
  assert.strictEqual(monthRes.data.valid, true);
  assert.strictEqual(monthRes.data.gym.slug, 'solo-fitness');
  console.log('  [PASS] Month-scoped token validated successfully for gym:', monthRes.data.gym.name);
  results.test2_monthScopedToken = 'PASS';

  // ── TEST 3: Fresh single-use registration ──────────────────────────────────
  console.log('\nTEST 3: Fresh registration with valid token...');
  const nonce = Math.floor(100000 + Math.random() * 900000);
  const reg1 = await registerMember({
    full_name: `Lifecycle Member ${nonce}`,
    phone: `+9198${nonce}`,
    activation_token: monthToken,
    username: `user_life_${nonce}`,
    password: 'StrongPass#2026!',
  });
  assert.strictEqual(reg1.status, 201, 'Registration must return 201 Created');
  assert(reg1.data.user_id, 'User ID must be returned');
  assert(reg1.data.member_id, 'Member ID must be returned');
  console.log('  [PASS] Fresh registration completed successfully. User ID:', reg1.data.user_id);
  results.test3_freshRegistration = 'PASS';

  // ── TEST 4: Duplicate phone rejection ──────────────────────────────────────
  console.log('\nTEST 4: Duplicate phone number rejection...');
  const regDupPhone = await registerMember({
    full_name: `Duplicate Phone Member`,
    phone: `+9198${nonce}`, // same phone as TEST 3
    activation_token: monthToken,
    username: `user_diff_${nonce}`,
    password: 'StrongPass#2026!',
  });
  assert.strictEqual(regDupPhone.status, 409, 'Duplicate phone must return 409 Conflict');
  console.log('  [PASS] Duplicate phone safely rejected with HTTP 409.');
  results.test4_duplicatePhone = 'PASS';

  // ── TEST 5: Duplicate username rejection ───────────────────────────────────
  console.log('\nTEST 5: Duplicate username rejection...');
  const regDupUser = await registerMember({
    full_name: `Duplicate User Member`,
    phone: `+9199${nonce}`,
    activation_token: monthToken,
    username: `user_life_${nonce}`, // same username as TEST 3
    password: 'StrongPass#2026!',
  });
  assert.strictEqual(regDupUser.status, 409, 'Duplicate username must return 409 Conflict');
  console.log('  [PASS] Duplicate username safely rejected with HTTP 409.');
  results.test5_duplicateUsername = 'PASS';

  // ── TEST 6: Concurrency test — simultaneous registration attempts ────────
  console.log('\nTEST 6: Concurrency test — simultaneous registration attempts on identical credentials...');
  const cNonce = Math.floor(100000 + Math.random() * 900000);
  const p1 = registerMember({
    full_name: `Concurrent Athlete A`,
    phone: `+9197${cNonce}`,
    activation_token: monthToken,
    username: `user_c_${cNonce}`,
    password: 'StrongPass#2026!',
  });
  const p2 = registerMember({
    full_name: `Concurrent Athlete B`,
    phone: `+9197${cNonce}`, // duplicate phone
    activation_token: monthToken,
    username: `user_c_${cNonce}`, // duplicate username
    password: 'StrongPass#2026!',
  });

  const [resA, resB] = await Promise.all([p1, p2]);
  const statuses = [resA.status, resB.status];
  console.log('  Simultaneous execution responses:', statuses);
  console.log('  Response A:', resA.status, resA.data);
  console.log('  Response B:', resB.status, resB.data);

  const successCount = statuses.filter(s => s === 201).length;
  assert(successCount === 1, `Exactly 1 concurrent attempt must succeed, got ${successCount}`);
  
  const losingStatus = statuses.find(s => s !== 201);
  assert(losingStatus === 409 || losingStatus === 429, `Losing concurrent request must return controlled HTTP 409 Conflict or 429, got ${losingStatus}`);
  console.log(`  [PASS] Exactly 1 concurrent worker succeeded (201); the other received controlled conflict (${losingStatus}).`);
  results.test6_concurrencyIntegrity = 'PASS';

  console.log('\n================================================================');
  console.log('LIFECYCLE & CONCURRENCY AUDIT RESULTS:');
  console.table(results);
  console.log('================================================================');
}

runLifecycleTests().catch(err => {
  console.error('LIFECYCLE AUDIT FAILED:', err);
  process.exit(1);
});
