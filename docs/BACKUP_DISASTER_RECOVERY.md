# LiftFlow Backup & Disaster Recovery (DR) Plan

This document outlines the backup strategies, Point-In-Time Recovery (PITR) workflows, failover mechanisms, and recovery time/point objectives (RTO/RPO) for LiftFlow.

---

## 1. Recovery Objectives

- **Recovery Point Objective (RPO)**: < 5 minutes (Maximum acceptable data loss in catastrophic scenario).
- **Recovery Time Objective (RTO)**: < 30 minutes (Maximum acceptable time to restore full service).

---

## 2. Automated Backup Schedule

### Postgres Continuous Archiving & PITR
- **Continuous Write-Ahead Logging (WAL)**: Streamed continuously to multi-region cloud object storage.
- **Full Base Backups**: Executed daily at 02:00 UTC.
- **Retention Period**:
  - Production: 30 days of continuous PITR.
  - Staging: 7 days.

### Edge Function Code & Configuration
- All migration scripts (`supabase/migrations/*.sql`) and Edge Functions are version-controlled in GitHub.
- Database state is reproducible from migration files 001 to 010.

---

## 3. Disaster Recovery Procedures

### Scenario A: Accidental Data Corruption / Bad Deployment
1. Identify the exact corruption timestamp ($T_{\text{corrupt}}$).
2. Initiate PITR to $T_{\text{target}} = T_{\text{corrupt}} - 1\text{ minute}$.
3. Spin up staging instance from recovery snapshot to verify integrity.
4. Promote recovered database and update connection strings in Supabase control plane.
5. Re-run idempotency checks on payment webhooks processed during the recovery window.

### Scenario B: Cloud Provider Regional Outage
1. Declare regional failover incident.
2. Direct DNS traffic to standby hot-replica region via Cloudflare load balancer.
3. Promote read-replica in secondary region to primary write cluster.
4. Verify Supabase Auth and Edge Function routing.
5. Notify tenants via StatusPage.

---

## 4. Disaster Recovery Drills & Testing

- **Quarterly Tabletop Simulation**: Review of failure scenarios, credential rotations, and runbook updates.
- **Bi-Annual Live PITR Restoration Drill**: Clone production database to sandbox, execute complete verification test suite (`db_test.mjs`), and validate RTO benchmark.
