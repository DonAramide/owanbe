# Phase 43.12 — Test Coverage Audit

**Date:** 2026-06-04

---

## Executive summary

API has solid guard and policy unit tests (10 spec files). Flutter has a single widget smoke test (login). No customer portal widget tests, no integration test suite in repo, certification relies on Node scripts. **Testing grade: 5/10** — acceptable for private beta with manual cert; insufficient for GA without expansion.

---

## Flutter

| Type | Location | Count | Coverage |
|------|----------|-------|----------|
| Widget tests | `mobile/test/widget_test.dart` | 1 | Login title only |
| Integration tests | None found | 0 | — |
| Customer portal tests | None | 0 | **Gap** |
| Event module tests | None | 0 | **Gap** |
| Golden tests | None | 0 | — |

### Recommended additions (debt)

1. `EventFriendlyErrors` never shows raw errors — widget test with failing provider
2. `EventModuleScaffold` breadcrumb renders event title
3. Guest list empty state
4. Navigation smoke: home → event workspace

---

## API (`services/api`)

| Type | Location | Count |
|------|----------|-------|
| Unit specs | `services/api/test/*.spec.ts` | 10 |

### Covered

- `tenant-header.guard.spec.ts`
- `permissions.guard.spec.ts`
- `roles.guard.spec.ts`
- `tenant-isolation.spec.ts`
- `jwt-payload.util.spec.ts`
- `quaser-signature.util.spec.ts`
- `owanbe-throttler.guard.spec.ts`
- `commerce-finance-policy.spec.ts`
- `financial-treasury-dual-write.spec.ts`
- `booking-access.service.spec.ts`

### Gaps

- No controller e2e supertest suite in repo
- No load tests
- Events/guests/invitations services — no dedicated specs

---

## Certification & smoke scripts

| Script | Scope |
|--------|-------|
| `scripts/phase41-certification.js` | Staging API + Quaser flows |
| `scripts/verify-phase10-e2e-certification.js` | E2E certification |
| `scripts/verify-phase10-security-recert.js` | Security recert |

No dedicated `smoke.test.js` — certification scripts serve as smoke harness.

---

## Regression

- Phase 41 customer C1–C14, vendor V1–V7, admin A1–A7 documented in certification markdown.
- Phase 42 navigation regression — manual (organizer redirects).

---

## CI expectations

| Gate | Present |
|------|---------|
| `flutter analyze` | Should run in CI |
| `dart analyze` | Should run |
| `npm run build` (api) | Should run |
| `npm test` (api) | Should run |
| Certification scripts | Manual / staging |

---

## Gap summary

| ID | Gap | Priority |
|----|-----|----------|
| TEST-1 | Customer portal widget tests | P1 |
| TEST-2 | API service integration tests | P1 |
| TEST-3 | Staging e2e in CI | P0 |
| TEST-4 | Load test baseline | P1 |

---

## Phase 43 verification run

Execute as part of phase completion:

```bash
cd mobile && flutter analyze
cd mobile && dart analyze lib/portals/customer
cd services/api && npm run build && npm test
node scripts/phase41-certification.js  # staging
node scripts/verify-phase10-e2e-certification.js
```

Results recorded in `RELEASE_CANDIDATE_CHECKLIST.md`.
