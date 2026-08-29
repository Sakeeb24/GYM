# LiftFlow Pilot Gym Onboarding & Verification Runbook

This runbook outlines the operational protocol for onboarding the single initial pilot gym facility, executing verification drills, and establishing production feedback loops.

---

## 1. Pilot Gym Profile & Scope

- **Facility Selection**: Single facility with 100–300 active members and 2–5 staff members.
- **Trial Period**: 14 calendar days.
- **Target Role Distribution**:
  - 1 Owner account (`owner`)
  - 2 Front Desk staff (`front_desk`)
  - 2 Personal Trainers (`trainer`)
  - 50–100 Opt-in Members (`member`)

---

## 2. Onboarding Workflow

### Phase A: Tenant Provisioning
1. Insert tenant row into `gyms` with custom slug (e.g. `pilot-gym-01`) and timezone.
2. Initialize `gym_settings` with default parameters:
   - `inactivity_threshold_days = 7`
   - `qr_session_grace_minutes = 5`
   - `reminder_windows_days = [14, 7, 3]`
3. Provision owner account via Supabase Auth with custom claims (`gym_id`, `role: owner`).

### Phase B: Kiosk & Front Desk Station Setup
1. Configure front desk tablet / workstation running LiftFlow Web or Android App.
2. Verify front desk staff can view real-time check-in stream.
3. Test assisted check-in search by member name and phone.

### Phase C: Member QR Check-In Verification
1. Pilot members install LiftFlow Android or Web App.
2. Log in using OTP magic link.
3. Scan facility QR code kiosk:
   - Verify HMAC token validation succeeds.
   - Verify streak count increments on dashboard.
   - Verify duplicate scan within 5 minutes triggers duplicate acknowledgment rather than error.

### Phase D: Stripe Payment Test Mode
1. Configure Stripe webhook URL targeting `https://<supabase-project-ref>.supabase.co/functions/v1/processPaymentWebhook`.
2. Set `STRIPE_WEBHOOK_SECRET` in Edge function secrets.
3. Trigger test subscription renewal using Stripe CLI test tokens (`pm_card_visa`).
4. Verify membership expiration date auto-extends in `memberships` table and audit log entry created.

### Phase E: Scheduled Job / Automation Drill
1. Trigger `schedulerTick` endpoint with valid `?token=<CRON_TOKEN>`.
2. Verify `runNoShowScan` detects inactive members (>7 days) and generates open `no_show_cases`.
3. Check member return check-in auto-resolves open case to `resolved (returned)`.

---

## 3. Incident Escalation & Feedback Protocol

- **Telemetry Dashboard**: Monitor Supabase Log Explorer for 4xx/5xx Edge Function spikes and RLS violations.
- **Feedback Collection**: Daily 5-minute staff sync to log UX friction, scanner responsiveness, and missing workflows.
- **Data Export & Cleanup**: At end of pilot, export full attendance records for facility owner.
