# Phase 9 — Production Integrations Report

**Baseline:** `v0.9.0-security-pass`  
**Migration:** `026_phase9_integrations.sql`  
**Gate result:** PASS (5/5)

## Gate

```bash
node scripts/apply-phase9-migration.js

# Restart API with production integration env:
# INTEGRATIONS_MODE=production
# QUASER_ROUTER_BASE_URL=http://localhost:9090
# QUASER_ROUTER_API_KEY=phase9-test-key
# QUASER_WEBHOOK_SECRET=phase9-test-webhook-secret
# PUBLIC_API_BASE_URL=http://localhost:8080
# NOTIFICATION_WEBHOOK_URL=http://127.0.0.1:<port>/notify

node scripts/mock-quaser-server.js   # terminal 1 (or gate starts it)
node scripts/verify-phase9-production-integrations.js
```

## Integrations Delivered

| Area | Implementation |
|------|----------------|
| Payments | `INTEGRATIONS_MODE=production` disables auto-stub; Quaser HTTP client + signed webhooks; mock router for gate |
| Notifications | `NotificationService` — Resend email, Twilio SMS, webhook fallback; `notification_deliveries` audit table |
| Storage | Supabase Storage presign via `POST /v1/media/presign`; `media_objects` registry; dispute evidence accepts `storageObjectId` |
| Realtime | SSE `GET /v1/events/:eventId/feed/stream`; broadcast on check-in + incidents |
| Observability | Enhanced `/health` (DB + integration checks); Prometheus `/metrics` |

## Workflow Wiring

- Ticket capture → confirmation email (`ticket_confirmation` template)
- `POST /ticket-entitlements/:id/resend` → re-deliver ticket email
- Finance alerts → `ALERT_EMAIL_TO` via Resend/webhook (no placeholder log)
- Dispute evidence → `storageObjectId` resolves to stored media URL
- Ops check-in / incidents → realtime feed broadcast

## Env Reference

See `services/api/.env.example` Phase 9 section.
