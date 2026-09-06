# ARCHITECTURE — LiftFlow

## 1. HIGH-LEVEL

```
[ Member / Front Desk / Owner ]  (Flutter, multi-platform)
           │  HTTPS (Supabase client: anon key only)
           ▼
[ Supabase Edge Functions ]       (privileged; Service Role; server-side authz)
    ├─ createMemberActivation    (owner QR generation)
    ├─ validateMemberActivation  (scanned QR verification)
    ├─ registerMember            (member onboarding via QR token)
    ├─ recoverPassword           (password recovery)
    ├─ recordAttendance          (member physical check-in)
    ├─ createMember              (staff member enrollment)
    ├─ createFollowUp / recordFollowUp / completeFollowUp
    ├─ createRenewalOrder
    ├─ processPaymentWebhook
    ├─ runNoShowScan          (scheduled)
    ├─ runRenewalScan         (scheduled)
    ├─ runDataQualityScan     (scheduled)
    ├─ sendNotification
    └─ schedulerTick          (cron entrypoint)
           │  PostgREST / GoTrue / Realtime
           ▼
[ Supabase Postgres ]  (primary DB; RLS-enforced tenant isolation)
           │
           ▼
[ Supabase Auth / Storage ]  (auth users, email/SMS provider, QR asset storage)
```

## 2. TENANT ISOLATION (the core invariant)
- Every business table has `gym_id uuid NOT NULL`.
- RLS policies use `auth.uid()` (the member/staff Supabase user) and
  `auth.gym_id()` (a custom JWT claim added by an auth hook).
- The anon role is denied; `authenticated` is granted DML **only** through RLS.
- Client never filters by `gym_id` for authorization — it may use it only as a
  hint. The function reads the caller's gym from the JWT, ignoring client input.

## 3. TRUST BOUNDARY
- **Trusted:** Postgres (RLS), Edge Functions (Service Role + JWT claims),
  payment-provider webhook (verified signature).
- **Untrusted:** Flutter client, network. The client may *display* anything but
  may *authorise* nothing; all sensitive decisions are server-side (rules 7, 9,
  8, 10).

## 4. BUSINESS-RULES SINGLE SOURCE OF TRUTH
- A canonical Dart package `lib/core/business_rules/` holds every rule as pure
  functions (deterministic, testable).
- The Edge Functions re-implement the *same* pure rules in TypeScript
  (`supabase/functions/_shared/business_rules.ts`) — same inputs/outputs, kept in
  sync by a shared doc (`docs/BUSINESS_RULES.md`). Where the rule can be
  expressed in SQL (e.g. status calculation in a view), SQL is the source and
  the TS/Dart copies are derived. A rule is never implemented three independent
  ways with divergent logic.
- `docs/BUSINESS_RULES.md` lists each rule, its parameters, and where it lives.

## 5. STATE MANAGEMENT (Flutter)
- `flutter_riverpod` (mirrors MindSpace).
- Repositories are interfaces with a Supabase implementation; all reads go
  through RLS-augmented queries (client attaches `gym_id` for *scoping the query*
  but the DB enforces isolation).
- Offline queue (`shared_preferences`) for QR check-ins; synced with
  `connectivity_plus` + `workmanager` on reconnect.

## 6. ROUTING (Flutter)
- `go_router` with guard: unauthenticated → `/login`; authenticated by role →
  owner/front_desk/member shells. (Mirrors MindSpace routing pattern.)

## 7. DESIGN SYSTEM
- `lib/core/theme/` — color/typography/spacing/radius/shadow tokens
  (Stitch + Taste + Awesome Design principles; see `docs/DESIGN_SYSTEM.md`).
- `lib/core/widgets/` — reusable components (button, card, badge, stat card,
  empty/error/loading states).

## 8. ENVIRONMENT MODEL
- DEV / STAGING / PRODUCTION each link a separate Supabase project.
- Flutter config via `--dart-define` (env: `SUPABASE_URL`,
  `SUPABASE_ANON_KEY`, `ENV`). No `.env` asset (audit anti-pattern A17).

## 9. OBSERVABILITY
- Edge functions log structured JSON (`request_id`, `gym_id`, `action`,
  `outcome`) to stdout (Supabase Function logs).
- `audit_logs` table for business events (rule 34).
- `notifications` + `payments` status columns drive retry/monitoring dashboards.

## 10. DUAL QR ARCHITECTURE
- **System A — Monthly Member Activation QR:** Used exclusively for prospective member onboarding and gym verification. Valid for the entire calendar month (`01` to `last day of month` 23:59:59 UTC). Generated server-side by `createMemberActivation`, scanned by new athletes during registration step 2.
- **System B — Daily Attendance QR:** Used by active members for daily gym check-in. Changes every calendar day at midnight. Cryptographically signed with HMAC-SHA256 containing `gym_id`, `valid_date`, `exp`, and `nonce`. Displayed on the **Gym Display Kiosk** (`/display/attendance`) and accessible in Owner QR Management.

## 11. PLATFORM ARCHITECTURAL RESPONSIBILITIES
- **Member App (Android/iOS):** 5-tab core navigation (`Home`, `Workout`, `Check-in`, `Membership`, `Profile`). Features active pass, streak tracking, workout set/rep logging, attendance history calendar, and Razorpay checkout.
- **Owner Mobile App (Android/iOS):** 8-tab operational shell (`Dashboard`, `Members`, `Attendance`, `QR`, `Renewals`, `Red List`, `Payments`, `Settings`) for managing the gym on the go.
- **Owner Web Dashboard (Desktop/Tablet Web):** Collapsible sidebar layout with enterprise data tables, search, filters, pagination, BI charts, and modal drawers for complete administration.
- **Gym Display Kiosk (`/display/attendance`):** Full-screen attendance kiosk for Android tablets, TV browsers, and monitors with large QR code, live clock, and automatic midnight date rollover detection.

## 12. RAZORPAY PAYMENT SYSTEM
- `createRazorpayOrder` edge function creates authenticated orders server-side with metadata (`gym_id`, `member_id`, `plan_id`).
- `processPaymentWebhook` verifies HMAC-SHA256 signatures (`x-razorpay-signature`), enforces idempotency against `payments.provider_reference`, atomically extends membership dates, and records audit logs.

## 13. VERIFICATION GATE (per phase, rule 53)
Each phase ends with: `flutter analyze` clean, relevant `flutter test` green,
and (DB phases) `node test/sql_db_test.js` green.
