# Phase 43.10 — Observability Audit

**Date:** 2026-06-04  
**Prior art:** `docs/phase41/MONITORING_CERTIFICATION.md`, `LOGGING_CERTIFICATION.md`

---

## Executive summary

API emits structured request logs and Prometheus-style counters via in-memory `MetricsService`. Launch ops dashboard aggregates key metrics. Gaps: multi-pod metric fusion, unauthenticated `/metrics`, incomplete payment metric coverage, and PII in notification debug logs.

---

## Metrics inventory

| Metric | Emitted | Location | Notes |
|--------|---------|----------|-------|
| `api_errors_total` | Yes | `owanbe-exception.filter.ts` | Labels: status, path |
| `payments_captured_total` | Partial | `ticket-capture.service.ts` | `rail: ticket` only |
| `notifications_sent_total` | Yes | `notification.service.ts` | By channel |
| `notifications_failed_total` | Yes | notification service | — |
| `rsvp_total` | Yes | `event-invitations.service.ts` | By status |
| `rsvp_confirmed_total` | Yes | launch dashboard | Aggregated |
| `storage_proxy_upload_total` | Yes | `storage.service.ts` | — |

### Gap

Booking/rental payment capture does not increment `payments_captured_total` — finance ops blind spot (P1).

---

## Request logging

`RequestLogMiddleware` fields:

| Field | Present | Phase 43 fix |
|-------|---------|--------------|
| `requestId` | Yes | — |
| `tenantId` | Yes | Now uses `req.tenantId` after JWT guard |
| `userId` | Yes | Post-auth routes |
| `eventId` | Yes | From route params |
| `durationMs` | Yes | — |
| `status` | Yes | HTTP code |
| `method` / `path` | Yes | — |

---

## Health & metrics endpoints

| Endpoint | Auth | Purpose |
|----------|------|---------|
| `GET /health` | Public | Liveness + DB check |
| `GET /metrics` | **Public** | Prometheus scrape — **restrict in prod** |
| `GET /admin/ops/launch-dashboard` | Admin | Internal dashboard |

---

## Audit logs

- Super-admin mutations write audit rows (tenant, actor, resource).
- Finance dual-write has policy tests.

---

## PII & secrets

| Risk | Status |
|------|--------|
| Passwords in logs | Not logged |
| JWT in logs | Not logged |
| Email/phone in notification debug | **Risk** — reduce log level in prod |
| Webhook secrets | Env only |

---

## Critical workflow coverage

| Workflow | Metric / log | Covered |
|----------|--------------|---------|
| Login | Request log | Yes |
| Create event | Request log + audit | Yes |
| RSVP | `rsvp_total` | Yes |
| Ticket payment | `payments_captured_total` | Yes |
| Booking payment | — | **No** |
| Invite send | `notifications_sent_total` | Yes |
| Media upload | `storage_proxy_upload_total` | Yes |
| API errors | `api_errors_total` | Yes |

---

## Recommendations

| ID | Action | Priority |
|----|--------|----------|
| OBS-1 | `payments_captured_total` on booking webhook | P1 |
| OBS-2 | Protect `/metrics` | P1 |
| OBS-3 | Redis-backed metrics for K8s | P1 |
| OBS-4 | `ALERT_WEBHOOK_URL` + Grafana (Phase 41 blocker) | P0 |
| OBS-5 | Flutter client breadcrumb logging (Sentry) | P2 |

---

## Verification

- Hit `/health` — expect 200
- Hit `/metrics` — counters present after traffic
- Confirm `requestId` in log line JSON
