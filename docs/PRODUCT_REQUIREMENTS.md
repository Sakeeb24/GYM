# PRODUCT REQUIREMENTS — LiftFlow (Gym Retention & Management SaaS)

**Working directory:** `E:\Gym`
**Code name:** LiftFlow
**Primary value proposition:** Detect inactive members, help staff follow up,
recover members, improve renewals, and make gym operations measurable.

> This specification is the single source of truth. It preserves the product
> terminology and workflows from the supplied 52-phase brief. Anything not
> specified here is an **assumption** (see `ASSUMPTIONS.md`).

---

## 1. SCOPE & TENANT MODEL

- **ONE application** serves **MANY gyms** (multi-tenant SaaS).
- A `user` (Supabase Auth identity) belongs to one or more `gyms` through
  `gym_memberships`/`gym_staff_roles` with a role.
- Every piece of business data is scoped to a `gym_id`. Cross-tenant reads/writes
  are forbidden by **Row Level Security** in Postgres, never by the Flutter client
  alone (rule 5 / rule 10).
- Roles: **Owner**, **Front Desk**, **Trainer**, **Member**.

## 2. ROLES & CAPABILITIES

| Role | Check-in | Attendance | Red List | Follow-ups | Renewals | Payments | Members | Plans | Staff | Settings | Reports |
|------|----------|-----------|----------|-----------|----------|----------|---------|-------|-------|----------|---------|
| Owner | view | view | manage | assign/complete | view/issue | verify | manage | manage | manage | manage | full |
| Front Desk | support | record (assisted) | view | complete | confirm | confirm | search/view | view | view | view | view |
| Trainer | view own | view | — | — | — | — | view assigned | view | view | — | view own |
| Member | self check-in (QR) | view | view own | — | renew | pay | view | view | view | manage | — |

## 3. CORE BUSINESS LOOP

```
QR Check-in → Attendance → Inactivity Detection → Red List →
Staff Follow-up → Member Returns → Renewal → Payment Verification →
Membership Extension
```

### 3.1 QR Check-in
- Member scans a per-gym QR (static) or a dynamic check-in QR.
- Client sends the **QR payload + session token** to an Edge Function
  `recordAttendance`. The function:
  1. Authenticates the caller (Supabase JWT).
  2. Resolves the gym from the QR.
  3. Validates the membership (active, not paused/frozen/expired/cancelled).
  4. Rejects duplicate check-ins within the same session window
     (configurable grace, default 5 min).
  5. Records `attendance`, updates `streak`, and resolves the related
     `no_show_cases` state.
- The client **never** writes attendance directly.

### 3.2 Attendance
- `attendance` rows: `gym_id, member_id, check_in_at, source(own/assisted),
  staff_id(optional)`.
- Streak = longest run of days with a check-in (configurable streak window).

### 3.3 Inactivity Detection (no-show automation)
- A scheduled function `runNoShowScan` runs daily (idempotent).
- Considers only **active** members (excludes paused/frozen/expired/cancelled).
- For each member, finds the last valid `attendance.check_in_at`.
  - If `(now - last_check_in) >= inactivity_threshold_days` (configurable,
    default 7), create **one open** no-show case if none exists.
- Threshold and window are gym-level `settings` (not hard-coded).
- Creates a `follow_up` action assigned to a configurable staff.

### 3.4 Red List
- The Owner/Front-Desk "Red List" = `no_show_cases` that are `open`, ordered by
  `last_seen_at` (oldest first).
- Each case shows: member, reason, status, assigned staff, created date,
  next action, contact history, outcome, notes, resolution.

### 3.5 Follow-up Workflow
Statuses: `open → contacted / will_return / no_response / wrong_number →
returning → resolved`.
- `createFollowUp`, `recordFollowUp`, `completeFollowUp` are server-authorised.
- Closing a case that was a no-show does **not** auto-renew; it logs the outcome.

### 3.6 Renewal
- Configurable reminder windows (default: 14d, 7d, 3d before expiry, then
  post-expiry).
- `runRenewalScan` (scheduled, idempotent) queues `renewal_orders` +
  `notifications` for soon-to-expire / expired memberships.
- Reminders **stop** on: payment verified, membership renewed, cancellation,
  or communication opt-out.
- Prevent duplicate campaigns per member per cycle (idempotent).

### 3.7 Payment Verification (never trust the client)
- Flutter creates a payment *order* via `createRenewalOrder` Edge Function.
- Provider (Stripe reference) redirects the member; provider calls the
  `processPaymentWebhook` Edge Function.
- Webhook verifies the signature, idempotency-key, provider reference, amount,
  currency; then updates `payments` and **extends the membership** server-side.
- Client only shows the *result*; success is never declared client-side.
- States: `created → pending → succeeded | failed | canceled | refunded |
  reversed`.
- Duplicate webhooks are rejected via `provider_reference` uniqueness +
  idempotency key.

### 3.8 Notifications
- Channels: push (default), email, SMS, WhatsApp (pluggable).
- `notifications` table: `channel, status(queued|sent|delivered|failed|canceled),
  scheduled_at, idempotency_key`.
- Respects `communication_preference` + opt-out. Retry with backoff; bounded.

### 3.9 Daily Owner Summary
Automated daily summary (email + in-app): check-ins, new red-list members,
follow-ups completed/due, renewals paid/pending, add-on orders, alerts.
Delivery configurable per gym.

### 3.10 Member Onboarding & Owner QR Activation
- Member registration is strictly gym-authorized via physical QR scanning.
- Flow:
  1. Prospective member enters Full Name & Phone Number (stored as contact metadata). No SMS OTP is sent or verified.
  2. Member scans owner/front-desk-generated activation QR code (`liftflow://member-activation/<token>`).
  3. Server validates token status (valid, not expired, not revoked, not used) and returns gym details (`Apex Performance Gym`).
  4. Member creates unique Username and Password.
  5. Edge Function `registerMember` atomically consumes the activation token, checks duplicate phone/username constraints (HTTP 409), creates the Supabase Auth user, creates the profile, provisions default membership, and links the member to the issuing gym tenant.
- Owner / Front-desk screen generates a short-lived (60s) single-use QR with live countdown timer and instant regeneration.

## 4. MODULES

### Member
Auth, profile, membership status, QR check-in, attendance history, streak,
renewal, payment, notifications, communication preferences, PT/add-on visibility.

### Owner
Dashboard, members, member detail, attendance, Red List, follow-ups,
renewals, payments, membership plans, add-ons, staff, settings, reports/analytics.

### Front Desk
Member search, assisted check-in, QR support, membership activation,
payment confirmation/status, follow-up recording, basic member management.

### Trainer
Minimum required (see ASSUMPTIONS.md). View assigned members, own attendance,
limited reports only.

## 5. ACCEPTANCE CRITERIA (critical edge cases, rule 52.31)
1. Duplicate QR scan → rejected (grace window).
2. Expired / paused / cancelled membership → check-in denied.
3. Offline check-in → queued locally, reconciled server-side; never auto-accepted.
4. Duplicate no-show case → prevented.
5. Duplicate payment webhook → idempotent (no double extension).
6. Wrong-tenant access → DENY (RLS enforced).
7. Unauthorized role → DENY.
8. Notification failure → retried then marked failed; never silently swallowed.
9. Network/backend timeout → client shows retry UI; server operations are idempotent.
