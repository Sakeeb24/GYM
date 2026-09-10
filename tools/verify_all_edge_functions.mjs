// tools/verify_all_edge_functions.mjs
import https from 'https';

const SUPABASE_URL = 'https://qwnxbdqzmxyukrbeqrcj.supabase.co';

async function getLiveAnonKey() {
  const resp = await fetch('https://sakeeb24.github.io/GYM/main.dart.js');
  const text = await resp.text();
  const match = text.match(/eyJ[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+/);
  if (!match) throw new Error('Could not extract anon key from live main.dart.js');
  return match[0];
}

async function testEdgeFunction(name, { method = 'POST', headers = {}, body = null, checkOptions = true } = {}) {
  const key = await getLiveAnonKey();
  const results = {};

  // 1. Check OPTIONS (CORS)
  if (checkOptions) {
    const optResp = await fetch(`${SUPABASE_URL}/functions/v1/${name}`, {
      method: 'OPTIONS',
      headers: {
        'Origin': 'https://sakeeb24.github.io',
        'Access-Control-Request-Method': method,
      },
    });
    const allowOrigin = optResp.headers.get('access-control-allow-origin');
    results.corsOptionsStatus = optResp.status;
    results.corsAllowOrigin = allowOrigin;
    results.corsOk = optResp.status === 200 || optResp.status === 204;
  }

  // 2. Unauthenticated check (no Authorization header)
  const unauthResp = await fetch(`${SUPABASE_URL}/functions/v1/${name}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      'apikey': key,
      ...headers,
    },
    body: body ? JSON.stringify(body) : JSON.stringify({}),
  });
  results.unauthStatus = unauthResp.status;
  try {
    results.unauthBody = await unauthResp.json();
  } catch {
    results.unauthBody = await unauthResp.text();
  }

  // 3. Authenticated / Standard Invocation check with Anon Key
  const anonAuthResp = await fetch(`${SUPABASE_URL}/functions/v1/${name}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      'apikey': key,
      'Authorization': `Bearer ${key}`,
      ...headers,
    },
    body: body ? JSON.stringify(body) : JSON.stringify({}),
  });
  results.anonAuthStatus = anonAuthResp.status;
  try {
    results.anonAuthBody = await anonAuthResp.json();
  } catch {
    results.anonAuthBody = await anonAuthResp.text();
  }

  return results;
}

async function run() {
  console.log('================================================================');
  console.log('EDGE FUNCTION LIVE PRODUCTION AUDIT');
  console.log(`Supabase URL: ${SUPABASE_URL}`);
  console.log('================================================================\n');

  const functionsToTest = [
    'registerOwner',
    'registerMember',
    'createMember',
    'createMemberActivation',
    'validateMemberActivation',
    'recoverPassword',
    'recordAttendance',
    'createRazorpayOrder',
    'processPaymentWebhook',
    'runNoShowScan',
    'runRenewalScan',
    'schedulerTick',
  ];

  const auditReport = {};

  for (const fn of functionsToTest) {
    process.stdout.write(`Testing Edge Function [${fn}]... `);
    try {
      const res = await testEdgeFunction(fn);
      auditReport[fn] = {
        status: 'VERIFIED',
        cors: res.corsOk ? 'PASS' : 'FAIL',
        unauthStatus: res.unauthStatus,
        anonAuthStatus: res.anonAuthStatus,
        sampleResponse: typeof res.anonAuthBody === 'object' ? JSON.stringify(res.anonAuthBody) : String(res.anonAuthBody).slice(0, 80),
      };
      console.log(`CORS: ${res.corsOk ? '✓' : '✗'}, Status: ${res.anonAuthStatus}`);
    } catch (err) {
      auditReport[fn] = {
        status: 'ERROR',
        error: err.message,
      };
      console.log(`ERROR: ${err.message}`);
    }
  }

  console.log('\n================================================================');
  console.log('EDGE FUNCTION SUMMARY TABLE');
  console.log('================================================================');
  console.table(auditReport);
}

run().catch(console.error);
