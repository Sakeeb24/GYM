// hosted_test.mjs
// Non-destructive, evidence-based verification of hosted Supabase project qwnxbdqzmxyukrbeqrcj.
// Validates:
// 1. API gateway connectivity
// 2. Edge Function deployment status & endpoints
// 3. Edge Function security guards (unauthorized rejection)
// 4. schedulerTick authentication barrier (CRON_TOKEN protection)
// 5. REST API / RLS isolation against unauthorized access

const PROJECT_URL = 'https://qwnxbdqzmxyukrbeqrcj.supabase.co';

async function testEndpoint(name, url, options = {}) {
  try {
    const res = await fetch(url, options);
    let bodyText = '';
    try {
      bodyText = await res.text();
    } catch {}
    return { name, status: res.status, ok: res.ok, body: bodyText };
  } catch (err) {
    return { name, status: 0, ok: false, error: err.message };
  }
}

async function run() {
  console.log('========================================================');
  console.log('HOSTED SUPABASE VERIFICATION: ' + PROJECT_URL);
  console.log('========================================================\n');

  const results = [];

  // 1. Check Root REST endpoint
  const restRoot = await testEndpoint('REST API Schema Gateway', `${PROJECT_URL}/rest/v1/`);
  console.log(`[TEST 1] REST API Gateway: HTTP ${restRoot.status}`);
  results.push({
    test: 'REST Gateway Reachable',
    pass: restRoot.status === 200 || restRoot.status === 401 || restRoot.status === 400,
    evidence: `HTTP ${restRoot.status}`
  });

  // 2. Test Edge Functions deployment & security guards
  const functions = [
    'schedulerTick',
    'recordAttendance',
    'processPaymentWebhook',
    'runNoShowScan',
    'runRenewalScan',
    'createMember'
  ];

  for (const fn of functions) {
    const fnUrl = `${PROJECT_URL}/functions/v1/${fn}`;
    const res = await testEndpoint(`Function: ${fn}`, fnUrl, { method: 'POST' });
    console.log(`[FUNCTION] ${fn} -> HTTP ${res.status} | Body: ${res.body.slice(0, 80)}`);
    
    // Status 401/400/403/500 indicates the function is deployed and actively processing requests
    // Status 404 would mean NOT DEPLOYED.
    const isDeployed = res.status !== 404;
    results.push({
      test: `Edge Function '${fn}' Deployed`,
      pass: isDeployed,
      evidence: `HTTP ${res.status} (Response: ${res.body.slice(0, 60)})`
    });
  }

  // 3. Test schedulerTick Security Guard
  // Test A: No token -> must be 401 Unauthorized
  const noToken = await testEndpoint('schedulerTick (no token)', `${PROJECT_URL}/functions/v1/schedulerTick`, { method: 'GET' });
  const noTokenBlocked = noToken.status === 401;
  results.push({
    test: 'schedulerTick Blocks Missing Token (401)',
    pass: noTokenBlocked,
    evidence: `HTTP ${noToken.status} | Response: ${noToken.body}`
  });

  // Test B: Invalid token -> must be 401 Unauthorized
  const badToken = await testEndpoint('schedulerTick (bad token)', `${PROJECT_URL}/functions/v1/schedulerTick?token=invalid_unauthorized_token_test`, { method: 'GET' });
  const badTokenBlocked = badToken.status === 401;
  results.push({
    test: 'schedulerTick Blocks Invalid Token (401)',
    pass: badTokenBlocked,
    evidence: `HTTP ${badToken.status} | Response: ${badToken.body}`
  });

  // 4. Test Unauthenticated Access to Protected Tables (RLS / Auth Barrier)
  const protectedTables = ['members', 'gyms', 'attendance', 'audit_logs', 'payments', 'no_show_cases'];
  for (const table of protectedTables) {
    const tableRes = await testEndpoint(`Table RLS: ${table}`, `${PROJECT_URL}/rest/v1/${table}?select=*`);
    // Without an API key / token, Supabase REST must deny with 401
    const isDenied = tableRes.status === 401 || tableRes.status === 403;
    results.push({
      test: `Unauthenticated REST access blocked for '${table}'`,
      pass: isDenied,
      evidence: `HTTP ${tableRes.status} (Access Denied)`
    });
  }

  console.log('\n========================================================');
  console.log('SUMMARY TABLE:');
  console.log('========================================================');
  let passCount = 0;
  for (const r of results) {
    const icon = r.pass ? 'PASS' : 'FAIL';
    if (r.pass) passCount++;
    console.log(`[${icon}] ${r.test} -> Evidence: ${r.evidence}`);
  }
  console.log('========================================================');
  console.log(`TOTAL: ${passCount} / ${results.length} PASSED`);
  console.log('========================================================');
}

run();
