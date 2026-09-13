---
name: ralph-loop
description: >-
  Iterative autonomous implementation and testing loop for LiftFlow / GYM.
  Works alongside GSD (planning/context) and CodeRabbit (independent code review).
  Enforces test-driven verification, maximum iteration bounds, git safety, and LiftFlow business rule invariants.
---

# Ralph Loop Workflow: LiftFlow / GYM

Ralph is the iterative implementation and test harness agent loop for the LiftFlow / GYM project. It executes focused, single-task implementation cycles while maintaining safety guardrails and strict quality gates.

---

## 1. Core Architectural Separation of Responsibilities

Role | System | Primary Responsibility
:--- | :--- | :---
**Planning & Specifications** | **GSD** (`.agent/skills/gsd-*`) | Requirements, milestones, phases, workstreams, state tracking, and acceptance criteria.
**Iterative Implementation** | **Ralph Loop** (`ralph-loop` skill / PowerShell harness) | Single-task pick, smallest correct edit, targeted test execution, flutter analyze, and iteration logging.
**Independent Review Gate** | **CodeRabbit** (`code-review` plugin) | Static analysis, architecture integrity, security scanning, anti-pattern checks, and PR readiness validation.
**Execution Environment** | **Antigravity IDE & CLI** | Agent tool execution, background commands, terminal orchestration, and file operations on Windows.

> [!IMPORTANT]
> - GSD plans and tracks; Ralph executes iteratively; CodeRabbit validates independently.
> - Never bypass the CodeRabbit review gate before marking a task complete.
> - Never modify planning files or phase definitions inside Ralph execution cycles unless explicitly updating task completion status.

---

## 2. LiftFlow Business Rules (Strict Invariants)

Ralph must **NEVER** alter or violate these immutable core business rules to make a test pass or satisfy a prompt:

1. **Member Registration Has NO OTP**:
   - The registration workflow is strictly:
     `Personal Details` $\rightarrow$ `Gym Verification (Monthly QR Scan / Gym Code)` $\rightarrow$ `Username + Password Selection` $\rightarrow$ `Account Created & Activated`.
   - Never introduce SMS OTP, email OTP, or verification code delays into member sign-up.

2. **Monthly Activation QR Model**:
   - The gym QR is a **Monthly Activation QR**, NOT a one-time activation token.
   - Exactly **one active monthly QR per gym per calendar month**.
   - The **same QR code is reused** by all new members registering at that gym during the calendar month.
   - It is **NEVER consumed or invalidated** upon a member's registration.
   - It automatically expires upon calendar month rollover, at which point the gym owner displays the new month's QR.

3. **Tenant Isolation & Security**:
   - All database tables enforce Row Level Security (RLS).
   - Member access must remain strictly isolated by `gym_id` and auth UID.
   - Never weaken RLS, bypass security policies, or expose service role keys.

---

## 3. Ralph Loop Iteration Cycle (Step-by-Step)

Each Ralph iteration follows an uncompromising protocol:

1. **State Ingestion**: Read current GSD status (`.agents/ralph/state.json`, `.planning/` or active GSD milestone).
2. **Task Selection**: Select **exactly one** highest-priority incomplete task with clear acceptance criteria.
3. **Inspection**: Read all relevant files before making changes. Never guess file structure or signatures.
4. **Focused Edit**: Implement the smallest possible atomic change needed to progress the task.
5. **Targeted Tests**: Execute unit and widget tests for the modified module (`flutter test <path_to_test>`).
6. **Broader Verification**: Run `flutter analyze` and broader test suites when relevant modules are touched.
7. **CodeRabbit Gate**: Invoke the CodeRabbit review agent (`code-reviewer` / `code-review` skill) when implementation is complete.
8. **Fix Feedback**: Resolve any critical or high-severity CodeRabbit suggestions.
9. **Log Iteration**: Record iteration count, timestamp, files modified, test results, and status in `.agents/ralph/iterations.log`.
10. **Evaluate Loop Termination**: Determine if acceptance criteria are met, or if a stop condition is triggered.

---

## 4. Configuration & Stop Conditions

Parameter | Default Value | Description
:--- | :--- | :---
`max_iterations` | `5` | Maximum edit-test attempts per task before halting.
`safety_mode` | `strict` | Prevents destructive git commands, force pushes, or unreviewed merges.
`test_command` | `flutter test` | Command for Dart/Flutter test execution.
`analyze_command` | `flutter analyze` | Command for static Dart analysis.

### Explicit Stop Conditions

Ralph **MUST IMMEDIATELY STOP** and notify the user when:

1. **Acceptance Criteria Met**:
   - All targeted tests pass with zero failures.
   - `flutter analyze` reports zero errors and zero fatal warnings.
   - CodeRabbit review reports no open critical/high issues.
   - Working tree changes are verified and documented.

2. **Blocked / Needs Human Decision**:
   - Missing required credentials, API tokens, or 3rd-party services.
   - Ambiguous business requirement not covered by LiftFlow invariants.
   - Physical device or platform-specific manual testing required (e.g. camera barcode scanner).

3. **Repairs Irrecoverable**:
   - The same test failure persists after 3 consecutive repair attempts.
   - A requested change requires modifying third-party packages or locked database schemas without migration authority.

4. **Max Iterations Reached**:
   - Loop reaches `max_iterations` (default: 5) without achieving a clean passing state.

---

## 5. Safety & Security Guardrails

The following actions are strictly prohibited in any Ralph Loop cycle:
- **NO Force Push**: Never run `git push --force` or `git push -f`.
- **NO Destructive Reset**: Never run `git reset --hard` or `git clean -fd` over uncommitted user work.
- **NO Production Deploy**: Never trigger production deployments or run live production migrations during iterative loops.
- **NO Secret Exposure**: Never write API keys, Supabase service keys, or keystore passwords into source files or commit logs.
- **Preserve Unstaged Work**: Never overwrite or delete user changes without explicit instruction.

---

## 6. Code Review Gate (CodeRabbit)

A task is officially complete **only** when reviewed by CodeRabbit.
Before marking a task done:
1. Ensure all local tests and analysis pass.
2. Run the CodeRabbit review using the installed CodeRabbit plugin (`code-reviewer` subagent or `code-review` skill).
3. If CodeRabbit flags security vulnerabilities, performance regressions, or violation of LiftFlow business rules, apply targeted fixes and re-verify.
4. If CodeRabbit passes with no critical findings, mark the task as complete in the GSD state log.
