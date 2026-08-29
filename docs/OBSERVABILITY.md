# LiftFlow Observability, Telemetry & Alerting Strategy

This document details the monitoring, structured logging, distributed tracing, and incident alerting architecture for the LiftFlow SaaS platform.

---

## 1. Structured Logging Architecture

### Client-Side (Flutter)
- Errors and network failures are captured via structured logger without logging PII (Personally Identifiable Information, such as payment details or plain passwords).
- Sentry / Datadog SDK integration wraps the Flutter root zone:

```dart
// Zone-level exception handling
runZonedGuarded(() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: App()));
}, (error, stack) {
  // Dispatched to observability telemetry sink
});
```

### Serverless Edge Functions (Deno / TypeScript)
- Edge functions format all logs as single-line JSON with standard attributes:
  - `timestamp`: ISO-8601 UTC.
  - `level`: `INFO`, `WARN`, `ERROR`.
  - `tenant_id`: Active `gym_id`.
  - `trace_id`: Request correlation ID.
  - `event_name`: Named domain event (`ATTENDANCE_RECORDED`, `NO_SHOW_DETECTED`, `PAYMENT_PROCESSED`).
  - `latency_ms`: Execution duration.

---

## 2. Core Operational Metrics & KPIs

| Metric Name | Type | Source | SLA / Target | Alert Threshold |
| :--- | :--- | :--- | :--- | :--- |
| `qr_checkin.latency_p99` | Histogram | Edge Function | < 300ms | > 800ms for 3m |
| `qr_checkin.error_rate` | Rate | Edge Function | < 0.05% | > 1.0% for 5m |
| `db.pool_exhaustion` | Gauge | Postgres | 0 | > 80% capacity |
| `no_show_scanner.duration` | Gauge | Cron Worker | < 60s | > 180s |
| `renewal_orders.failed_rate` | Rate | Stripe Webhook | < 0.1% | > 2.0% for 10m |

---

## 3. Distributed Tracing & Correlation

- Every client request attaches an `X-Request-ID` / `X-Correlation-ID` header.
- Edge Functions propagate the correlation ID to Supabase DB RPCs and downstream external APIs (Stripe, Twilio, SendGrid).
- On error, the correlation ID is returned in the API error response, enabling instant log lookup in customer support workflows.

---

## 4. Alert Routing & Escalation Policy

1. **P1 (Critical Outage / RLS Breach / Database Down)**:
   - Automated Page to On-Call Engineer via PagerDuty / Opsgenie.
   - Immediate notification in `#incidents-p1` Slack channel.
2. **P2 (Elevated Check-in Failures / High Latency)**:
   - Slack alert in `#eng-alerts` with 15-minute escalation timer.
3. **P3 (Minor Background Task Warning / Retry Spikes)**:
   - Digest in daily engineering dashboard.
