# Phase 40.2 — Staging Deployment Runbook

**Target:** `api.staging.owanbe.com` + `app.staging.owanbe.com`  
**No product feature changes** — infrastructure and verification only.

---

## Prerequisites

| Item | Value |
|------|-------|
| Managed Postgres | Connection string in secret manager |
| Supabase project | JWT secret, anon key, service role |
| Quaser sandbox | Router URL, API key, webhook secret |
| DNS | `api.staging.*`, `app.staging.*` |
| TLS | Let's Encrypt or CDN (Cloudflare) |

---

## 1. API deployment

```bash
# Build
cd services/api && npm ci && npm run build

# Environment (secret manager)
NODE_ENV=production
PORT=8080
DATABASE_URL=postgres://...
SUPABASE_JWT_SECRET=...
INTEGRATIONS_MODE=production
QUASER_ROUTER_BASE_URL=https://sandbox.quaser.example
QUASER_ROUTER_API_KEY=...
QUASER_WEBHOOK_SECRET=...
PUBLIC_API_BASE_URL=https://api.staging.owanbe.com
CORS_ORIGINS=https://app.staging.owanbe.com
ALERT_WEBHOOK_URL=https://hooks.slack.com/services/...
```

**Health check:** `GET https://api.staging.owanbe.com/health` → `status: ok`

**Quaser webhook URL:** `https://api.staging.owanbe.com/webhooks/quaser`

---

## 2. Flutter web deployment

```bash
cd mobile
# Inject staging env
cp assets/env/supabase.env.staging.example assets/env/supabase.env
# OWANBE_API_BASE=https://api.staging.owanbe.com/v1
# ALLOW_MOCK_PERSISTENCE_FALLBACK=false

flutter build web --release
# Deploy build/web/ to CDN or static host at app.staging.owanbe.com
```

---

## 3. Database migrations

```bash
node scripts/phase40-2-apply-migrations.js
# Validates tables 034–038 + schema_migrations history
```

---

## 4. TLS + CORS verification

```bash
curl -I https://api.staging.owanbe.com/health
curl -I -H "Origin: https://app.staging.owanbe.com" \
  -X OPTIONS https://api.staging.owanbe.com/v1/events
# Expect Access-Control-Allow-Origin: https://app.staging.owanbe.com
```

---

## 5. Full readiness execution

```bash
# Local (Windows — requires Docker Desktop)
powershell -File scripts/phase40-2-bootstrap.ps1

# Staging
API_BASE=https://api.staging.owanbe.com/v1 \
HEALTH_BASE=https://api.staging.owanbe.com \
STAGING_API_BASE=https://api.staging.owanbe.com \
node scripts/phase40-2-staging-readiness.js

node scripts/phase40-2-generate-reports.js
```

Results: `docs/phase40/results/phase40-2-*.json`  
Reports: `MIGRATION_VALIDATION_REPORT.md`, `PAYMENT_VERIFICATION_REPORT.md`, `BETA_EXECUTION_LOG.md`, `FINAL_GO_NO_GO.md`

---

## Local staging simulation (dev)

```bash
docker compose up -d postgres
node scripts/phase40-2-apply-migrations.js

# Terminal 1 — mock Quaser
MOCK_QUASER_PORT=9090 QUASER_WEBHOOK_SECRET=phase9-test-webhook-secret node scripts/mock-quaser-server.js

# Terminal 2 — API
cd services/api
$env:SUPABASE_JWT_SECRET="dev-jwt-secret-16chars"
$env:INTEGRATIONS_MODE="production"
$env:QUASER_ROUTER_BASE_URL="http://localhost:9090"
$env:PUBLIC_API_BASE_URL="http://localhost:8080"
$env:QUASER_WEBHOOK_SECRET="phase9-test-webhook-secret"
npm run start

# Terminal 3 — readiness
node scripts/phase40-2-staging-readiness.js
```

---

## Rollback

1. Revert API deployment to previous image/tag.
2. Do **not** roll back migrations without DBA review.
3. Point DNS back if TLS misconfigured.
