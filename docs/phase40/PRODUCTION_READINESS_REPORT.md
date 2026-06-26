# Phase 40 — Production Readiness Report

**Date:** 4 June 2026  
**Scope:** Infrastructure verification for public beta (West Africa launch)

---

## Environment matrix

| Layer | Dev (current) | Staging (required) | Production (required) |
|-------|---------------|-------------------|------------------------|
| Flutter env | `mobile/assets/env/supabase.env` | CI-injected secrets | Store build secrets |
| API env | `services/api/.env` | Secret manager | Secret manager |
| DB | Local Postgres | Managed Postgres | Managed Postgres + backups |
| Integrations | `INTEGRATIONS_MODE=development` | `production` | `production` |

---

## 1. Supabase

| Check | Status | Notes |
|-------|--------|-------|
| Project provisioned | **Configured** | URL in `supabase.env` |
| Auth (email/password) | **Configured** | JWT validated via `SUPABASE_JWT_SECRET` on API |
| Roles in `app_metadata.roles` | **Required** | `client`, `organizer`, `vendor`, `admin_*` |
| RLS policies | **Review** | API uses service role for storage proxy only — never in Flutter |
| Email confirmation | **Verify** | Signup flow uses `signUpAttendee`; confirm policy for beta |
| Anon key in Flutter only | **OK** | No service role in mobile |
| Seed users | **Dev** | `scripts/supabase/seed-dev-auth-users.sql` |

**Flutter variables**

| Variable | Purpose |
|----------|---------|
| `SUPABASE_URL` | Auth + realtime |
| `SUPABASE_ANON_KEY` | Client SDK |
| `OWANBE_API_BASE` | REST API (`/v1`) |
| `OWANBE_TENANT_ID` | `X-Tenant-Id` header |
| `ALLOW_MOCK_PERSISTENCE_FALLBACK` | Must be `false` |

**API variables**

| Variable | Purpose |
|----------|---------|
| `SUPABASE_JWT_SECRET` | JWT verification (required) |
| `SUPABASE_URL` | Storage proxy |
| `SUPABASE_SERVICE_ROLE_KEY` | Server-side uploads only |

---

## 2. Quaser (payments)

| Check | Status | Notes |
|-------|--------|-------|
| `QUASER_ROUTER_BASE_URL` | **Dev stub** | Set for staging/prod |
| `QUASER_ROUTER_API_KEY` | **Unset** | Required for prod |
| `QUASER_WEBHOOK_SECRET` | **Unset** | Webhook at `/webhooks/quaser` |
| `PUBLIC_API_BASE_URL` | **localhost** | Must be public HTTPS URL for webhooks |
| `INTEGRATIONS_MODE=production` | **Not set** | Disables payment stubs |
| S2S verify threshold | `PAYMENT_S2S_VERIFY_THRESHOLD_MINOR=500000` | NGN 5,000 default |

**Boot gate:** `requireProductionConfig()` in `main.ts` fails start if production mode without Quaser + public API URL.

**Verification**

1. Create ticket order → initiate payment → complete on Quaser sandbox.
2. Webhook delivers capture → entitlements issued (`payments_captured_total` metric).
3. Aso-ebi pay endpoint returns `PAYMENT_REQUIRED` when stubs disabled.

---

## 3. FCM (push notifications)

| Check | Status | Notes |
|-------|--------|-------|
| Firebase project | **Not integrated** | No FCM SDK in Flutter or API env |
| Push channel in API | **Log-only** | `NotificationService` supports `push` but logs only |
| Email (Resend) | **Optional** | `RESEND_API_KEY` |
| SMS (Twilio) | **Optional** | `TWILIO_*` |
| Invitation email | **Resend or log** | Uses `notifications.send` |

**Beta recommendation:** Email via Resend for invitations; defer FCM to post-beta. Document in app that push is not yet available.

---

## 4. Storage

| Check | Status | Notes |
|-------|--------|-------|
| Supabase bucket | `STORAGE_BUCKET=owanbe-media` | |
| Presign | API proxy only | Service key never returned to clients (S1 fixed) |
| Upload | `PUT /v1/media/upload/:encodedKey` | Server-side proxy |
| Public URLs | `{SUPABASE_URL}/storage/v1/object/public/...` | |

**Verification:** Presign → upload binary → `public_url` reachable.

---

## 5. Domains & SSL

| Surface | Suggested hostname | SSL |
|---------|-------------------|-----|
| Marketing / Flutter web | `app.owanbe.com` | TLS 1.2+ (CDN) |
| API | `api.owanbe.com` | TLS + HSTS |
| Quaser webhooks | `api.owanbe.com/webhooks/quaser` | Same cert |
| Invitation links | `app.owanbe.com/events/:id/rsvp?token=` | Must match `PUBLIC_API_BASE_URL` invite URLs |

**CORS:** Set `CORS_ORIGINS=https://app.owanbe.com` when `NODE_ENV=production`.

**Not yet in repo:** IaC/Terraform for DNS — manual checklist for ops.

---

## 6. Environment variables (complete API list)

See `services/api/.env.example` and `services/api/src/config/env.schema.ts`.

**Required always**

- `DATABASE_URL`
- `SUPABASE_JWT_SECRET`

**Required for production integrations**

- `INTEGRATIONS_MODE=production`
- `QUASER_ROUTER_BASE_URL`
- `PUBLIC_API_BASE_URL`
- `QUASER_ROUTER_API_KEY` (recommended)
- `QUASER_WEBHOOK_SECRET` (recommended)

**Recommended for beta**

- `RESEND_API_KEY`, `NOTIFICATION_FROM_EMAIL`
- `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`
- `ALERT_WEBHOOK_URL` (Slack/PagerDuty)
- `CORS_ORIGINS`

---

## 7. Database migrations

Apply in order before beta:

```bash
node scripts/apply-phase34-seating-migration.js
node scripts/apply-phase35-program-migration.js
node scripts/apply-phase36-vendor-ops-migration.js
node scripts/apply-phase38-guests-migration.js
```

---

## 8. Health endpoints

| Endpoint | Purpose |
|----------|---------|
| `GET /health` | DB, payments, notifications, storage, integrations mode |
| `GET /metrics` | Prometheus counters (see Monitoring Dashboard doc) |

---

## Infrastructure readiness score

| Component | Score | Blocker? |
|-----------|-------|----------|
| Supabase Auth | 85% | No |
| Postgres / migrations | 80% | Apply 035–038 |
| Quaser payments | 40% | **Yes** for paid beta |
| Notifications | 50% | No for link-based invites |
| Storage | 75% | Configure Supabase bucket |
| FCM | 0% | No for beta (email/link OK) |
| Domains/SSL | 0% (not deployed) | **Yes** for public beta |
| Observability | 65% | Partial metrics wired |

**Overall infrastructure: 58%** — ready for **private staging**, not public internet until Quaser + domains + SSL.
