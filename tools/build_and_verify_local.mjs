// tools/build_and_verify_local.mjs
// Secure local build and API key verification tool.
// Never prints, logs, or commits keys.

import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import { execSync, spawnSync } from 'child_process';

const URL = 'https://qwnxbdqzmxyukrbeqrcj.supabase.co';

function loadKey() {
  if (process.env.SUPABASE_ANON_KEY) {
    return process.env.SUPABASE_ANON_KEY.trim();
  }

  const envFiles = ['local.evn', 'local.env', '.env.local', '.env'];
  for (const file of envFiles) {
    const filePath = path.join(process.cwd(), file);
    if (fs.existsSync(filePath)) {
      const content = fs.readFileSync(filePath, 'utf-8');
      for (const line of content.split('\n')) {
        const trimmed = line.trim();
        if (trimmed.startsWith('SUPABASE_ANON_KEY=')) {
          const val = trimmed.substring('SUPABASE_ANON_KEY='.length).trim().replace(/^["']|["']$/g, '');
          if (val) return val;
        }
        if (trimmed.startsWith('SUPABASE_CLIENT_KEY=')) {
          const val = trimmed.substring('SUPABASE_CLIENT_KEY='.length).trim().replace(/^["']|["']$/g, '');
          if (val) return val;
        }
      }
    }
  }
  return null;
}

async function verifyKey(key) {
  if (!key) {
    console.error('\n[ERROR] No client key found.');
    console.error('Please put your active client key in local.env (ignored by git):');
    console.error('SUPABASE_ANON_KEY=your_key_here\n');
    process.exit(1);
  }

  // Security guard: Ensure it is NEVER a service_role key or secret key
  if (key.startsWith('sb_secret_') || key.toLowerCase().includes('service_role')) {
    console.error('\n[SECURITY ERROR] Detected service_role or secret key!');
    console.error('Do NOT use server secrets in the mobile client. Use only publishable or anon key.\n');
    process.exit(1);
  }

  const hash = crypto.createHash('sha256').update(key).digest('hex').slice(0, 8);
  const keyType = key.startsWith('sb_publishable_') ? 'Publishable Key' : (key.startsWith('eyJ') ? 'JWT Anon Key' : 'Custom Client Key');

  console.log('================================================================');
  console.log('SUPABASE CLIENT KEY VERIFICATION (Zero Secret Exposure)');
  console.log('================================================================');
  console.log(`Target URL  : ${URL}`);
  console.log(`Key Type    : ${keyType}`);
  console.log(`Key Length  : ${key.length} chars`);
  console.log(`Fingerprint : SHA256:${hash}...`);
  console.log('----------------------------------------------------------------');

  // Test 1: Auth settings endpoint
  console.log('1. Testing Auth settings endpoint (/auth/v1/settings)...');
  let authOk = false;
  try {
    const res = await fetch(`${URL}/auth/v1/settings`, {
      headers: {
        'apikey': key,
        'Authorization': `Bearer ${key}`,
      }
    });
    console.log(`   Result: HTTP ${res.status}`);
    if (res.status === 200) {
      authOk = true;
      console.log('   [PASS] Auth settings accepted the key.');
    } else {
      console.log(`   [FAIL] Auth settings rejected the key (HTTP ${res.status}).`);
    }
  } catch (err) {
    console.log(`   [FAIL] Network connection error: ${err.message}`);
  }

  // Test 2: REST endpoint
  console.log('\n2. Testing REST endpoint (/rest/v1/gym_settings)...');
  let restOk = false;
  try {
    const res = await fetch(`${URL}/rest/v1/gym_settings?select=gym_id`, {
      headers: {
        'apikey': key,
      }
    });
    console.log(`   Result: HTTP ${res.status}`);
    if (res.status === 200 || res.status === 400) {
      restOk = true;
      console.log('   [PASS] REST API gateway accepted the client key.');
    } else {
      console.log(`   [FAIL] REST endpoint returned HTTP ${res.status}`);
    }
  } catch (err) {
    console.log(`   [FAIL] Network connection error: ${err.message}`);
  }

  console.log('================================================================');
  if (!authOk || !restOk) {
    console.error('\n[GATEWAY REJECTED] Key verification failed. Please ensure the key copied from the dashboard is the active public/anon key.');
    process.exit(1);
  }

  console.log('\n[PASS] Key is fully valid and accepted by Supabase Gateway.\n');
  return key;
}

async function buildAndInstall(key) {
  console.log('================================================================');
  console.log('BUILDING NEW DEBUG APK WITH VALIDATED DART-DEFINES');
  console.log('================================================================\n');

  console.log('1. Running flutter clean...');
  execSync('flutter clean', { stdio: 'inherit' });

  console.log('\n2. Running flutter pub get...');
  execSync('flutter pub get', { stdio: 'inherit' });

  console.log('\n3. Building Debug APK...');
  const buildArgs = [
    'build', 'apk', '--debug',
    `--dart-define=ENV=dev`,
    `--dart-define=SUPABASE_URL=${URL}`,
    `--dart-define=SUPABASE_ANON_KEY=${key}`,
    `--dart-define=APP_NAME=LiftFlow`,
  ];

  const buildRes = spawnSync('flutter', buildArgs, { stdio: 'inherit', shell: true });
  if (buildRes.status !== 0) {
    console.error('\n[ERROR] Flutter build failed.');
    process.exit(1);
  }

  console.log('\n================================================================');
  console.log('INSTALLING DEBUG APK ON PHYSICAL DEVICE');
  console.log('================================================================\n');

  const apkPath = path.join('build', 'app', 'outputs', 'flutter-apk', 'app-debug.apk');
  if (!fs.existsSync(apkPath)) {
    console.error(`[ERROR] APK file not found at ${apkPath}`);
    process.exit(1);
  }

  console.log('Installing to connected device via ADB...');
  execSync(`adb install -r ${apkPath}`, { stdio: 'inherit' });

  console.log('\nLaunching LiftFlow app on device...');
  try {
    execSync('adb shell am start -n com.liftflow.liftflow/.MainActivity', { stdio: 'inherit' });
  } catch {}

  console.log('\n================================================================');
  console.log('SUCCESS: New APK installed and launched on physical device!');
  console.log('================================================================\n');
}

async function main() {
  const key = loadKey();
  const validKey = await verifyKey(key);
  await buildAndInstall(validKey);
}

main();
