# LiftFlow / GYM — Agent Architecture & Operational Guidelines

## System Responsibilities
1. **GSD (`.agent/skills/gsd-*`)**: Requirements, phases, planning, specifications, task definitions, and milestone state.
2. **Ralph Loop (`.agents/skills/ralph-loop/SKILL.md`)**: Autonomous single-task implementation, iterative code edits, targeted testing, static analysis, and iteration logging.
3. **CodeRabbit (`code-reviewer` / `code-review`)**: Independent review gate verifying code quality, security, and architectural correctness before task completion.
4. **Antigravity**: Unified execution runtime on Windows.

---

## Immutable LiftFlow Business Invariants (MUST NEVER BE CHANGED)
- **Member Registration has NO OTP**: Flow is strictly `Personal Details` → `Gym Verification (Monthly QR / Gym Code)` → `Username + Password` → `Account Created`.
- **Monthly Activation QR**:
  - One active QR per gym per calendar month.
  - The same QR is reused by multiple new members during that month.
  - It is **NEVER** consumed or invalidated upon a member's registration.
  - It expires at month rollover, and a new QR becomes active for the new month.
- **Tenant Isolation & RLS**: All queries and mutations must preserve tenant isolation and Row Level Security. Never weaken security policies to pass tests.

---

## Ralph Loop Execution Constraints
- **Max Iterations**: 5 (configurable). Stop and request human review if max iterations is reached.
- **Git Safety**:
  - NO force pushing (`git push -f`).
  - NO destructive git operations (`git reset --hard`, `git clean -fd`).
  - NO automatic deployment to production.
  - NO secret, key, or credential leaks.
  - Unstaged user edits must be preserved.
- **Review Gate**: A task is NOT complete until all unit/widget tests pass, `flutter analyze` passes, and CodeRabbit review has no critical/high findings.
