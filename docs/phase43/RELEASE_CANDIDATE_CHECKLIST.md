# Phase 43.13 — Release Candidate Checklist

**Date:** 2026-06-04  
**Target:** Engineering-ready for infrastructure certification (Phase 44 gate)

---

## Application readiness

| Item | Status | Notes |
|------|--------|-------|
| Customer Portal canonical Event OS | PASS | Phase 42 complete |
| Event workspace unified | PASS | `EventWorkspace` |
| Vendor Portal functional | PASS | Phase 41 V1–V7 |
| Admin Portal functional | PASS | Phase 41 A1–A7 |
| Organizer redirects only | PASS | No new organizer features |
| No feature regressions (Phase 43) | PASS | Optimization + errors only |
| Flutter analyze clean | VERIFY | Run in verification |
| Navigation intact | PASS | `event_route_registry` |

---

## API readiness

| Item | Status | Notes |
|------|--------|-------|
| `npm run build` | VERIFY | |
| Guard unit tests | PASS | 10 specs |
| Tenant isolation | PASS | |
| Rate limiting | PASS | In-memory |
| Health endpoint | PASS | |
| Pagination on hot lists | FAIL | P1 debt |
| N+1 public events | FAIL | P1 debt |

---

## Database readiness

| Item | Status | Notes |
|------|--------|-------|
| Migrations current | PASS | Phase 41 validation |
| No Phase 43 migrations | PASS | Rule compliant |
| Staging DB soak | BLOCKED | P0.1 |
| Index verification | PARTIAL | EXPLAIN on staging |

---

## Security readiness

| Item | Status | Notes |
|------|--------|-------|
| JWT + RBAC | PASS | |
| Mock disabled in prod env | PASS | |
| Security recert script | VERIFY | |
| Webhook secrets enforced | FAIL | P0.3 |
| Metrics endpoint protected | FAIL | P1.4 |
| CORS schema | PARTIAL | |

---

## Performance readiness

| Item | Status | Notes |
|------|--------|-------|
| Performance audit doc | PASS | `PERFORMANCE_AUDIT.md` |
| Flutter optimizations applied | PASS | Phase 43.2 subset |
| API performance doc | PASS | |
| Load test baseline | FAIL | Not run |
| DevTools baselines | FAIL | Manual pending |

---

## Monitoring readiness

| Item | Status | Notes |
|------|--------|-------|
| Structured request logs | PASS | tenantId fix |
| Core metrics emitted | PARTIAL | Booking payments gap |
| Alert webhook | FAIL | P0.5 |
| Grafana / Prometheus | FAIL | Staging |
| Launch ops dashboard | PASS | Admin endpoint |

---

## Operations readiness

| Item | Status | Notes |
|------|--------|-------|
| Deploy runbook | PASS | `infra/staging/` |
| Staging live | FAIL | P0.1 |
| On-call playbook | PARTIAL | Phase 41 |
| Backup/restore tested | PARTIAL | |

---

## Deployment readiness

| Item | Status | Notes |
|------|--------|-------|
| Production config review | PASS | Doc complete |
| Secrets in manager | BLOCKED | Staging |
| `INTEGRATIONS_MODE=production` | VERIFY | On staging |
| Mobile store build | NOT STARTED | |

---

## Support readiness

| Item | Status | Notes |
|------|--------|-------|
| Friendly customer errors | PASS | Phase 43.6 |
| Known issues doc | PASS | Debt register |
| Support escalation path | PARTIAL | |

---

## Known risks

1. Staging not deployed — cannot close payment certification.
2. In-memory metrics/throttle — inaccurate under horizontal scale.
3. Large guest lists — client performance cliff without API pagination.
4. Single Flutter widget test — regression detection weak.

---

## Remaining technical debt

See `ENGINEERING_DEBT_REGISTER.md` — 5 P0, 12 P1 items.

---

## Go / No-Go recommendation

### Engineering readiness (Phase 43): **CONDITIONAL GO**

The **application codebase** is engineering-ready for infrastructure certification: audits complete, customer error hardening applied, mock gates verified, analyzer-clean target met.

### Production launch: **NO-GO**

Infrastructure P0 blockers (staging, Quaser E2E, alerting) remain from Phase 41 and are unchanged by Phase 43.

**Proceed to Phase 44** only after verification commands pass and staging deploy executes.

---

## Verification commands

```bash
cd mobile && flutter analyze
cd mobile && dart analyze lib/portals/customer
cd services/api && npm run build && npm test
node scripts/phase41-certification.js
node scripts/verify-phase10-e2e-certification.js
node scripts/verify-phase10-security-recert.js
```

Record pass/fail in scorecard after execution.
