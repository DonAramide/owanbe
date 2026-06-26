# Phase 40 — Monitoring Dashboard

**Purpose:** Beta operations visibility for API, invitations, payments, notifications, and RSVP failures.  
**Stack:** Prometheus scrape of `GET /metrics` + optional Grafana dashboard.

---

## Data sources

| Source | Endpoint | Format |
|--------|----------|--------|
| API metrics | `GET https://api.owanbe.com/metrics` | Prometheus text |
| Health | `GET https://api.owanbe.com/health` | JSON integration status |
| DB audit | `notification_deliveries`, `event_invitations` | SQL (ops) |
| Quaser | Quaser admin / webhook logs | External |

**Scrape config (Prometheus)**

```yaml
scrape_configs:
  - job_name: owanbe-api
    metrics_path: /metrics
    static_configs:
      - targets: ['api.owanbe.com:443']
    scheme: https
    scrape_interval: 30s
```

---

## Metric catalog (beta)

### API failures

| Metric | Labels | Emitted when |
|--------|--------|--------------|
| `api_errors_total` | `status`, `code`, `route` | Any HTTP exception via `OwanbeExceptionFilter` |

**Grafana panel — error rate (5m)**

```promql
sum(rate(api_errors_total[5m])) by (code)
```

**Alert:** `sum(rate(api_errors_total{status="500"}[5m])) > 0.1` for 10m → page on-call.

---

### Invitation failures

| Metric | Labels | Emitted when |
|--------|--------|--------------|
| `invitations_sent_total` | `channel` | Invitation batch send succeeds per guest |
| `invitations_failed_total` | `reason` | `email_delivery`, `invalid_token` |

**Grafana panel — invite success ratio**

```promql
sum(rate(invitations_sent_total[1h]))
/
(sum(rate(invitations_sent_total[1h])) + sum(rate(invitations_failed_total[1h])))
```

**SQL fallback (delivery tracking)**

```sql
SELECT status, COUNT(*) FROM event_invitations
WHERE created_at > now() - interval '24 hours'
GROUP BY status;
```

---

### Payment failures

| Metric | Labels | Emitted when |
|--------|--------|--------------|
| `payments_captured_total` | `rail=ticket` | Ticket webhook capture success |

**Gap (post-P40):** Add `payments_failed_total` on Quaser webhook reject and capture rollback.

**Interim:** Monitor Quaser dashboard + `ticket_orders` where `payment_status = 'failed'`.

```sql
SELECT payment_status, COUNT(*) FROM ticket_orders
WHERE created_at > now() - interval '24 hours'
GROUP BY payment_status;
```

---

### Notification failures

| Metric | Labels | Emitted when |
|--------|--------|--------------|
| `notifications_sent_total` | `channel` | email/sms/push dispatch ok |
| `notifications_failed_total` | `channel` | dispatch failed |

```promql
sum(rate(notifications_failed_total[1h])) by (channel)
```

**SQL**

```sql
SELECT channel, status, COUNT(*) FROM notification_deliveries
WHERE created_at > now() - interval '24 hours'
GROUP BY channel, status;
```

---

### RSVP failures

| Metric | Labels | Emitted when |
|--------|--------|--------------|
| `rsvp_total` | `status` | confirmed / declined success |
| `rsvp_failed_total` | `reason` | `invalid_token`, `invalid_status` |

```promql
sum(rate(rsvp_failed_total[1h])) by (reason)
```

---

### Storage (upload health)

| Metric | Notes |
|--------|-------|
| `storage_presign_total` | Presign requests |
| `storage_proxy_upload_total` | Successful proxy uploads |

---

## Grafana dashboard layout (recommended)

```
┌─────────────────────────────────────────────────────────┐
│ OWANBE Beta — Launch Ops          [health: ok/degraded] │
├──────────────┬──────────────┬──────────────┬────────────┤
│ API errors   │ Invite ratio │ Pay captures │ RSVP fails │
│  (5m rate)   │   (1h %)     │   (24h)      │   (1h)     │
├──────────────┴──────────────┴──────────────┴────────────┤
│ notifications_failed by channel (stacked)               │
├─────────────────────────────────────────────────────────┤
│ api_errors_total by route (top 10)                      │
└─────────────────────────────────────────────────────────┘
```

---

## Alert routing

| Variable | Purpose |
|----------|---------|
| `ALERT_WEBHOOK_URL` | Slack/PagerDuty on payment or error spikes |
| `ALERT_EMAIL_TO` | Email fallback |
| `ALERT_DEDUPE_WINDOW_MS` | 120s default dedupe |

**Beta minimum:** Wire `ALERT_WEBHOOK_URL` to Slack `#owanbe-beta-ops`.

---

## Admin UI (current)

- **Super Admin / Platform:** `GET /health` surfaced in system health service.
- **No embedded Grafana in app** — use external dashboard for beta.

---

## Phase 40 instrumentation changelog

- `OwanbeExceptionFilter` → `api_errors_total`
- `EventInvitationsService` → `invitations_*`, `rsvp_*`
- Existing: `notifications_*`, `payments_captured_total`, `storage_*`

Run `curl -s localhost:8080/metrics | rg 'api_errors|invitation|rsvp|notification|payment'`
