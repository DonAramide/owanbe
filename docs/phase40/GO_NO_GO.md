# Phase 40 — Public Beta GO / NO-GO

**Date:** 4 June 2026  
**Decision owner:** Launch steering  
**Recommendation:** **CONDITIONAL GO** — private/staging beta only; **NO-GO** for open public beta until blockers cleared.

---

## Scorecard

| Area | Weight | Score | Weighted |
|------|--------|-------|----------|
| Security (S1–S5) | 20% | 90% | 18.0 |
| Guest / invitation infra | 20% | 85% | 17.0 |
| Mock elimination | 15% | 85% | 12.8 |
| Production infrastructure | 20% | 58% | 11.6 |
| Payment verification | 15% | 45% | 6.8 |
| Monitoring & ops | 10% | 70% | 7.0 |
| **Total** | 100% | | **78.2%** |

---

## GO criteria (public beta)

| # | Criterion | Status |
|---|-----------|--------|
| 1 | Migrations 034–038 applied on staging | ⬜ Verify |
| 2 | `INTEGRATIONS_MODE=production` + Quaser sandbox E2E | ⬜ Blocked |
| 3 | HTTPS API + app domains live | ⬜ Blocked |
| 4 | `ALLOW_MOCK_PERSISTENCE_FALLBACK=false` | ✅ Done |
| 5 | Vendor order/catalog mock writes removed | ✅ Done (P40.1/P40.2) |
| 6 | Beta scripts C1–C14 pass on staging | ⬜ Pending soak |
| 7 | Metrics + alerts wired | ⚠️ Partial |
| 8 | Resend (or webhook) for invitation email | ⬜ Optional |

**Met:** 1/8 strict; 2/8 with optional email.

---

## Decision matrix

| Audience | Verdict | Rationale |
|----------|---------|-----------|
| **Internal QA / staging** | **GO** | Core flows API-backed; security fixes in place; test scripts ready |
| **Invite-only private beta** (≤50 organizers) | **CONDITIONAL GO** | After Quaser sandbox + migration apply + 48h soak; vendor writes API-backed |
| **Open public beta** | **NO-GO** | Domains/SSL, Quaser production, FCM N/A |

---

## Blockers to lift NO-GO → GO

1. Deploy API + Flutter web to staging with TLS.
2. Configure Quaser (URL, API key, webhook secret) and run ticket payment E2E.
3. ~~Fix `orders_bookings_screen` + `service_catalog_screen` unconditional `VendorStore` writes.~~ **Done (P40.1/P40.2)**
4. Apply DB migrations on staging.
5. Run full beta scripts; zero P0 failures.
6. Connect `ALERT_WEBHOOK_URL` and Grafana dashboard per monitoring doc.

**Estimated effort:** 5–8 engineering days + ops.

---

## What ships in this phase (documentation + observability)

| Deliverable | Location |
|-------------|----------|
| A. Mock Elimination Report | [`docs/phase40/MOCK_ELIMINATION_REPORT.md`](MOCK_ELIMINATION_REPORT.md) |
| B. Production Readiness Report | [`docs/phase40/PRODUCTION_READINESS_REPORT.md`](PRODUCTION_READINESS_REPORT.md) |
| C. Beta Test Scripts | [`docs/phase40/BETA_TEST_SCRIPTS.md`](BETA_TEST_SCRIPTS.md) |
| D. Monitoring Dashboard | [`docs/phase40/MONITORING_DASHBOARD.md`](MONITORING_DASHBOARD.md) |
| E. Marketplace Trust (design) | [`docs/phase40/MARKETPLACE_TRUST_LAYER_DESIGN.md`](MARKETPLACE_TRUST_LAYER_DESIGN.md) |
| F. Launch Readiness Report (P40.1) | [`docs/phase40/LAUNCH_READINESS_REPORT.md`](LAUNCH_READINESS_REPORT.md) |
| Metrics instrumentation | `api_errors_total`, `invitations_*`, `rsvp_*` (API) |

---

## Final recommendation

**CONDITIONAL GO** for **invite-only staging beta** once Quaser sandbox and migrations are verified.

**NO-GO** for **public open beta** until infrastructure (domains, SSL, payments) is verified.

Re-evaluate after Quaser sandbox and staging soak documented in [`LAUNCH_READINESS_REPORT.md`](LAUNCH_READINESS_REPORT.md).

---

*Prior sprint:* [`../LAUNCH_HARDENING_REPORT.md`](../LAUNCH_HARDENING_REPORT.md)
