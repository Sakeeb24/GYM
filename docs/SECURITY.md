# LiftFlow Security Architecture & Threat Model

This document outlines the multi-layered security model implemented in LiftFlow, ensuring complete multi-tenant isolation, cryptographic verification, and strict least-privilege access control.

---

## 1. Multi-Tenant Isolation Model

### Row Level Security (RLS) Enforcement
- Every table containing tenant data contains a mandatory `gym_id UUID NOT NULL REFERENCES gyms(id)` column.
- All RLS policies derive tenant context exclusively from the authenticated user's JWT claims (`auth.jwt() ->> 'gym_id'`).
- The client NEVER passes `gym_id` as a trusted filter for authorization; the database automatically rejects queries where JWT claims do not match the row `gym_id`.

```sql
-- Standard RLS pattern applied across all tables
CREATE POLICY tenant_isolation_policy ON members
  FOR ALL
  USING (gym_id = (auth.jwt() ->> 'gym_id')::uuid)
  WITH CHECK (gym_id = (auth.jwt() ->> 'gym_id')::uuid);
```

### Defense-in-Depth Write Guarantees
- Uniqueness constraints (e.g., `UNIQUE (gym_id, member_number)`, `UNIQUE (gym_id, provider_reference)`) prevent cross-tenant collision attacks.
- Service-role privileges are restricted exclusively to backend Edge Functions; the Flutter client only receives the public `anon` publishable key.

---

## 2. Authentication & Authorization Matrix

| Role | Self Check-in | View Members | Modify Members | Manage Staff | View Financials / Payments | Edit Gym Settings |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **Owner** | Yes | Yes | Yes | Yes | Yes | Yes |
| **Front Desk** | Yes | Yes | Yes | No | Read-Only / Succeeded | No |
| **Trainer** | Yes | Yes (Assigned) | No | No | No | No |
| **Member** | Yes (Self) | Self Only | Self (Profile) | No | Self History | No |

---

## 3. Cryptographic Verification & QR Anti-Spoofing

### Attendance QR Tokens
- QR codes generated for physical check-in contain HMAC-SHA256 signatures with:
  - `gym_id`: Target facility UUID.
  - `member_id`: Authorized member UUID.
  - `timestamp`: Generation epoch.
  - `nonce`: Ephemeral random bytes preventing replay.
  - `exp`: Short-lived expiration window (30–60 seconds).
- Edge Functions (`recordAttendance`) verify the signature against the gym secret key before recording check-in records.
- Database trigger prevents double check-ins within a configurable grace window (e.g. 5 minutes).

### Member Registration QR Activation Tokens
- Prospective members join a gym by physically scanning an owner/staff-generated activation QR code.
- **No SMS OTP Dependency**: Phone numbers are stored solely as contact information and are never used as an authentication proof.
- **Short-Lived & Ephemeral**: Default token lifespan is 60 seconds.
- **Single-Use & Atomically Consumed**: Tokens are consumed atomically (`UPDATE member_activation_tokens SET used_at = now(), used_by_profile_id = ... WHERE id = ... AND used_at IS NULL AND expires_at > now()`), preventing race conditions and screenshot reuse.
- **Cryptographic Hashing**: Tokens are 256-bit random cryptographic nonces; the database stores only SHA-256 hashes (`token_hash`).
- **Strict Role & Tenant Boundary**: Only authenticated owners and authorized front-desk staff can generate activation tokens for their own gym tenant (`gym_id` derived exclusively from server-side JWT). Anonymous users, trainers, and members cannot generate activation tokens.

---

## 4. Secret Hygiene & Key Management

1. **Flutter Client Assets**:
   - Zero hardcoded secrets, private certificates, or service-role keys exist in the Flutter codebase.
   - All runtime variables are injected via compile-time `--dart-define` flags.
2. **Edge Functions**:
   - Private API keys (Stripe Webhook secrets, Twilio/Resend notification tokens) are stored in encrypted Supabase Vault / environment secrets.
3. **Webhook Verification**:
   - All incoming Stripe/payment provider webhooks verify the cryptographic signature header (`Stripe-Signature`) before processing state mutations.

---

## 5. Security Incident Response Protocol

1. **Compromised Credentials**:
   - Revoke JWT tokens immediately via Supabase Auth Admin API.
   - Rotate Supabase service keys and payment provider webhook signing secrets.
2. **Audit Logging**:
   - All administrative actions, role assignments, and payment overrides are immutably logged to `audit_logs` table with client IP, user ID, timestamp, and before/after payloads.
