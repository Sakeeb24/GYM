# ASSUMPTIONS

Recorded decisions for anything not explicitly specified in the product brief.
Each is implemented in a **configurable** way where practical (rule 6).

| # | Assumption | Rationale / Configurability |
|---|------------|-----------------------------|
| A1 | **App name = "LiftFlow"**, package `com.liftflow.app`. | Brand placeholder; overridable via dart-define `APP_NAME` + flavor. |
| A2 | **One primary gym per staff/user** for MVP (a user belongs to a single gym as member/staff). Multi-gym staff deferred; schema supports `gym_staff_roles` membership (many-to-many) so expansion is a config, not a rewrite. | Avoids scope creep; schema already N:N. |
| A3 | **Payment provider = Stripe** (reference implementation). Architecture is provider-agnostic via `payments.provider` column + provider-agnostic webhook verifier. Switching provider is config + a new verifier. | Only one provider can be deeply integrated under budget. |
| A4 | **QR = static per-gym QR** containing `{gym_id, nonce, version}` signed. Members scan with their device camera; front-desk has an assisted scanner. Dynamic (time-limited) QR is a config flag (`qr.mode = static|dynamic`), default `static` for MVP. | Static QR is simplest and sufficient for the retention loop. |
| A5 | **Notification provider** = Firebase Cloud Messaging (push) + SMTP provider-agnostic. Channels are abstracted; email/SMS/WhatsApp adapters added later. | Scope. |
| A6 | **Trainer module** = minimal: view assigned members, view own metrics. A full trainer app is explicitly out of scope (brief §4 TRAINER). | Brief says implement minimum only. |
| A7 | **Membership model**: each member has at most one *active* membership at a time (one active row per member). `status ∈ {active, paused, frozen, expired, canceled, expired}` with a single source of truth for status (business rules). | Simplifies renewal; prevents overlapping billing states. |
| A8 | **Inactivity threshold** configurable per gym via `settings.inactivity_threshold_days` (default 7). **Renewal reminder windows** configurable per gym (`reminder_windows` JSON: `[14,7,3]`). | Rule 6 (no hard-coded thresholds). |
| A9 | **Scheduled jobs** run via a single edge function `schedulerTick` invoked by an external cron (Supabase Edge Functions do not run on a timer natively without Scheduled Functions beta). This engagement provides the functions + a documented cron; the external scheduler host is an ops assumption. | Supabase scheduled functions are in beta; idempotent functions are the durable artifact. |
| A10 | **Supabase Auth** email+password + magic-link for members (no phone/SMS auth in MVP). | Spec rule 11 ("Use Supabase Auth if already selected"). |
| A11 | **JWT gym claim** populated via a Supabase Auth custom-access-token hook (`auth.hook.custom_access_token`) that adds `gym_id` + `roles` claims. Edge Functions + RLS read these claims. A no-op client fallback exists for local dev (rules test harness shims `auth.gym_id()`). | Cleanest RLS pattern; avoids per-table lookups for the gym. |
| A12 | **Local storage** uses `shared_preferences` (key-value) only — NOT Hive. (MindSpace used Hive; gym app keeps local state minimal: pending offline queue + session cache.) Reduces sync complexity. | Simpler offline strategy; offline queue is the only persisted local data. |
| A13 | **Offline**: only *QR check-in* is queued offline. All other actions require connectivity. Offline queue is reconciled on reconnect with conflict resolution (server wins; client flags conflicts for review). | Realistic offline scope. |
| A14 | **CI/CD** uses GitHub Actions (mirrors MindSpace CI). Staging deploys automatically on merge; production is manual approval. | Mirrors existing project pattern. |
| A15 | **App store demo account** = Owner `demo@liftflow.dev` / password in reviewer instructions doc (rotated credentials stored in GitHub repo-secrets, never in source). | Spec §42. |
| A16 | **No production data is seeded** into dev. Dev/staging use `.env` with separate credentials (rule 17). | |
| A17 | **Dart-define only for env** (never ship `.env` as an Flutter asset — COOK/app anti-pattern noted in audit). Config: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `ENV`, `APP_NAME`. | Rule 7 (never expose service-role in Flutter). |
| A18 | **Web** target is supported (for owner/staff browser use + Playwright). Mobile (Android/iOS) targets are primary for member QR. | Spec §29. |
