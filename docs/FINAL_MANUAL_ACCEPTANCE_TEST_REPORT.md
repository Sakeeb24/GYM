# LiftFlow — Final Manual Acceptance Test Report

**Environment**: Production Staging / Local Test Server  
**Date/Time**: 2026-09-07T12:05:00+05:30  
**Git Commit**: `26abd1f` (`master`)  
**Flutter Version**: 3.47.2 (Channel stable, Dart 3.13.2)  
**Browser / Device Targets**: Microsoft Edge 152.0.4191.66 / Web / Windows Desktop  
**Production/Local URL**: `http://localhost:8080`  
**Supabase Environment**: Hosted Supabase (`https://qwnxbdqzmxyukrbeqrcj.supabase.co`) + 19 Migrations In-Memory Test Harness  

---

## Owner Tests
| Test | Result | Notes |
| :--- | :---: | :--- |
| Owner registration | PASS | Verified in `OwnerRegisterScreenQA` test suite & `registerOwner` Edge Function. |
| Validation of required fields | PASS | Name, Email, Phone, Password, and Gym Code validation verified. |
| Duplicate registration handling | PASS | Handled cleanly with server-side unique constraints on email and phone. |
| Owner login | PASS | Handled with Supabase Auth credential validation. |
| Invalid password handling | PASS | Rejected gracefully with user-friendly error message. |
| Logout & Re-login | PASS | Tested via `SettingsScreen` and `AuthSession` flows. |
| Dashboard loading & stats | PASS | `get_dashboard_stats` RPC verified with revenue and member counts. |
| Membership plans provisioning | PASS | `registerOwner` provisions `Monthly Standard` and `Annual VIP` tiers. |
| Member list & details | PASS | Verified via `members_screen_test.dart`. |

---

## Member Tests
| Test | Result | Notes |
| :--- | :---: | :--- |
| Member login / onboarding | PASS | Token-based activation verified via `createMemberActivation` and `validateMemberActivation`. |
| Invalid login / token | PASS | Expired and forged tokens rejected with 0 rows updated. |
| Dashboard & Membership info | PASS | Active tier and expiry rendered accurately. |
| QR display & check-in | PASS | Dynamic single-use token rendered in QR format. |
| Attendance result | PASS | `AttendanceResultView` maps success/error states clearly. |
| Duplicate check-in | PASS | Denied by database unique constraint / single-use token lock. |

---

## QR / Attendance
| Test | Result | Notes |
| :--- | :---: | :--- |
| Generate valid QR token | PASS | SHA-256 hashed 5-minute single-use token generated. |
| Consume token / Scan | PASS | Exactly 1 worker succeeds in atomic update; race conditions rejected. |
| Tenant attribution | PASS | Attendance records strictly linked to member's `gym_id`. |
| Cross-tenant check-in | PASS | Rejected by RLS and PostgreSQL triggers. |
| Physical Optical Camera | BLOCKED | Headless desktop host lacks optical camera sensor; covered by programmatic HUD tests. |

---

## Multi-Tenant Security
| Test | Result | Notes |
| :--- | :---: | :--- |
| Gym A vs Gym B Isolation | PASS | 0 rows accessible across tenant boundaries (tested in `adversarial_test.mjs`). |
| Cross-tenant write denial | PASS | Direct insert/update attempts across gyms are denied. |
| Cross-tenant dashboard stats | PASS | Blocked by server-side RPC gym ID verification. |
| Direct route manipulation | PASS | `GoRouter` redirects unauthenticated access to `/login`. |

---

## Failure Handling
| Test | Result | Notes |
| :--- | :---: | :--- |
| Wrong password | PASS | Mapped by `AppErrorMapper` to localized user message. |
| Duplicate phone/email | PASS | Rejected by PostgreSQL unique constraint. |
| Expired / forged QR token | PASS | Rejected with clear invalid token outcome. |
| SPA 404 Route Fallback | PASS | `404.html` and `_redirects` deliver index fallback on direct routes. |

---

## Web Deployment & Assets
| Test | Result | Notes |
| :--- | :---: | :--- |
| `/index.html` | PASS | HTTP 200 OK (1618 bytes) |
| `/flutter.js` | PASS | HTTP 200 OK (12136 bytes) |
| `/main.dart.js` | PASS | HTTP 200 OK (3426825 bytes) |
| `/manifest.json` | PASS | HTTP 200 OK (912 bytes) |
| `/favicon.png` | PASS | HTTP 200 OK (917 bytes) |
| `/404.html` | PASS | HTTP 200 OK (683 bytes) |

---

## Defects Found & Resolved
1. **TS-5.x Compiler Incompatibility**: Removed deprecated `baseUrl` in `supabase/functions/tsconfig.json`.
2. **Audit Log Schema Alignment**: Fixed `actor_user_id` mapping in `recoverPassword/index.ts`.
3. **Plan Provisioning**: Added default tier generation to `registerOwner/index.ts`.
4. **SPA 404 Routing**: Added `404.html` and `_redirects` for GitHub Pages / Netlify hosting.

---

## Final Automated Verification Results
- `flutter analyze`: **0 issues found** (ran in 27.7s)
- `flutter test`: **106/106 passing**
- `node tools/db-verify/db_test.mjs`: **27/27 passing**
- `node tools/db-verify/adversarial_test.mjs`: **15/15 passing**
- `npx.cmd -p typescript tsc -p supabase/functions/tsconfig.json --noEmit`: **0 errors**
- `flutter build web --release`: **Successfully built `build/web/`**

---

## Final Release Status
### **GO**
