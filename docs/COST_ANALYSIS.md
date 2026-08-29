# LiftFlow Infrastructure Cost Analysis & SaaS Unit Economics

This document provides a breakdown of cloud infrastructure costs, scaling tiers, and unit economics for the LiftFlow SaaS platform.

---

## 1. Cloud Infrastructure Breakdown (Base Tier: 100 Gyms / 50,000 Active Members)

| Component | Provider | Tier / Specs | Estimated Cost (Monthly) |
| :--- | :--- | :--- | :--- |
| **Database & Auth** | Supabase Pro | Multi-AZ Postgres (4 vCPU, 16GB RAM) + PITR | \$100.00 |
| **Serverless Compute** | Supabase Edge | 10M invocations/mo (Check-in, webhooks, crons) | \$20.00 |
| **Storage & Egress** | Cloudflare R2 / AWS S3 | Static assets, QR images, backup WALs (100GB) | \$5.00 |
| **Edge Routing & CDN** | Cloudflare Pro | Web hosting, DDoS protection, WAF rules | \$20.00 |
| **SMS / WhatsApp Alerts** | Twilio / Meta API | 15,000 retention alerts/mo @ \$0.0075 | \$112.50 |
| **Email Service** | Resend / SendGrid | 50,000 transactional emails/mo | \$20.00 |
| **Error Monitoring** | Sentry / Datadog | Developer Team tier | \$26.00 |
| **Total Base Operating Cost** | | | **\$303.50 / month** |

---

## 2. SaaS Pricing Model & Unit Margins

- **Average Revenue Per Gym (ARPU)**: \$99.00 / month
- **Total Revenue (100 Gyms)**: \$9,900.00 / month
- **Infrastructure Cost per Gym**: \$303.50 / 100 = **\$3.04 / month**
- **Gross Margin**: **> 96.9%**

---

## 3. Scaling Milestones & Economics

| Milestone | Active Gyms | Total Members | Monthly Infra Cost | Monthly Revenue | Gross Margin |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Launch** | 10 | 5,000 | \$60 | \$990 | 93.9% |
| **Growth** | 100 | 50,000 | \$304 | \$9,900 | 96.9% |
| **Scale** | 1,000 | 500,000 | \$2,100 | \$99,000 | 97.8% |
| **Enterprise** | 5,000 | 2,500,000 | \$8,500 | \$495,000 | 98.2% |

---

## 4. Cost Optimization Directives

1. **Edge Function Execution Time**:
   - Keep check-in functions sub-50ms to minimize compute billing.
2. **Database Query Optimization**:
   - All tenant filter queries use indexed lookups on `(gym_id, ...)`.
   - Prevent sequential scans on large attendance history tables using composite btree indexes.
3. **Smart Notification Batching**:
   - Group non-urgent retention notifications into scheduled hourly digests rather than real-time per-member SMS calls.
