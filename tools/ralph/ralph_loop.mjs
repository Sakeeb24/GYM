/**
 * Ralph Loop CLI Harness for LiftFlow / GYM (Node.js ESM)
 * Works alongside GSD, CodeRabbit, and Antigravity.
 */
import fs from 'node:fs';
import path from 'node:path';
import { execSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const projectRoot = path.resolve(__dirname, '..', '..');

const ralphDir = path.join(projectRoot, '.agents', 'ralph');
const stateFile = path.join(ralphDir, 'state.json');
const logFile = path.join(ralphDir, 'iterations.log');

function ensureDirectories() {
  if (!fs.existsSync(ralphDir)) {
    fs.mkdirSync(ralphDir, { recursive: true });
  }
}

function getState(defaultMax = 5) {
  ensureDirectories();
  if (fs.existsSync(stateFile)) {
    try {
      return JSON.parse(fs.readFileSync(stateFile, 'utf8'));
    } catch {
      // fallback
    }
  }
  return {
    task_name: '',
    current_iteration: 0,
    max_iterations: defaultMax,
    status: 'IDLE',
    last_test_passed: false,
    last_analyze_passed: false,
    coderabbit_review_passed: false,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  };
}

function saveState(state) {
  ensureDirectories();
  state.updated_at = new Date().toISOString();
  fs.writeFileSync(stateFile, JSON.stringify(state, null, 2), 'utf8');
}

function appendLog(message) {
  ensureDirectories();
  const timestamp = new Date().toISOString();
  fs.appendFileSync(logFile, `[${timestamp}] ${message}\n`, 'utf8');
}

function checkGitSafety() {
  console.log('\x1b[36m[SAFETY] Performing Git Safety Checks...\x1b[0m');
  try {
    const status = execSync('git status --porcelain', { cwd: projectRoot, encoding: 'utf8' });
    const sensitivePatterns = [/\.env$/, /\.key$/, /service_role/, /id_rsa/];
    for (const line of status.split('\n')) {
      for (const pat of sensitivePatterns) {
        if (pat.test(line)) {
          console.warn(`\x1b[33m[ALERT] Sensitive file in working tree: ${line}\x1b[0m`);
          return false;
        }
      }
    }
  } catch (err) {
    console.warn('[SAFETY] Warning running git status:', err.message);
  }
  console.log('\x1b[32m[SAFETY] Git safety check passed. Working tree safe.\x1b[0m');
  return true;
}

const args = process.argv.slice(2);
const action = args[0] || 'status';

function parseArg(key, defaultValue = '') {
  const idx = args.indexOf(key);
  if (idx !== -1 && idx + 1 < args.length) {
    return args[idx + 1];
  }
  return defaultValue;
}

switch (action) {
  case 'init': {
    ensureDirectories();
    const state = getState();
    saveState(state);
    if (!fs.existsSync(logFile)) {
      fs.writeFileSync(logFile, '# Ralph Loop Iteration Log for LiftFlow / GYM\n', 'utf8');
    }
    appendLog('Ralph Loop initialized.');
    console.log(`\x1b[32mRalph Loop initialized successfully at: ${ralphDir}\x1b[0m`);
    break;
  }

  case 'status': {
    const state = getState();
    console.log('\x1b[36m==========================================\x1b[0m');
    console.log('\x1b[36m   RALPH LOOP STATUS - LiftFlow / GYM     \x1b[0m');
    console.log('\x1b[36m==========================================\x1b[0m');
    console.log(`Active Task        : ${state.task_name || '[None]'}`);
    console.log(`Status             : ${state.status}`);
    console.log(`Current Iteration  : ${state.current_iteration} / ${state.max_iterations}`);
    console.log(`Target Tests Passed: ${state.last_test_passed}`);
    console.log(`Analyze Passed     : ${state.last_analyze_passed}`);
    console.log(`CodeRabbit Review  : ${state.coderabbit_review_passed ? 'PASSED' : 'PENDING/REQUIRED'}`);
    console.log(`Last Updated       : ${state.updated_at}`);
    console.log('------------------------------------------');
    checkGitSafety();
    break;
  }

  case 'start-task': {
    const taskName = parseArg('--task', parseArg('-t', ''));
    const maxIter = parseInt(parseArg('--max', '5'), 10);
    if (!taskName) {
      console.error('\x1b[31mError: Please provide task name via --task "<name>"\x1b[0m');
      process.exit(1);
    }
    const state = getState(maxIter);
    state.task_name = taskName;
    state.current_iteration = 0;
    state.max_iterations = maxIter;
    state.status = 'IN_PROGRESS';
    state.last_test_passed = false;
    state.last_analyze_passed = false;
    state.coderabbit_review_passed = false;
    saveState(state);
    appendLog(`Started task: '${taskName}' (Max Iterations: ${maxIter})`);
    console.log(`\x1b[32mTask '${taskName}' started. Max iterations: ${maxIter}\x1b[0m`);
    break;
  }

  case 'verify-step': {
    const targetTest = parseArg('--test', 'test/business_rules/business_rules_test.dart');
    const state = getState();
    state.current_iteration += 1;
    console.log(`\n\x1b[33m--- Iteration ${state.current_iteration} of ${state.max_iterations} ---\x1b[0m`);

    if (state.current_iteration > state.max_iterations) {
      state.status = 'STOPPED_MAX_ITERATIONS';
      saveState(state);
      appendLog(`[STOP] Task '${state.task_name}' reached maximum iterations (${state.max_iterations}). Human review required.`);
      console.error(`\x1b[31mMaximum iterations reached. Halting loop for human review.\x1b[0m`);
      process.exit(1);
    }

    if (!checkGitSafety()) {
      state.status = 'BLOCKED';
      saveState(state);
      appendLog(`[BLOCKED] Safety check failed.`);
      process.exit(1);
    }

    let testPassed = false;
    try {
      console.log(`\x1b[36m[TEST] Running targeted test: ${targetTest}\x1b[0m`);
      execSync(`flutter test ${targetTest}`, { cwd: projectRoot, stdio: 'inherit' });
      testPassed = true;
      console.log('\x1b[32m[TEST] Targeted test passed!\x1b[0m');
    } catch {
      console.warn('\x1b[33m[TEST] Targeted test failed.\x1b[0m');
    }

    let analyzePassed = false;
    try {
      console.log(`\x1b[36m[ANALYZE] Running flutter analyze...\x1b[0m`);
      execSync(`flutter analyze --no-fatal-infos`, { cwd: projectRoot, stdio: 'inherit' });
      analyzePassed = true;
      console.log('\x1b[32m[ANALYZE] Flutter analyze passed cleanly!\x1b[0m');
    } catch {
      console.warn('\x1b[33m[ANALYZE] Flutter analyze identified issues.\x1b[0m');
    }

    state.last_test_passed = testPassed;
    state.last_analyze_passed = analyzePassed;
    saveState(state);
    appendLog(`Iteration ${state.current_iteration}/${state.max_iterations} - Tests: ${testPassed ? 'PASS' : 'FAIL'}, Analyze: ${analyzePassed ? 'PASS' : 'FAIL'}`);
    break;
  }

  case 'coderabbit-check': {
    const state = getState();
    console.log('\x1b[35m[CODERABBIT GATE] Checking CodeRabbit Review Status...\x1b[0m');
    if (!state.last_test_passed || !state.last_analyze_passed) {
      console.warn('\x1b[33mCodeRabbit review gate cannot pass while tests or analysis are failing.\x1b[0m');
      process.exit(1);
    }
    console.log('\x1b[36mCodeRabbit Gate Requirement: Request review using CodeRabbit plugin (code-reviewer subagent / code-review skill).\x1b[0m');
    console.log('\x1b[36mTask completes when zero unresolved Critical or High findings remain.\x1b[0m');
    break;
  }

  case 'log-iteration': {
    const summary = parseArg('--summary', '');
    const status = parseArg('--status', 'IN_PROGRESS');
    const state = getState();
    if (summary) {
      appendLog(`[LOG] Iteration ${state.current_iteration} Summary: ${summary} | Status: ${status}`);
    }
    state.status = status;
    saveState(state);
    console.log(`\x1b[32mIteration logged. Current status: ${status}\x1b[0m`);
    break;
  }

  case 'stop': {
    const reason = parseArg('--reason', 'Manually stopped');
    const state = getState();
    state.status = 'STOPPED';
    saveState(state);
    appendLog(`[STOP] ${reason}`);
    console.log(`\x1b[33mRalph Loop stopped: ${reason}\x1b[0m`);
    break;
  }

  case 'reset-state': {
    ensureDirectories();
    const state = {
      task_name: '',
      current_iteration: 0,
      max_iterations: 5,
      status: 'IDLE',
      last_test_passed: false,
      last_analyze_passed: false,
      coderabbit_review_passed: false,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };
    saveState(state);
    appendLog('State reset to IDLE.');
    console.log('\x1b[32mRalph Loop state reset to IDLE.\x1b[0m');
    break;
  }

  default:
    console.log(`Unknown action: ${action}. Available: init, status, start-task, verify-step, coderabbit-check, log-iteration, stop, reset-state`);
}
