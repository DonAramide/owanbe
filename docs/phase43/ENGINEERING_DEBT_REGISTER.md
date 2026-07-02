# Phase 43.14 — Engineering Debt Register

**Date:** 2026-06-04  
**Owner:** Engineering (default) unless noted

---

## P0 — Production blockers

| ID | Item | Impact | Risk | Effort | Release |
|----|------|--------|------|--------|---------|
| DEBT-P0-1 | Staging infrastructure + TLS | Cannot certify payments | High | 2–5d | Pre-beta |
| DEBT-P0-2 | Quaser sandbox E2E without mocks | Payment unverified | High | 3d | Pre-beta |
| DEBT-P0-3 | `QUASER_WEBHOOK_SECRET` boot enforcement | Silent misconfig | High | 0.5d | Pre-beta |
| DEBT-P0-4 | Payment flows C12–C14 on staging | Revenue blocked | High | 2d | Pre-beta |
| DEBT-P0-5 | `ALERT_WEBHOOK_URL` + Grafana scrape | Blind incidents | High | 1d | Pre-beta |

---

## P1 — Pre-GA required

| ID | Item | Impact | Risk | Effort | Release |
|----|------|--------|------|--------|---------|
| DEBT-P1-1 | Guest list API pagination | Slow large events | Medium | 3d | RC1 |
| DEBT-P1-2 | Public events N+1 fix | Slow discovery | Medium | 2d | RC1 |
| DEBT-P1-3 | Wall feed pagination | UI jank | Medium | 2d | RC1 |
| DEBT-P1-4 | `/metrics` authentication | Info disclosure | Medium | 0.5d | RC1 |
| DEBT-P1-5 | Distributed rate limit + metrics | Multi-pod skew | Medium | 3d | RC1 |
| DEBT-P1-6 | `payments_captured_total` booking rail | Finance ops | Low | 0.5d | RC1 |
| DEBT-P1-7 | CORS_ORIGINS in env schema | Misconfig | Medium | 0.5d | RC1 |
| DEBT-P1-8 | Customer portal widget tests | Regression risk | Medium | 5d | RC1 |
| DEBT-P1-9 | API explicit timeouts (mobile) | Hung UI | Medium | 1d | RC1 |
| DEBT-P1-10 | GuestListTile Semantics | A11y | Low | 0.5d | RC1 |
| DEBT-P1-11 | `customer_create_event_screen` → native wizard | Organizer import | Low | 5d | Post-GA |
| DEBT-P1-12 | Invitation send queue (async) | Timeout on bulk | Medium | 3d | RC1 |

---

## P2 — Quality improvements

| ID | Item | Impact | Risk | Effort | Release |
|----|------|--------|------|--------|---------|
| DEBT-P2-1 | `cached_network_image` marketplace | Bandwidth | Low | 1d | GA+1 |
| DEBT-P2-2 | `ref.select` pass all modules | Rebuilds | Low | 2d | GA+1 |
| DEBT-P2-3 | Connectivity auto-refresh | UX | Low | 1d | GA+1 |
| DEBT-P2-4 | CI mock-flag guard | Safety | Low | 0.5d | RC1 |
| DEBT-P2-5 | Marketplace vendor profile cache | Duplicate API | Low | 1d | GA+1 |
| DEBT-P2-6 | Notification log PII mask | Compliance | Low | 0.5d | RC1 |
| DEBT-P2-7 | Loading semantics (a11y) | A11y | Low | 1d | GA+1 |

---

## Future — Intentional deferrals

| ID | Item | Notes |
|----|------|-------|
| DEBT-F-1 | Remove Organizer code | Blocked by Phase 43 rule 7 |
| DEBT-F-2 | EventBook | Out of scope |
| DEBT-F-3 | Marketplace expansion | Out of scope |
| DEBT-F-4 | AI enhancements | Out of scope |
| DEBT-F-5 | DB redesign | Out of scope |
| DEBT-F-6 | Redis catalog cache | Scale trigger |

---

## Phase 42 carryover

| Item | Status |
|------|--------|
| Legacy organizer redirects | Kept |
| `legacy_organizer_compat.dart` deprecated | Zero runtime refs |
| EventCreateWizardV2 organizer import | One remaining touchpoint |
