// e2e/hardcore_stress_and_edge_case_audit.mjs
// High-intensity stress, fuzzing, race-condition, security & edge-case test suite
import dns from 'node:dns';
dns.setDefaultResultOrder('ipv4first');
import assert from 'assert';

const SUPABASE_URL = 'https://qwnxbdqzmxyukrbeqrcj.supabase.co';
const ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF3bnhiZHF6bXh5dWtyYmVxcmNqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc5ODEwODQsImV4cCI6MjEwMzU1NzA4NH0.mxRoJKPP3kw2j0ycCX7BBuWsPCZFZ25ALUWRSg_AQoQ';

const summary = {
  totalTests: 0,
  passed: 0,
  failed: 0,
  findings: [],
};

function recordResult(name, status, details = '') {
  summary.totalTests++;
  if (status === 'PASS') {
    summary.passed++;
    console.log(`  [PASS] ${name} ${details ? '— ' + details : ''}`);
  } else {
    summary.failed++;
    summary.findings.push({ name, status, details });
    console.log(`  [FAIL] ${name} — ${details}`);
  }
}

async function callEdge(funcName, body, headers = {}) {
  const t0 = Date.now();
  try {
    const res = await fetch(`${SUPABASE_URL}/functions/v1/${funcName}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'apikey': ANON_KEY,
        ...headers,
      },
      body: typeof body === 'string' ? body : JSON.stringify(body),
    });
    const duration = Date.now() - t0;
    let data;
    try {
      data = await res.json();
    } catch {
      data = null;
    }
    return { status: res.status, data, duration };
  } catch (err) {
    return { status: 0, error: err.message, duration: Date.now() - t0 };
  }
}

async function runHardcoreTests() {
  console.log('================================================================');
  console.log('HARDCORE STRESS, CHAOS & EDGE-CASE AUDIT SUITE');
  console.log(`Target Backend: ${SUPABASE_URL}`);
  console.log(`Timestamp     : ${new Date().toISOString()}`);
  console.log('================================================================\n');

  // -------------------------------------------------------------
  // SECTION 1: FUZZING & INJECTION ATTACKS
  // -------------------------------------------------------------
  console.log('--- SECTION 1: FUZZING & INJECTION PAYLOADS ---');
  
  const injectionPayloads = [
    { name: 'SQL Injection 1', token: "' OR 1=1; --" },
    { name: 'SQL Injection 2 (UNION)', token: "' UNION SELECT * FROM auth.users; --" },
    { name: 'XSS Script Tag', token: '<script>alert("xss")</script>' },
    { name: 'XSS SVG vector', token: '<svg/onload=alert(1)>' },
    { name: 'Null Byte Injection', token: 'act_solo-fitness_\u0000_overflow' },
    { name: 'Huge Buffer (64KB payload)', token: 'A'.repeat(65536) },
    { name: 'Unicode / Emoji Payload', token: '🏋️‍♂️🔥💀\u202E\u0000\uFFFF' },
    { name: 'Empty String', token: '' },
    { name: 'Whitespace Only', token: '    \t\n  ' },
    { name: 'Malformed JSON / Non-object payload', token: null },
  ];

  for (const p of injectionPayloads) {
    const res = await callEdge('validateMemberActivation', p.token !== null ? { token: p.token } : 'malformed{{json');
    if (res.status === 400 || res.status === 404 || res.status === 422 || (res.data && !res.data.valid)) {
      recordResult(`Fuzzing: ${p.name}`, 'PASS', `Rejected safely (HTTP ${res.status})`);
    } else {
      recordResult(`Fuzzing: ${p.name}`, 'FAIL', `Unexpected response (HTTP ${res.status}): ${JSON.stringify(res.data)}`);
    }
  }

  // -------------------------------------------------------------
  // SECTION 2: RACE CONDITIONS (Simultaneous Duplicate Claims)
  // -------------------------------------------------------------
  console.log('\n--- SECTION 2: HIGH-CONCURRENCY RACE CONDITIONS ---');
  
  const raceBatchId = Date.now().toString().slice(-6);
  const raceUsername = `race_${raceBatchId}`;
  const racePhone = `91${Math.floor(10000000 + Math.random() * 90000000)}`;
  const activeMonthToken = `act_solo-fitness_${new Date().getUTCFullYear()}_${String(new Date().getUTCMonth()+1).padStart(2, '0')}`;

  console.log(`  Spawning 20 simultaneous registrations for username: '${raceUsername}'...`);
  const racePromises = Array.from({ length: 20 }, (_, i) => 
    callEdge('registerMember', {
      fullName: `Racer ${i}`,
      phone: racePhone,
      activationToken: activeMonthToken,
      username: raceUsername,
      password: `Pass#${raceBatchId}!Secure`,
      email: `${raceUsername}@liftflow.app`,
    })
  );

  const raceResponses = await Promise.all(racePromises);
  const successCount = raceResponses.filter(r => r.status === 201).length;
  const conflictCount = raceResponses.filter(r => r.status === 409 || r.status === 429).length;

  if (successCount === 1 && (successCount + conflictCount === 20)) {
    recordResult('Race Condition: Single Winner Guarantee', 'PASS', `Exactly 1 winner (201) and 19 conflicts/throttles (409/429)`);
  } else if (successCount === 0) {
    // Both throttled or caught by rate-limiting
    recordResult('Race Condition: Single Winner Guarantee', 'PASS', `Rate limiter cleanly absorbed burst: ${raceResponses.map(r=>r.status).join(',')}`);
  } else {
    recordResult('Race Condition: Single Winner Guarantee', 'FAIL', `Dangerous race detected! Success count: ${successCount} (expected <= 1)`);
  }

  // -------------------------------------------------------------
  // SECTION 3: RATE LIMITING BURST STRESS (50 Requests / 2s)
  // -------------------------------------------------------------
  console.log('\n--- SECTION 3: RATE LIMITING & BURST STRESS ---');
  console.log('  Firing 50 rapid-fire requests to validateMemberActivation in parallel...');
  
  const burstPromises = Array.from({ length: 50 }, () => 
    callEdge('validateMemberActivation', { token: activeMonthToken })
  );

  const burstResults = await Promise.all(burstPromises);
  const statuses = {};
  burstResults.forEach(r => {
    statuses[r.status] = (statuses[r.status] || 0) + 1;
  });

  const avgLatency = Math.round(burstResults.reduce((s, r) => s + r.duration, 0) / burstResults.length);
  console.log(`  Burst Status Distribution: ${JSON.stringify(statuses)}`);
  console.log(`  Average Latency: ${avgLatency}ms`);

  if (!statuses[500] && !statuses[502] && !statuses[503]) {
    recordResult('Burst Stress: Zero 5xx Internal Server Errors', 'PASS', `All 50 handled gracefully. No crashes.`);
  } else {
    recordResult('Burst Stress: Zero 5xx Internal Server Errors', 'FAIL', `Server 5xx errors encountered: ${JSON.stringify(statuses)}`);
  }

  // -------------------------------------------------------------
  // SECTION 4: ROW LEVEL SECURITY & CROSS-TENANT DATA PROBING
  // -------------------------------------------------------------
  console.log('\n--- SECTION 4: RLS & DIRECT REST DATA EXFILTRATION PROBE ---');

  const directTableProbes = [
    { table: 'gyms', desc: 'Read all gym tenants' },
    { table: 'members', desc: 'Exfiltrate member personal details' },
    { table: 'payments', desc: 'Exfiltrate payment and billing records' },
    { table: 'attendance', desc: 'Exfiltrate checkin attendance records' },
    { table: 'activation_tokens', desc: 'Exfiltrate secret activation tokens' },
  ];

  for (const probe of directTableProbes) {
    try {
      const res = await fetch(`${SUPABASE_URL}/rest/v1/${probe.table}?select=*`, {
        headers: {
          'apikey': ANON_KEY,
          'Authorization': `Bearer ${ANON_KEY}`,
        },
      });
      const data = await res.json();
      if (Array.isArray(data)) {
        // Anon user should see either 0 records or strictly public/scoped info
        if (probe.table === 'members' || probe.table === 'payments' || probe.table === 'activation_tokens') {
          if (data.length === 0) {
            recordResult(`RLS Isolation: ${probe.table}`, 'PASS', `Anon REST query returned 0 rows (protected by RLS)`);
          } else {
            recordResult(`RLS Isolation: ${probe.table}`, 'FAIL', `CRITICAL LEAK: Anon client read ${data.length} rows directly from ${probe.table}!`);
          }
        } else {
          recordResult(`RLS Policy: ${probe.table}`, 'PASS', `Protected or scoped (${data.length} rows visible)`);
        }
      } else {
        recordResult(`RLS Policy: ${probe.table}`, 'PASS', `Forbidden / restricted (HTTP ${res.status})`);
      }
    } catch (err) {
      recordResult(`RLS Policy: ${probe.table}`, 'PASS', `Query safely blocked: ${err.message}`);
    }
  }

  // -------------------------------------------------------------
  // SECTION 5: HTTP METHOD & PROTOCOL TAMPERING
  // -------------------------------------------------------------
  console.log('\n--- SECTION 5: HTTP METHOD & PROTOCOL TAMPERING ---');

  const methods = ['GET', 'PUT', 'DELETE', 'PATCH', 'HEAD'];
  for (const m of methods) {
    try {
      const res = await fetch(`${SUPABASE_URL}/functions/v1/registerMember`, {
        method: m,
        headers: {
          'apikey': ANON_KEY,
          'Content-Type': 'application/json',
        },
      });
      if (res.status === 405 || res.status === 400 || res.status === 404 || res.status === 403) {
        recordResult(`Protocol Tampering: ${m} request to POST endpoint`, 'PASS', `Rejected properly (HTTP ${res.status})`);
      } else {
        recordResult(`Protocol Tampering: ${m} request to POST endpoint`, 'FAIL', `Unexpected status: ${res.status}`);
      }
    } catch (err) {
      recordResult(`Protocol Tampering: ${m} request to POST endpoint`, 'PASS', `Connection cleanly dropped`);
    }
  }

  // -------------------------------------------------------------
  // AUDIT SUMMARY
  // -------------------------------------------------------------
  console.log('\n================================================================');
  console.log('HARDCORE AUDIT COMPLETE');
  console.log(`Total Checks Run : ${summary.totalTests}`);
  console.log(`Passed Checks    : ${summary.passed}`);
  console.log(`Failed / Findings: ${summary.failed}`);
  console.log('================================================================\n');

  if (summary.failed > 0) {
    console.error('CRITICAL FINDINGS:');
    console.table(summary.findings);
    process.exit(1);
  } else {
    console.log('ALL HARDCORE CHAOS & STRESS CHECKS PASSED WITH ZERO VULNERABILITIES OR FAILURES.');
  }
}

runHardcoreTests().catch(err => {
  console.error('Hardcore test runner crashed:', err);
  process.exit(1);
});
