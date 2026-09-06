# LiftFlow Privacy Policy

**Effective Date**: August 29, 2026  
**Last Updated**: August 29, 2026  

LiftFlow ("we", "our", or "us") provides a multi-tenant gym management and member retention platform. This Privacy Policy explains how personal information is collected, used, disclosed, and protected when fitness facilities ("Gyms", "Tenants") and their members ("Users", "Members", "Staff") access our application and services.

---

## 1. Information We Collect

### A. Account & Profile Information
- **Staff & Owners**: Name, business email, phone number, gym affiliation, administrative role (`owner`, `front_desk`, `trainer`).
- **Members**: Name, member ID number, email, phone number, emergency contact, membership tier, active subscription dates.

### B. Facility Attendance & Usage Data
- Check-in timestamps, attendance sources (`qr_self`, `qr_assisted`), check-in frequency, and retention streaks.

### C. Financial & Transaction Reference Data
- Transaction IDs, payment amounts, currency, subscription status, and billing intervals processed via third-party processors (e.g. Stripe).
- **Note**: Full credit card numbers, CVVs, and banking details are processed directly by Stripe and are NEVER stored or processed on LiftFlow servers.

### D. Device & Camera Permissions
- **Camera Access**: Used exclusively on the local device for real-time QR code scanning during facility check-in. No photos or video recordings are saved or uploaded to our servers.

---

## 2. How We Use Your Information

- Facilitate member check-in verification and physical facility access.
- Calculate member retention streaks and detect inactivity (No-Show prevention).
- Process subscription renewals and send automated status notifications (SMS/Email).
- Enforce strict tenant isolation across multi-tenant facilities.
- Maintain tamper-proof security audit logs.

---

## 3. Data Sharing & Disclosure

We do NOT sell, rent, or monetize your personal data. Data is shared strictly with:
- **Your Affiliated Gym**: Accessible only to authorized facility staff under strict Row Level Security (RLS).
- **Service Providers**: Infrastructure and delivery partners (Supabase cloud hosting, Stripe payment gateway, Twilio SMS/email relays) under confidentiality agreements.
- **Legal Compliance**: When required by law or to protect user safety.

---

## 4. Multi-Tenant Data Isolation & Security

- Every data record is cryptographically tied to a facility identifier (`gym_id`) and guarded by Postgres Row Level Security (RLS).
- Data is encrypted in transit (TLS 1.3) and at rest (AES-256).

---

## 5. User Rights & Data Deletion

Members and staff have the right to:
- Access, review, and export their personal attendance history.
- Request account and profile deletion by contacting their gym administrator or emailing `privacy@liftflow.app`.
- Upon deletion request, member records are scrubbed and anonymized in compliance with applicable data protection regulations.

---

## 6. Contact Us

If you have questions regarding this Privacy Policy, please contact us at:  
**Email**: privacy@liftflow.app  
**Website**: https://github.com/Sakeeb24/GYM
