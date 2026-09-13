# Ralph Loop Architecture & Workflow Guide

## Overview
Ralph Loop is the iterative execution engine for the LiftFlow / GYM Flutter + Supabase codebase. It operates within a strict separation of concerns alongside **GSD**, **CodeRabbit**, and the **Antigravity** execution runtime.

---

## 1. System Responsibilities

Layer | Tool | Scope & Responsibilities
:--- | :--- | :---
**Planning** | **GSD** (`.agent/skills/gsd-*`) | Requirements gathering, roadmap phases, architectural specifications, work breakdown, and overall milestone state.
**Execution** | **Ralph Loop** (`.agents/skills/ralph-loop` / `tools/ralph/ralph_loop.ps1`) | Single-task pick, focused atomic implementation, targeted test runner, Dart analysis, iteration counting, and state logging.
**Review Gate** | **CodeRabbit** (`code-reviewer` / `code-review`) | Independent code quality, anti-pattern detection, security verification, and PR readiness gate.
**Host Runtime** | **Antigravity IDE & CLI** | Execution environment on Windows, file system access, terminal operations, and subagent orchestration.

---

## 2. LiftFlow Business Invariants (Strict Core Rules)

Ralph must **NEVER** modify or bypass these core business rules:

1. **Member Registration Has NO OTP**:
   - The member onboarding flow is strictly:
     `Personal Details` $\rightarrow$ `Gym Verification (Monthly QR Scan / Gym Code)` $\rightarrow$ `Username + Password Selection` $\rightarrow$ `Account Created & Active`.
   - Never introduce SMS OTP, email OTP, or verification code steps.

2. **Monthly Activation QR Model**:
   - The QR code displayed by gym owners is a **Monthly Activation QR**.
   - Exactly **one active monthly QR per gym per calendar month**.
   - The same QR code is **reused by all new members** registering at that gym during that calendar month.
   - The QR is **NEVER consumed or invalidated** upon a member's registration.
   - It automatically expires upon calendar month rollover, and a new monthly QR becomes active for the new month.

3. **Tenant Isolation & RLS**:
   - Strict gym-level tenant isolation via Row Level Security (RLS).
   - Never bypass RLS policies or expose Supabase service role keys.

---

## 3. Ralph Iteration Workflow

Every Ralph loop iteration follows a deterministic cycle:

```text
[GSD State Ingestion]
        ↓
[Select 1 Incomplete Task]
        ↓
[Inspect Relevant Codebase]
        ↓
[Smallest Atomic Edit]
        ↓
[Run Targeted Tests: flutter test]
        ↓
[Run Static Analysis: flutter analyze]
        ↓
[Check Loop Thresholds / Safety]
        ↓
[CodeRabbit Review Gate]
        ↓
[Task Completed / Next Iteration / Stop on Block]
```

---

## 4. Safety Guardrails & Stop Conditions

### Prohibited Operations
- ❌ No Force Push (`git push --force`)
- ❌ No Destructive Git Reset (`git reset --hard`, `git clean -fd`)
- ❌ No Automated Production Deployments
- ❌ No Secret / Private Key Leaks
- ❌ No Overwriting / Discarding User Unstaged Changes

### Explicit Stop Conditions
The loop **immediately halts** when:
1. **Task Complete**: Acceptance criteria pass, tests succeed, flutter analyze passes cleanly, and CodeRabbit reports zero unresolved critical/high issues.
2. **Blocked**: Missing credentials, external service outage, or ambiguous requirement.
3. **Repairs Irrecoverable**: Test failure repeats after 3 repair attempts.
4. **Max Iterations Reached**: Iteration counter reaches configured limit (default: 5).

---

## 5. Command Reference

### Starting & Managing Ralph

```powershell
# 1. Initialize Ralph State
.\tools\ralph\ralph_loop.ps1 init

# 2. Check Ralph Loop Status
.\tools\ralph\ralph_loop.ps1 status

# 3. Start a new task from GSD
.\tools\ralph\ralph_loop.ps1 start-task -TaskName "Task-Name" -MaxIterations 5

# 4. Verify step (runs targeted tests, flutter analyze, and git safety)
.\tools\ralph\ralph_loop.ps1 verify-step -TargetTest "test/business_rules/business_rules_test.dart"

# 5. Log iteration progress
.\tools\ralph\ralph_loop.ps1 log-iteration -Summary "Refactored QR validation logic" -Status "IN_PROGRESS"

# 6. Check CodeRabbit gate readiness
.\tools\ralph\ralph_loop.ps1 coderabbit-check

# 7. Stop Ralph Loop manually
.\tools\ralph\ralph_loop.ps1 stop -Reason "Awaiting manual device QR camera test"

# 8. Reset state to IDLE
.\tools\ralph\ralph_loop.ps1 reset-state
```
