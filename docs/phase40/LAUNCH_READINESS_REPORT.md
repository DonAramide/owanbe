# Phase 40.1 — Launch Readiness Report

**Date:** 4 June 2026  
**Sprint:** Beta Launch Closure  
**Feature freeze:** Active — no EventBook, reviews, ratings, new AI, marketplace categories, or social features.

---

## Executive summary

Phase 40.1 closes the two **critical mock write blockers** (P40.1 vendor orders, P40.2 vendor catalog). Remaining launch work is **infrastructure and verification**, not product features.

| Metric | Phase 40 | Phase 40.1 |
|--------|----------|------------|
| Mock write blockers (critical) | 2 | **0** |
| Overall launch readiness | 69% | **78%** |
| Public beta recommendation | NO-GO | **CONDITIONAL GO** (invite-only) |

---

## Completed in Phase 40.1

### P40.1 — Vendor order status (API-backed)

| Layer | Change |
|-------|--------|
| API | `PATCH /v1/bookings/:bookingId/status` with actions `accept`, `fulfill`, `cancel` |
| API | Enriched `GET /v1/bookings` with `packageName`, `clientName`, `eventTitle` |
| Flutter | `VendorBookingsApi` + `vendorOrdersProvider` → API first |
| UI | `orders_bookings_screen.dart` — no unconditional `VendorStore` writes |

### P40.2 — Vendor catalog (API-backed)

| Layer | Change |
|-------|--------|
| API | `GET/POST /v1/vendor/packages`, `PATCH /v1/vendor/packages/:id` |
| DB | Uses existing `vendor_packages` table |
| Flutter | `VendorCatalogApi` + `vendorCatalogProvider` → API first |
| UI | `service_catalog_screen.dart` — create/toggle via API |

Mock fallbacks remain **only** when `ALLOW_MOCK_PERSISTENCE_FALLBACK=true` (dev).

---

## Remaining blockers

| ID | Blocker | Owner | ETA |
|----|---------|-------|-----|
| B1 | **Quaser sandbox E2E** — ticket purchase → webhook → entitlement not verified on staging | Eng + Finance | 2–3 days |
| B2 | **Staging deployment + TLS** — `api.*` and `app.*` not live | DevOps | 2–5 days |
| B3 | **DB migrations** — apply 034–038 on staging | DevOps | 0.5 day |
| B4 | **Beta script execution** — C1–C14, V1–V7, A1–A7 not yet run on staging | QA | 2 days after B2 |
| B5 | **Monitoring alerts** — `ALERT_WEBHOOK_URL` + Grafana not connected | Ops | 1 day |
| B6 | **Organizer persistence fallbacks** — `organizer_persistence.dart` still falls back to `OrganizerEventStore` on API error (non-critical for beta if API stable) | Eng | Post-beta |
| B7 | **FCM push** — not integrated; email/link invites only | Product | Post-beta |
| B8 | **Resend / Twilio** — invitation email/SMS in log-only mode without keys | Ops | 1 day |

**Launch-critical path:** B1 → B2 → B3 → B4 → B5

---

## Risk register

| ID | Risk | Likelihood | Impact | Mitigation |
|----|------|------------|--------|------------|
| R1 | Quaser webhook misconfiguration in staging | Medium | High | Run payment script; verify `payments_captured_total` metric |
| R2 | Empty vendor bookings/catalog on fresh staging (no seed data) | High | Medium | Seed `vendor_packages` + test booking for demo vendor |
| R3 | Supabase email confirmation blocks new signups (C3) | Medium | Medium | Disable confirm or use pre-verified beta accounts |
| R4 | API downtime causes organizer mock fallback confusion | Low | Medium | `ALLOW_MOCK_PERSISTENCE_FALLBACK=false` in beta builds |
| R5 | Public seating/program endpoints expose ops data | Medium | Low | Accept for beta; restrict post-launch |
| R6 | No FCM — guests miss real-time updates | High | Low | Email + share links for invitations |
| R7 | Vendor dev ID hardcoded in onboarding screen | Medium | Low | Resolve vendor from JWT profile before wide beta |
| R8 | In-memory Prometheus metrics lost on API restart | High | Low | Scrape interval ≤30s; add external APM post-beta |

---

## Verification status (priorities 3–8)

| Priority | Task | Status |
|----------|------|--------|
| 3 | Quaser sandbox E2E | **Not run** — requires staging + Quaser |
| 4 | Staging deployment with TLS | **Not deployed** |
| 5 | Monitoring & alerts | **Partial** — metrics wired; Grafana/alerts pending |
| 6 | Beta scripts C1–C14 | **Ready** — see [`BETA_TEST_SCRIPTS.md`](BETA_TEST_SCRIPTS.md) |
| 7 | Vendor journey V1–V7 | **Ready** — V6/V7 unblocked by P40.1/P40.2 |
| 8 | Admin journey A1–A7 | **Ready** — pending staging admin seed |
| 9 | Launch Readiness Report | **This document** |

---

## Public beta recommendation

### Open public beta — **NO-GO**

Reasons:
- Production HTTPS endpoints not live
- Quaser payment path not verified end-to-end on staging
- Beta test scripts not executed with pass record
- Alerting not connected

### Invite-only private beta — **CONDITIONAL GO**

Proceed when **all** are true:
1. Migrations 034–038 applied on staging
2. API at `https://api.<domain>/v1` with valid TLS
3. Flutter web at `https://app.<domain>` with `ALLOW_MOCK_PERSISTENCE_FALLBACK=false`
4. Quaser sandbox completes at least one ticket purchase E2E
5. C1–C10 pass (customer core); V2–V6 pass (vendor); A2–A4 pass (admin health)
6. `GET /metrics` scraped; one alert rule on `api_errors_total`

**Target cohort:** ≤50 organizers, ≤20 vendors, internal admin — 7-day soak.

### Full public beta — **NO-GO** until

- 48h invite-only soak with zero P0 incidents
- B6 organizer fallbacks removed or API SLO ≥99.5%
- Resend configured for invitation email
- Risk R5 seating/program access reviewed

---

## Next actions (ordered)

```text
1. Deploy API + DB to staging (B2, B3)
2. Configure Quaser + PUBLIC_API_BASE_URL (B1)
3. Run scripts/apply-phase38-guests-migration.js (+ 034–037)
4. Seed vendor_packages + test booking for demo vendor
5. Execute BETA_TEST_SCRIPTS.md — record pass/fail
6. Wire Grafana + ALERT_WEBHOOK_URL (B5)
7. Go/no-go review with stakeholders
```

---

## Related documents

- [`MOCK_ELIMINATION_REPORT.md`](MOCK_ELIMINATION_REPORT.md) — P40.1/P40.2 closed
- [`MIGRATION_VALIDATION_REPORT.md`](MIGRATION_VALIDATION_REPORT.md) — Phase 40.2
- [`PAYMENT_VERIFICATION_REPORT.md`](PAYMENT_VERIFICATION_REPORT.md) — Phase 40.2
- [`BETA_EXECUTION_LOG.md`](BETA_EXECUTION_LOG.md) — Phase 40.2
- [`FINAL_GO_NO_GO.md`](FINAL_GO_NO_GO.md) — **Phase 40.2 decision**

---

## Frozen scope (do not implement)

EventBook · Reviews · Ratings · Additional AI · New marketplace categories · New social features
