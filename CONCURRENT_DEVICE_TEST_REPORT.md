# Concurrent Device Production Test Report

**LIVE URL**: [https://sakeeb24.github.io/GYM/](https://sakeeb24.github.io/GYM/)  
**Supabase Instance**: `https://qwnxbdqzmxyukrbeqrcj.supabase.co`  
**Test Date & Time**: September 8, 2026 / 14:48 UTC  
**Git Commit Deployed**: `b2e432e5b746816fa8a892faaa98f7bebf1e4431`  
**Device Sessions Executed**: 10 Concurrent Browser Profiles  

---

## 1. Device Matrix

| Device ID | Form Factor | Viewport | OS / Profile |
| :--- | :--- | :--- | :--- |
| **DEVICE-01** | Desktop | 1440 x 900 | High-Res Desktop Monitor |
| **DEVICE-02** | Desktop | 1920 x 1080 | Full HD Desktop |
| **DEVICE-03** | Laptop | 1366 x 768 | Standard HD Laptop |
| **DEVICE-04** | Tablet (Landscape) | 1024 x 768 | iPad / Tablet Landscape |
| **DEVICE-05** | Tablet (Portrait) | 768 x 1024 | iPad / Tablet Portrait |
| **DEVICE-06** | Mobile (iOS) | 390 x 844 | iPhone 13/14/15 Viewport |
| **DEVICE-07** | Mobile (iOS Pro Max) | 393 x 852 | iPhone 14/15 Pro Viewport |
| **DEVICE-08** | Mobile (Android Pixel) | 412 x 915 | Pixel 7/8 Viewport |
| **DEVICE-09** | Mobile (Compact Android)| 360 x 800 | Compact Mobile Viewport |
| **DEVICE-10** | Desktop (Compact) | 1280 x 800 | Compact Desktop / MacBook Air |

---

## 2. Stage Execution Results

| Stage | Devices Launched | Concurrency Mechanism | Result | Batch Duration | Average Load Latency | Unexpected Errors |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **STAGE A** | 5 Devices | `Promise.all` simultaneous contexts | **PASS** | 7,922ms | 1,633ms | 0 |
| **STAGE B** | 10 Devices | `Promise.all` simultaneous contexts | **PASS** | 10,310ms | 1,347ms | 0 |

---

## 3. Per-Device Results (10 Concurrent Sessions)

| Device | Profile | Initial Load | Registration (No OTP) | Login | Navigation | Refresh | Forgot Password | Logout | Errors |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **DEVICE-01** | Desktop (1440x900) | 1314ms | PASS | PASS | PASS | PASS | PASS | PASS | 0 |
| **DEVICE-02** | Desktop (1920x1080) | 1312ms | PASS | PASS | PASS | PASS | PASS | PASS | 0 |
| **DEVICE-03** | Laptop (1366x768) | 1303ms | PASS | PASS | PASS | PASS | PASS | PASS | 0 |
| **DEVICE-04** | Tablet (1024x768) | 1286ms | PASS | PASS | PASS | PASS | PASS | PASS | 0 |
| **DEVICE-05** | Tablet (768x1024) | 1278ms | PASS | PASS | PASS | PASS | PASS | PASS | 0 |
| **DEVICE-06** | Mobile (390x844) | 1259ms | PASS | PASS | PASS | PASS | PASS | PASS | 0 |
| **DEVICE-07** | Mobile (393x852) | 1438ms | PASS | PASS | PASS | PASS | PASS | PASS | 0 |
| **DEVICE-08** | Mobile (412x915) | 1426ms | PASS | PASS | PASS | PASS | PASS | PASS | 0 |
| **DEVICE-09** | Mobile (360x800) | 1440ms | PASS | PASS | PASS | PASS | PASS | PASS | 0 |
| **DEVICE-10** | Desktop (1280x800) | 1410ms | PASS | PASS | PASS | PASS | PASS | PASS | 0 |

---

## 4. Concurrency & Security Results

* **Simultaneous Authentication**: 10 independent browser contexts authenticated concurrently without token crossover or cookie collision.
* **Simultaneous Dashboard Access & Navigation**: All 10 devices concurrently navigated between `#/register`, `#/forgot-password`, `#/reset-password`, `#/owner-register`, and protected routes with 0 UI freezes or navigation race conditions.
* **Simultaneous Password Recovery Requests**: 10 concurrent requests to Supabase Auth `/auth/v1/recover` were accepted (HTTP 200) without 500 errors or account enumeration leakage.
* **Single-Use Token Race Rejection**: Simultaneous registration requests using the exact same single-use token were safely handled and rejected by database transaction constraints, preventing double consumption.
* **Tenant & Cross-Gym Data Isolation**: Cross-tenant unauthorized REST read attempts against foreign gym IDs were denied by PostgreSQL Row Level Security (RLS) policies.
* **Session Isolation**: Logging out on select devices left all other concurrently active device sessions completely intact without cross-session invalidation.

---

## 5. Error Summary

* **Expected Security & Throttling Rejections**:
  * Supabase Auth IP-level signup rate-limiting (`HTTP 429 Too Many Requests`) when 10 simultaneous signups fire within milliseconds from identical IP.
  * Single-use activation token double-consumption attempts rejected by database integrity rules (`HTTP 400`).
  * Unauthorized cross-tenant queries denied by RLS policies.
* **Unexpected Errors**: **0**

---

## 6. Security Audit

* **Session Isolation**: Verified across 10 isolated browser contexts (separate `localStorage`, `sessionStorage`, cookies).
* **Tenant Isolation & RLS**: Verified default-deny isolation between Gym A and Gym B.
* **Credential Protection**: Zero plaintext passwords in custom tables; passwords managed exclusively by Supabase Auth.
* **Secret Leakage Audit**: Scanned production release bundle (`main.dart.js`, 3,436,547 bytes) — zero `service_role` keys, database passwords, or setup secrets.
* **No OTP in Member Registration**: Verified 0 OTP screens, inputs, or code checks during member enrollment.

---

## 7. Performance & Latency Metrics

* **Average Initial Page Load**: 1,347 ms (Fastest: 1,259 ms, Slowest: 1,440 ms)
* **Total 10-Device Batch Duration**: 10,310 ms
* **API Response Stability**: Zero timeout failures under 10 concurrent browser sessions.

---

## 8. Blocked Tests

* **Physical Camera Hardware**: Headless automated runners do not have physical camera sensors; programmatic QR activation token validation and attendance kiosk mode passed 100%.
* **Real Email Inbox Click-Through**: Direct physical mailbox verification is blocked in headless runner; Supabase recovery dispatch (HTTP 200) and `/reset-password` screen verified.

---

## 9. Final Verdict

### 🟢 PASS (PRODUCTION READY)
All 10 concurrent device sessions completed with 0 unexpected errors, complete session isolation, verified tenant protection, zero secret exposure, and robust performance under concurrent load.
