# BUSINESS RULES — Single Source of Truth

Every rule below has ONE canonical implementation. Where a rule can live in SQL it
does; the Dart client and TypeScript edge functions hold *derived, identical*
copies (kept in sync by this doc). A rule is **never** implemented with divergent
logic across layers.

Notation: `→` means "produces / resolves to".
Configurable values (rule 6) read from `gym_settings` (DB) or the in-app
`Settings` provider (Flutter cache of the same DB row).

---

## R1. Membership status (canonical: SQL `membership_status(mem)` + Flutter
`MembershipStatus.of(...)`)
A membership row has a stored `status` ENUM, but the **live** effective status is
calculated so it is never stale:

```
IF canceled_at IS NOT NULL        → 'canceled'
ELSE IF paused_until > now()      → 'paused'
ELSE IF expires_at <= now()       → 'expired'
ELSE IF expires_at <= now()+1day  → 'expiring'      (eligible for renewal reminder)
ELSE                              → 'active'
```
- A *paused/frozen* membership (`paused_until > now()`) is **inactive for all
  retention rules** but keeps billing paused.
- `expiring` is a transient state used by the renewal scan (do not persist it).

## R2. Member check-in eligibility (`canCheckIn`)
A member may check in at the gym iff ALL hold:
1. `members.status = 'active'` (roster active), AND
2. an **active** or **paused** membership exists for the member (per R1), AND
3. `now() >= membership.started_at` (has started), AND
4. no **duplicate** check-in within `qr_session_grace_minutes` for the same
   `idempotency_key` (R5).
- Expired / frozen / canceled memberships → DENY.
- Paused → allowed (member can still enter).

## R3. Attendance streak (`computeStreak`)
- Streak = longest run of **consecutive days** (calendar, gym local tz) with ≥1
  check-in within the grace window (`streak_required_consecutive` = 1 by default).
- A missed day *breaks* the current streak; it is NOT reset until the streak is
  broken (i.e., current_streak counts the active run).
- Stored in `streaks` (current_streak, longest_streak, last_check_in_at).
- Updated only by `recordAttendance` (server-side).

## R4. No-show / red-list creation (`shouldOpenNoShowCase`)
Run by `runNoShowScan` daily. For each **active** member:
1. Exclude if `members.status != 'active'` or membership is not
   `active`/`paused` (per R1).
2. Find `last_check_in_at = max(attendance.check_in_at)` where membership was
   eligible at that time.
3. If `last_check_in_at IS NULL` OR `now() - last_check_in_at >=
   inactivity_threshold_days` (settings) → eligible.
4. Create an `open` `no_show_cases` row **only if none exists** for that member
   (partial unique index guarantees it — `unique(gym_id, member_id) WHERE status='open'`).
5. Create one `follow_up` action (status=open) assigned to the gym's default
   follow-up staff.
- Idempotent: re-running does not duplicate cases.

## R5. QR duplicate-scan prevention (`duplicateCheckIn`)
`recordAttendance` rejects a scan when an `attendance` row with the same
`idempotency_key` (or same member within `qr_session_grace_minutes`) exists.

## R6. Renewal eligibility (`renewalEligible`)
A membership is renewal-eligible when:
- status = `active` or `expiring` or `expired` (per R1), AND
- the member has NOT opted out of renewal comms (communication preference), AND
- the membership is **not** canceled.

## R7. Renewal reminder windows
Configured in `gym_settings.reminder_windows_days` (default `[14,7,3]`).
A `renewal_order` is created when `days_until_expiry` hits each window. One
order per `(member, window)` (idempotency_key = `member|window`). Stops when:
payment verified, membership renewed, cancellation, or comm opt-out.

## R8. Payment success → membership extension (canonical: `processPaymentWebhook`)
On a verified success webhook:
1. Idempotency: skip if `provider_reference` already recorded (idempotent).
2. Create/confirm `payments` row (`status = succeeded`).
3. Extend the member's **currently active** membership `expires_at` by the plan
   `duration_days` (or create a new active membership if none active).
4. Mark `renewal_order` `paid`/`completed`.
5. Emit audit + notification.
- Client never sets payment status (rule 8). The Flutter client only *polls*
  `payments.status`.

## R9. Notification eligibility
- Respect `communication_preferences.opted_in` per channel; `opted_in=false`
  ⇒ do not send (rule 19 stop-condition: comm opt-out).
- Respect `gym_settings.notification_channels` whitelist.
- Bounded retries with backoff; mark `failed` after N attempts (rule 15).

## R10. Authorization matrix (enforceable server-side)
| Action | Allowed roles |
|--------|---------------|
| self QR check-in | member |
| assisted check-in | front_desk, owner |
| create member | owner, front_desk |
| edit member | owner, front_desk |
| manage red-list / follow-ups | owner, front_desk |
| manage plans / pricing | owner |
| manage staff | owner |
| manage settings | owner |
| manage payments / refunds | owner |
| view reports | owner |

Edge functions assert the caller's role from the JWT (`auth.jwt()`) before acting.
RLS handles **tenant** isolation; functions handle **role** authorization.

---

## WHERE EACH RULE LIVES

| Rule | SQL | Dart | TypeScript (edge fn) |
|------|-----|------|-----------------------|
| R1 status | `memberships.status` + `membership_status()` | `MembershipRepository` / `MembershipStatus.of` | `business_rules.ts` (`statusOf`) |
| R2 check-in | n/a (function) | `canCheckIn` | `recordAttendance` |
| R3 streak | `streaks` table | `computeStreak` | `recordAttendance` |
| R4 no-show | n/a (scan function) | `shouldOpenNoShowCase` | `runNoShowScan` |
| R5 duplicate | `attendance.idempotency_key` unique | `duplicateCheckIn` | `recordAttendance` |
| R6 renewal | n/a (scan function) | `renewalEligible` | `runRenewalScan` |
| R7 windows | `gym_settings.reminder_windows_days` | read Settings | `runRenewalScan` |
| R8 payment | `payments.provider_reference` unique | — | `processPaymentWebhook` |
| R9 notify | `communication_preferences` | `notifyEligible` | `sendNotification` |
| R10 authz | RLS (tenant) + JWT (role) | `Role` + `auth guard` | each fn (`assertRole`) |
