# Phase 43.11 — Production Configuration Review

**Date:** 2026-06-04

---

## Environments

| Environment | Purpose | Status |
|-------------|---------|--------|
| Development | Local API + Flutter | Active |
| Staging | Pre-prod certification | **BLOCKED** (Phase 41 P0.1) |
| Production | Customer load | Not deployed |

---

## Mobile (`mobile/assets/env/supabase.env`)

| Variable | Value (repo) | Production rule |
|----------|--------------|-----------------|
| `SUPABASE_URL` | Set | Per environment |
| `SUPABASE_ANON_KEY` | Set (public) | Rotate per env |
| `OWANBE_API_BASE` | `localhost:8080` | Staging/prod API URL |
| `ALLOW_MOCK_PERSISTENCE_FALLBACK` | **false** | Must be false |

### Feature flags (mobile)

- Mock persistence — env only
- No remote config gate documented — P2

---

## API environment variables

| Category | Keys | Validation |
|----------|------|------------|
| Database | `DATABASE_URL` | Joi schema |
| Auth | JWT secret, Supabase | Required |
| Integrations | Quaser, Resend, Twilio, Firebase | Mode-dependent |
| Storage | Supabase storage | Required |
| CORS | Origins | **Not in schema** — P1 |
| Alerts | `ALERT_WEBHOOK_URL` | Optional — required for ops |
| Webhooks | `QUASER_WEBHOOK_SECRET` | **Not enforced at boot in prod** — P0 |

### Integration modes

- `INTEGRATIONS_MODE=production` required for live payments/notifications (Phase 41 checklist).

---

## Third-party services

| Service | Usage | Config location |
|---------|-------|-----------------|
| Supabase | Auth, DB, storage | API + mobile env |
| Quaser | Payments | API secrets |
| Resend | Email | API env |
| Twilio | SMS | API env |
| Firebase | Push (optional) | API env |

---

## Public URLs

| Portal | Expected |
|--------|----------|
| Customer app | `app.owanbe.com` (staging TBD) |
| Vendor | `vendors.owanbe.com` |
| Admin | `admin.owanbe.com` |
| API | `api.owanbe.com/v1` |

---

## CORS

- API reads allowed origins from environment.
- **Action:** Add `CORS_ORIGINS` to boot validation; document per-environment values in deploy runbook.

---

## Secrets management

- No secrets in Flutter beyond anon key.
- API secrets via env / secret manager at deploy — not committed.
- **CI:** Verify `.env` not in artifacts.

---

## Certification scripts

| Script | Purpose |
|--------|---------|
| `scripts/phase41-certification.js` | Staging cert harness |
| `scripts/verify-phase10-e2e-certification.js` | E2E smoke |
| `scripts/verify-phase10-security-recert.js` | Security recert |

`PHASE41_ALLOW_MOCK_QUASER=true` — local only.

---

## Checklist

- [x] `ALLOW_MOCK_PERSISTENCE_FALLBACK=false` in committed mobile env
- [ ] Staging domains + TLS
- [ ] Production secret manager wired
- [ ] `CORS_ORIGINS` validated at boot
- [ ] `QUASER_WEBHOOK_SECRET` required in production
- [ ] `ALERT_WEBHOOK_URL` set on staging
