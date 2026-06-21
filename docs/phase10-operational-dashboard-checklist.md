# Phase 10 — Operational Dashboard Checklist

Use this checklist when wiring production monitoring (Datadog, Grafana, CloudWatch, etc.).

## Health & Availability

- [ ] `GET /health` — overall status + integration checks (200/503 alerting)
- [ ] `GET /metrics` — Prometheus scrape every 30s
- [ ] Super Admin `GET /super-admin/system/health` — cross-tenant composite
- [ ] Uptime SLO: 99.5% monthly

## Metrics to Chart

| Metric | Source | Alert threshold |
|--------|--------|-----------------|
| `owanbe_up` | `/metrics` | == 0 for 2m |
| `payments_captured_total` | `/metrics` | anomaly drop >50% |
| `notifications_failed_total` | `/metrics` | >10/min |
| `storage_presign_total` | `/metrics` | error rate >5% |
| HTTP 5xx rate | LB logs | >1% for 5m |
| p95 latency | LB logs | >2s for 10m |

## Logs

- [ ] Structured JSON logs with `request_id`
- [ ] Finance alerts (`AlertsService`) forwarded to PagerDuty/Slack
- [ ] Security events (`platform_security_events`) reviewed daily
- [ ] Failed login spike >20/min → Security Center review

## SLO Monitoring

| SLO | Target |
|-----|--------|
| Ticket purchase success | 99% |
| Check-in API success | 99.5% |
| Admin dashboard p95 | <2s |
| Webhook processing | 99.9% idempotent ack |

## Alert Routes

- **CRITICAL:** payment mismatch, webhook verification failure, DB down
- **WARNING:** rate limit violations, permission escalation, finance timeout
- **INFO:** deployment complete, backup success

## Verification

```bash
node scripts/verify-phase10-observability.js
```
