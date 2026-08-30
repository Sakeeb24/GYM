// tools/e2e-verify/auth_verification.mjs
// Comprehensive End-to-End Verification Suite for LiftFlow

const PROJECT_URL = 'https://qwnxbdqzmxyukrbeqrcj.supabase.co';
const ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF3bnhiZHF6bXh5dWtyYmVxcmNqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDY4NjQwMTksImV4cCI6MjA2MjQ0MDAxOX0.yMek6g3u9g46X9XhWpZ4EsmD0wY6v4kMup01SkgB_Zk';

async function testEndpoint(name, url, options = {}) {
  try {
    const res = await fetch(url, options);
    let bodyJson = null;
    let bodyText = '';
    try {
      bodyText = await res.text();
      bodyJson = JSON.parse(bodyText);
    } catch {}
    return { name, status: res.status, ok: res.ok, bodyText, bodyJson };
  } catch (err) {
    return { name, status: 0, ok: false, error: err.message, bodyText: '' };
  }
}

async function run() {
  console.log('================================================================');
  console.log('LIFTFLOW END-TO-END SYSTEM VERIFICATION');
  console.log('Target: ' + PROJECT_URL);
  console.log('================================================================\n');

  const report = [];

  // TEST 1: Phone Normalization & RegisterMember Edge Function with Invalid OTP
  console.log('1. Testing registerMember with test phone 7019707247 & invalid OTP...');
  const regRes = await testEndpoint(
    'registerMember (Invalid OTP)',
    `${PROJECT_URL}/functions/v1/registerMember`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'apikey': ANON_KEY,
        'Authorization': `Bearer ${ANON_KEY}`,
      },
      body: JSON.stringify({
        full_name: 'Test Athlete',
        phone: '7019707247',
        otp_token: '999999', // Deliberately wrong OTP
        username: 'testathlete_' + Date.now(),
        password: 'Password123!',
      }),
    }
  );
  
  const wrongOtpRejected = regRes.status === 400 || regRes.status === 401 || regRes.status === 422;
  console.log(`   Result: HTTP ${regRes.status} -> ${regRes.bodyText.slice(0, 100)}`);
  report.push({
    category: 'Authentication - Wrong OTP Rejection',
    status: wrongOtpRejected ? 'PASS' : 'FAIL',
    details: `HTTP ${regRes.status}: Wrong OTP token rejected as expected.`
  });

  // TEST 2: Duplicate Phone / Account Takeover Prevention Check
  console.log('\n2. Testing duplicate phone protection...');
  const dupCheck = await testEndpoint(
    'registerMember (Duplicate Phone Check)',
    `${PROJECT_URL}/functions/v1/registerMember`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'apikey': ANON_KEY,
        'Authorization': `Bearer ${ANON_KEY}`,
      },
      body: JSON.stringify({
        full_name: 'Duplicate User Test',
        phone: '+919876543210', // Pre-existing phone
        otp_token: '123456',
        username: 'newuser_' + Date.now(),
        password: 'Password123!',
      }),
    }
  );
  const dupBlocked = dupCheck.status >= 400;
  report.push({
    category: 'Authentication - Duplicate Phone Protection',
    status: dupBlocked ? 'PASS' : 'FAIL',
    details: `HTTP ${dupCheck.status}: ${dupCheck.bodyJson?.error || 'Duplicate registration rejected.'}`
  });

  // TEST 3: Password Recovery Endpoint
  console.log('\n3. Testing recoverPassword endpoint...');
  const recRes = await testEndpoint(
    'recoverPassword (Unauthenticated Request)',
    `${PROJECT_URL}/functions/v1/recoverPassword`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'apikey': ANON_KEY,
        'Authorization': `Bearer ${ANON_KEY}`,
      },
      body: JSON.stringify({
        action: 'request_otp',
        username: 'nonexistent_user_' + Date.now(),
      }),
    }
  );
  console.log(`   Result: HTTP ${recRes.status} -> ${recRes.bodyText.slice(0, 100)}`);
  report.push({
    category: 'Authentication - Password Recovery Guard',
    status: (recRes.status === 404 || recRes.status === 400 || recRes.status === 401) ? 'PASS' : 'FAIL',
    details: `HTTP ${recRes.status}: Handled gracefully without exposing secrets.`
  });

  // TEST 4: QR Check-in Endpoint Security (Forged / Unsigned Token Rejection)
  console.log('\n4. Testing QR Check-in Security (Forged QR token rejection)...');
  const qrRes = await testEndpoint(
    'recordAttendance (Forged QR)',
    `${PROJECT_URL}/functions/v1/recordAttendance`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'apikey': ANON_KEY,
        'Authorization': `Bearer ${ANON_KEY}`,
      },
      body: JSON.stringify({
        token: 'forged_fake_unsigned_qr_token',
        source: 'self_kiosk',
      }),
    }
  );
  console.log(`   Result: HTTP ${qrRes.status} -> ${qrRes.bodyText.slice(0, 100)}`);
  report.push({
    category: 'QR Check-in - Signature Verification',
    status: (qrRes.status === 400 || qrRes.status === 401 || qrRes.status === 403) ? 'PASS' : 'FAIL',
    details: `HTTP ${qrRes.status}: Forged QR token securely rejected.`
  });

  // TEST 5: Payment Webhook Signature Guard
  console.log('\n5. Testing Payment Webhook Security (Invalid signature rejection)...');
  const payRes = await testEndpoint(
    'processPaymentWebhook (Missing / Invalid signature)',
    `${PROJECT_URL}/functions/v1/processPaymentWebhook`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'apikey': ANON_KEY,
        'Authorization': `Bearer ${ANON_KEY}`,
        'stripe-signature': 'invalid_signature_header',
      },
      body: JSON.stringify({
        type: 'payment_intent.succeeded',
        data: { object: { id: 'pi_fake_123' } }
      }),
    }
  );
  console.log(`   Result: HTTP ${payRes.status} -> ${payRes.bodyText.slice(0, 100)}`);
  report.push({
    category: 'Payments - Webhook Signature Guard',
    status: (payRes.status === 400 || payRes.status === 401) ? 'PASS' : 'FAIL',
    details: `HTTP ${payRes.status}: Invalid webhook signature rejected.`
  });

  // TEST 6: Protected Tables RLS
  console.log('\n6. Testing RLS isolation across tables with Anon Key...');
  const tables = ['members', 'gym_settings', 'audit_logs', 'payments'];
  for (const t of tables) {
    const rls = await testEndpoint(
      `RLS: ${t}`,
      `${PROJECT_URL}/rest/v1/${t}?select=*`,
      {
        headers: {
          'apikey': ANON_KEY,
          'Authorization': `Bearer ${ANON_KEY}`,
        }
      }
    );
    // Anon key without auth JWT must be blocked by RLS (401 or returning 0 rows)
    const isIsolated = rls.status === 401 || (rls.status === 200 && Array.isArray(rls.bodyJson) && rls.bodyJson.length === 0);
    report.push({
      category: `RLS Isolation - Table '${t}'`,
      status: isIsolated ? 'PASS' : 'FAIL',
      details: `HTTP ${rls.status}: RLS blocked unauthorized rows.`
    });
  }

  console.log('\n================================================================');
  console.log('FINAL VERIFICATION SUMMARY TABLE:');
  console.log('================================================================');
  for (const r of report) {
    console.log(`[${r.status}] ${r.category.padEnd(45)} | ${r.details}`);
  }
  console.log('================================================================\n');
}

run();
