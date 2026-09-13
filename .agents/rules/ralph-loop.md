---
description: Always-on Ralph Loop execution guardrails, CodeRabbit review gates, and LiftFlow business invariants.
always_on: true
---

# Ralph Loop Rules & LiftFlow Invariants

## Architecture & Responsibilities
- **GSD** (`.agent/skills/gsd-*`): Requirements, milestone planning, specifications, state/context.
- **Ralph Loop** (`.agents/skills/ralph-loop` / `tools/ralph/ralph_loop.ps1`): Iterative implementation and test runner.
- **CodeRabbit** (`code-reviewer` / `code-review`): Independent review gate for quality, architecture, and security.
- **Antigravity**: Host execution environment on Windows.

## Immutable Business Rules (Do Not Change)
1. **Member Registration has NO OTP**: Flow is strictly `Personal Details` -> `Gym Verification (Monthly QR / Gym Code)` -> `Username + Password` -> `Account Active`.
2. **Monthly Activation QR**: One active QR per gym per calendar month. Reusable by all new members during that month. Never consumed or invalidated upon first registration. Expires at month rollover.
3. **Security & RLS**: Maintain strict tenant isolation by gym_id and auth UID. Never bypass RLS or expose service keys.

## Ralph Safety Guardrails
- **Max Iterations**: Default 5 iterations per task before requiring user review.
- **Git Safety**: No force push (`git push -f`), no hard reset (`git reset --hard`), no destructive clean (`git clean -fd`).
- **No Production Deploy**: Do not trigger production deployments or live database mutations during development loops.
- **Preserve User Changes**: Do not discard unstaged user modifications.
- **Independent Gate**: A task is complete ONLY after tests pass AND CodeRabbit review completes with no critical/high issues.
