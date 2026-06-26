# Phase 41 — Launch Operations Runbook

**Feature freeze:** No new product features. Execution and verification only.

---

## Quick start

```powershell
# Local full stack (Docker Desktop required)
.\scripts\phase40-2-bootstrap.ps1

# Phase 41 certification (local with mock Quaser — dev only)
$env:PHASE41_ALLOW_MOCK_QUASER="true"
node scripts/phase41-certification.js

# Staging (no mocks)
$env:API_BASE="https://api.staging.owanbe.com/v1"
$env:HEALTH_BASE="https://api.staging.owanbe.com"
$env:STAGING_API_BASE="https://api.staging.owanbe.com"
$env:QUASER_ROUTER_BASE_URL="https://sandbox.quaser.example"
node scripts/phase41-certification.js
```

---

## Deliverables

| Report | Script |
|--------|--------|
| STAGING_DEPLOYMENT_REPORT.md | `phase41-staging-verify.js` |
| STAGING_DATABASE_REPORT.md | `phase41-database-validate.js` |
| QUASER_CERTIFICATION_REPORT.md | `phase41-certification.js` |
| CUSTOMER/VENDOR/ADMIN_CERTIFICATION.md | `phase41-certification.js` |
| MONITORING_CERTIFICATION.md | `phase41-certification.js` |
| SECURITY_CERTIFICATION.md | `phase41-certification.js` |
| PERFORMANCE_REPORT.md | `phase41-performance.js` |
| LAUNCH_READINESS_REPORT_V2.md | `phase41-generate-reports.js` |

---

## Internal operations dashboard

- **API:** `GET /v1/admin/ops/launch-dashboard` (admin JWT)
- **UI:** Admin shell → **Launch ops** tab (first nav item)

---

## Staging domains

| Host | Purpose |
|------|---------|
| api.staging.owanbe.com | NestJS API |
| app.staging.owanbe.com | Flutter web (customer) |
| vendors.staging.owanbe.com | Flutter web (vendor portal) |
| admin.staging.owanbe.com | Flutter web (admin) |

See [`../infra/staging/DEPLOY_RUNBOOK.md`](../infra/staging/DEPLOY_RUNBOOK.md).
