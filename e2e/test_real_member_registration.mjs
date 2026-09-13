// e2e/test_real_member_registration.mjs
// Real Mobile Flow Reproduction & Comprehensive Regression Test Suite for Monthly Activation QR Architecture

import dns from 'node:dns';
dns.setDefaultResultOrder('ipv4first');
import assert from 'assert';

const SUPABASE_URL = 'https://qwnxbdqzmxyukrbeqrcj.supabase.co';

function generateRandomSuffix() {
  return `${Date.now().toString().slice(-6)}_${Math.floor(1000 + Math.random() * 9000)}`;
}

async function validateToken(token) {
  const url = `${SUPABASE_URL}/functions/v1/validateMemberActivation`;
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ token }),
  });
  const data = await res.json().catch(() => ({}));
  return { status: res.status, data };
}

async function registerMember(payload) {
  const url = `${SUPABASE_URL}/functions/v1/registerMember`;
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });
  const data = await res.json().catch(() => ({}));
  return { status: res.status, data };
}

async function runRealMobileFlowSuite() {
  console.log('================================================================');
  console.log('REAL MOBILE FLOW REPRODUCTION & REGRESSION TEST SUITE');
  console.log(`Supabase URL: ${SUPABASE_URL}`);
  console.log(`Timestamp: ${new Date().toISOString()}`);
  console.log('================================================================\n');

  const testGymSlug = 'solo-fitness';
  const now = new Date();
  const year = now.getUTCFullYear();
  const monthNum = now.getUTCMonth() + 1;
  const monthString = String(monthNum).padStart(2, '0');
  const monthlyToken = `act_${testGymSlug}_${year}_${monthString}`;
  const deepLinkToken = `liftflow://member-activation/${monthlyToken}`;

  const summary = {
    totalTests: 0,
    passed: 0,
    failed: 0,
    results: {},
  };

  function record(testName, status, details = '') {
    summary.totalTests++;
    if (status === 'PASS') {
      summary.passed++;
      console.log(`  [PASS] ${testName} ${details ? '(' + details + ')' : ''}`);
    } else {
      summary.failed++;
      console.error(`  [FAIL] ${testName}: ${details}`);
    }
    summary.results[testName] = status;
  }

  // STEP 1: Test Step 1 Mobile Flow — Validate raw scanned token
  console.log('--- PHASE 1: TOKEN VALIDATION (Step 1 on Mobile) ---');
  {
    console.log('1.1 Validate raw monthly token string:');
    const res = await validateToken(monthlyToken);
    assert.strictEqual(res.status, 200, `Expected 200, got ${res.status}: ${JSON.stringify(res.data)}`);
    assert.strictEqual(res.data.valid, true);
    assert.strictEqual(res.data.gym.slug, testGymSlug);
    record('Token_Validation_Raw', 'PASS', `Gym: ${res.data.gym.name}`);

    console.log('1.2 Validate deep-link formatted token string:');
    const resDeep = await validateToken(deepLinkToken);
    assert.strictEqual(resDeep.status, 200);
    assert.strictEqual(resDeep.data.valid, true);
    record('Token_Validation_DeepLink', 'PASS', 'Deep-link parsed correctly');

    console.log('1.3 Validate invalid/garbage token:');
    const resGarbage = await validateToken('act_nonexistent-gym-999_2026_09');
    assert.ok(resGarbage.status === 404 || resGarbage.status === 400, `Expected 404/400, got ${resGarbage.status}`);
    record('Token_Validation_Invalid', 'PASS', `Rejected with status ${resGarbage.status}`);
  }

  // STEP 2: Consecutive Member Registrations with the SAME Monthly QR
  console.log('\n--- PHASE 2: CONSECUTIVE MEMBER REGISTRATIONS (Step 3 on Mobile) ---');
  const registeredUsers = [];
  const suffixA = generateRandomSuffix();
  const phoneA = `918${Math.floor(10000000 + Math.random() * 90000000)}`;
  const usernameA = `athlete_a_${suffixA}`;

  {
    console.log('2.1 Register Member A with Monthly QR:');
    const resA = await registerMember({
      full_name: `Athlete A ${suffixA}`,
      phone: phoneA,
      username: usernameA,
      password: `Pass#${suffixA}!Secure`,
      activation_token: monthlyToken,
    });
    assert.strictEqual(resA.status, 201, `Member A registration failed: ${JSON.stringify(resA.data)}`);
    assert.ok(resA.data.user_id, 'User ID missing in response');
    registeredUsers.push(resA.data.user_id);
    record('Member_A_Registration', 'PASS', `User ID: ${resA.data.user_id}`);
  }

  {
    console.log('2.2 Register Member B with THE SAME Monthly QR:');
    const suffixB = generateRandomSuffix();
    const phoneB = `918${Math.floor(10000000 + Math.random() * 90000000)}`;
    const usernameB = `athlete_b_${suffixB}`;

    const resB = await registerMember({
      full_name: `Athlete B ${suffixB}`,
      phone: phoneB,
      username: usernameB,
      password: `Pass#${suffixB}!Secure`,
      activation_token: monthlyToken,
    });
    assert.strictEqual(resB.status, 201, `Member B registration failed: ${JSON.stringify(resB.data)}`);
    assert.ok(resB.data.user_id, 'User ID missing in response');
    registeredUsers.push(resB.data.user_id);
    record('Member_B_Registration_Same_QR', 'PASS', `User ID: ${resB.data.user_id}`);
  }

  {
    console.log('2.3 Register Member C with THE SAME Monthly QR:');
    const suffixC = generateRandomSuffix();
    const phoneC = `918${Math.floor(10000000 + Math.random() * 90000000)}`;
    const usernameC = `athlete_c_${suffixC}`;

    const resC = await registerMember({
      full_name: `Athlete C ${suffixC}`,
      phone: phoneC,
      username: usernameC,
      password: `Pass#${suffixC}!Secure`,
      activation_token: monthlyToken,
    });
    assert.strictEqual(resC.status, 201, `Member C registration failed: ${JSON.stringify(resC.data)}`);
    assert.ok(resC.data.user_id, 'User ID missing in response');
    registeredUsers.push(resC.data.user_id);
    record('Member_C_Registration_Same_QR', 'PASS', `User ID: ${resC.data.user_id}`);
  }

  // STEP 3: Post-Registration Token State
  console.log('\n--- PHASE 3: POST-REGISTRATION QR LONGEVITY & PERSISTENCE ---');
  {
    console.log('3.1 Verify Monthly QR remains valid and active after multiple registrations:');
    const resPost = await validateToken(monthlyToken);
    assert.strictEqual(resPost.status, 200, `Expected 200, got ${resPost.status}`);
    assert.strictEqual(resPost.data.valid, true);
    record('Token_Active_Post_Registrations', 'PASS', 'Token remains valid for additional members');
  }

  // STEP 4: Edge Cases & Uniqueness Constraints
  console.log('\n--- PHASE 4: EDGE CASES & UNIQUENESS CONSTRAINTS ---');
  {
    console.log('4.1 Duplicate Phone Rejection:');
    const suffixDupPhone = generateRandomSuffix();
    const resDupPhone = await registerMember({
      full_name: `Duplicate Phone User ${suffixDupPhone}`,
      phone: phoneA, // existing phone
      username: `unique_user_${suffixDupPhone}`,
      password: `Pass#${suffixDupPhone}!Secure`,
      activation_token: monthlyToken,
    });
    assert.strictEqual(resDupPhone.status, 409, `Expected 409 Conflict, got ${resDupPhone.status}: ${JSON.stringify(resDupPhone.data)}`);
    record('Duplicate_Phone_Rejection', 'PASS', 'Correctly rejected with 409 Conflict');

    console.log('4.2 Duplicate Username Rejection:');
    const suffixDupUser = generateRandomSuffix();
    const resDupUser = await registerMember({
      full_name: `Duplicate Username User ${suffixDupUser}`,
      phone: `918${Math.floor(10000000 + Math.random() * 90000000)}`,
      username: usernameA, // existing username
      password: `Pass#${suffixDupUser}!Secure`,
      activation_token: monthlyToken,
    });
    assert.strictEqual(resDupUser.status, 409, `Expected 409 Conflict, got ${resDupUser.status}: ${JSON.stringify(resDupUser.data)}`);
    record('Duplicate_Username_Rejection', 'PASS', 'Correctly rejected with 409 Conflict');

    console.log('4.3 Invalid Password Rejection (Too short):');
    const suffixShortPass = generateRandomSuffix();
    const resShortPass = await registerMember({
      full_name: `Short Pass User ${suffixShortPass}`,
      phone: `918${Math.floor(10000000 + Math.random() * 90000000)}`,
      username: `short_pass_${suffixShortPass}`,
      password: '123',
      activation_token: monthlyToken,
    });
    assert.strictEqual(resShortPass.status, 400, `Expected 400 Bad Request, got ${resShortPass.status}`);
    record('Invalid_Password_Rejection', 'PASS', 'Correctly rejected with 400 Bad Request');
  }

  // STEP 5: Concurrent Registrations
  console.log('\n--- PHASE 5: CONCURRENT REGISTRATIONS ---');
  {
    console.log('5.1 Two simultaneous member registrations:');
    const s1 = generateRandomSuffix();
    const s2 = generateRandomSuffix();
    const [c1, c2] = await Promise.all([
      registerMember({
        full_name: `Concurrent User 1 ${s1}`,
        phone: `918${Math.floor(10000000 + Math.random() * 90000000)}`,
        username: `conc_u1_${s1}`,
        password: `Pass#${s1}!Safe`,
        activation_token: monthlyToken,
      }),
      registerMember({
        full_name: `Concurrent User 2 ${s2}`,
        phone: `918${Math.floor(10000000 + Math.random() * 90000000)}`,
        username: `conc_u2_${s2}`,
        password: `Pass#${s2}!Safe`,
        activation_token: monthlyToken,
      }),
    ]);

    assert.strictEqual(c1.status, 201, `Concurrent 1 failed: ${JSON.stringify(c1.data)}`);
    assert.strictEqual(c2.status, 201, `Concurrent 2 failed: ${JSON.stringify(c2.data)}`);
    record('Concurrent_Registrations', 'PASS', `Both completed with 201`);
  }

  console.log('\n================================================================');
  console.log('TEST RESULTS SUMMARY:');
  console.log(`Total Tests Run: ${summary.totalTests}`);
  console.log(`Passed: ${summary.passed}`);
  console.log(`Failed: ${summary.failed}`);
  console.log('================================================================\n');

  if (summary.failed > 0) {
    process.exit(1);
  }
}

runRealMobileFlowSuite().catch((err) => {
  console.error('\nFatal test runner error:', err);
  process.exit(1);
});
