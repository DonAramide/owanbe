# Phase 43.6 — Error Handling Review

**Date:** 2026-06-04  
**Includes:** Phase 43.7 Offline & Recovery (merged per deliverable structure)

---

## Policy

Customer-facing surfaces must **never** expose:

- Stack traces
- Exception class names or messages
- HTTP status codes
- Raw API error bodies

Use `EventFriendlyErrors` and `EventErrorView` (Event OS modules) or `EmptyStateCard` with generic copy (shell routes).

---

## Module compliance matrix

| Surface | Status (post Phase 43) | Pattern |
|---------|------------------------|---------|
| Event workspace modules | PASS | `EventErrorView.module` |
| Customer Home | PASS | `EventFriendlyErrors` + skeleton |
| My Events | PASS | Generic message |
| Guests hub | PASS | Generic message |
| Marketplace | PASS | Generic message |
| Vendor detail | PASS | Generic message |
| Rentals | PASS | Generic message |
| Add guest sheet | PASS | `actionFailedMessage` snackbar |
| Import contacts | PASS | `actionFailedMessage` snackbar |
| Request vendor sheet | PASS | Generic message |
| Organizer portal | NOT IN SCOPE | Legacy — redirects only |
| Vendor portal | PARTIAL | Separate audit (Phase 41 vendor cert) |
| Admin portal | PARTIAL | Internal users — Phase 41 |

---

## Phase 43.6 fixes applied

| File | Change |
|------|--------|
| `customer_home_screen.dart` | Skeleton + friendly error |
| `marketplace_screen.dart` | Skeleton + friendly error |
| `customer_my_events_screen.dart` | Friendly error |
| `customer_guests_screen.dart` | Friendly error |
| `marketplace_vendor_detail_screen.dart` | Skeleton + friendly error |
| `marketplace_rentals_screen.dart` | Skeleton + friendly error + snackbar |
| `request_vendor_sheet.dart` | Friendly error + snackbar |
| `add_guest_sheet.dart` | Friendly snackbar |
| `import_contacts_sheet.dart` | Friendly snackbar |

Grep verification: **zero** `error.toString()` / `'$error'` in `mobile/lib/portals/customer`.

---

## Retry behavior

| Flow | Retry mechanism | Status |
|------|-----------------|--------|
| Event modules | Pull-to-refresh + Retry button | PASS |
| Home hub | Try again → `refreshCustomerHome` | PASS |
| Marketplace | Back home / pull refresh | PASS |
| Guest add/import | User re-submits form | PASS |
| Invitations send | Module retry | PASS |

---

## Timeout handling

- HTTP clients use default Dart `http`/`dio` timeouts — **document P2:** explicit 30s connect/read on API client.
- Long operations (invitation batch) — no client timeout override; may appear hung — P1 UX debt.

---

## Offline & recovery (Phase 43.7)

| Scenario | Current behavior | Grade |
|----------|------------------|-------|
| Offline startup | Cached auth may load; API providers error → friendly UI | B |
| API unavailable | Friendly error cards; no crash | A |
| Network reconnect | User pull-to-refresh | B — no auto-retry |
| Image failures | `errorBuilder` gradients on vendor images | A |
| Payment interruption | Commerce flows — verify on staging (Phase 41 C12–C14) | PARTIAL |
| Invitation retry | Resend from module | A |
| Media upload retry | Storage proxy — manual retry | B |
| Token expiration | Supabase refresh; logout on fail | B |
| Expired session | Redirect to login | A |
| Unexpected logout | Auth notifier clears state | A |

### Recommendations

| ID | Item | Priority |
|----|------|----------|
| ERR-1 | `ConnectivityListener` auto-refresh home | P2 |
| ERR-2 | Explicit API timeout + offline message | P1 |
| ERR-3 | Payment resume flow certification | P0 (staging) |

---

## API error filter

`owanbe-exception.filter.ts` maps exceptions to stable JSON — clients should not display `message` field raw in production UI (Customer Portal compliant).

---

## Sign-off

- [x] Customer Portal shell + modules audited
- [x] Raw error leaks remediated
- [ ] Vendor/Admin portal parity (future phase)
