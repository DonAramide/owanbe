# Phase 43.5 — Mock Elimination Final Pass

**Date:** 2026-06-04  
**Flag:** `ALLOW_MOCK_PERSISTENCE_FALLBACK` (`mobile/lib/core/api/persistence_providers.dart`)

---

## Executive summary

Production mobile builds ship with `ALLOW_MOCK_PERSISTENCE_FALLBACK=false`. All mock store paths are gated behind `allowMockPersistenceFallback()`. Customer Event OS uses dedicated `CustomerEventDevStore` (not `OrganizerEventStore`). Organizer compatibility layer retains `OrganizerEventStore` for `/organizer/*` redirects only — **not removed per Phase 43 rules**.

**Production mock execution:** **NONE** when env flag is false.

---

## Inventory

| Symbol | Location | Production path | Gated |
|--------|----------|-----------------|-------|
| `allowMockPersistenceFallback()` | `persistence_providers.dart` | Reads env | N/A |
| `OrganizerEventStore` | `features/organizer/data/` | Organizer portal only | Yes |
| `OperationsStore` | `features/organizer/data/operations_store.dart` | Guest/command fallback | Yes |
| `VendorStore` | `features/vendor/` | Vendor portal fallback | Yes |
| `CustomerEventDevStore` | `customer/data/customer_event_dev_store.dart` | Customer event fallback | Yes |
| `_mockVendors()` | `customer_home_providers.dart` | Marketplace carousel | Yes |
| `ALLOW_MOCK_FINANCE_FALLBACK` | `vendor_providers.dart` | Vendor finance | Separate flag |
| `MockPersistence` | Not found as class name | — | — |
| `DemoStore` | Not found | — | — |
| `ALLOW_MOCK` (API) | `scripts/phase41-certification.js` | `PHASE41_ALLOW_MOCK_QUASER` test only | Test script |

---

## Customer Portal paths

| Provider / file | Mock behavior when flag=false |
|-----------------|-------------------------------|
| `customer_event_providers.dart` | API error propagates |
| `customer_event_persistence.dart` | API error propagates |
| `customer_guest_providers.dart` | API error propagates |
| `customer_guest_persistence.dart` | Throws if API fails |
| `customer_event_command_providers.dart` | Skips OperationsStore |
| `customer_invitation_providers.dart` | Returns null on API miss |
| `customer_home_providers.dart` | Empty vendor list on API fail |
| `customer_event_invitations_screen.dart` | Mock-only UI actions hidden |

### Intentional non-mock fallback

`customerTicketInvitationsProvider` on API failure reads `attendeeTicketsProvider` (local ticket cache) — **not** a mock store; supports offline/cached entitlements. Document as acceptable.

---

## Organizer Portal (compatibility)

- `organizer_providers.dart` / `organizer_persistence.dart` — full mock gate.
- Retained for `/organizer/*` redirects; Customer Portal does not import at runtime (Phase 42.5).

---

## Vendor Portal

- `VendorStore` + `ALLOW_MOCK_FINANCE_FALLBACK` for finance demos.
- Production: both flags false.

---

## API / scripts

- `PHASE41_ALLOW_MOCK_QUASER=true` only for local certification without sandbox.
- No `ALLOW_MOCK` in API runtime.

---

## Production build verification

```text
mobile/assets/env/supabase.env → ALLOW_MOCK_PERSISTENCE_FALLBACK=false
```

Build pipeline must not override to `true` for staging/production flavors.

---

## Development workflow

Developers set `ALLOW_MOCK_PERSISTENCE_FALLBACK=true` in local `.env` overlay for offline UI work. Mock data is explicit and isolated — never compiled into production flavor.

---

## Remaining risk

| Risk | Mitigation |
|------|------------|
| Accidental true in prod env | CI check on env files |
| Ticket invitation local cache stale | Refresh on reconnect |
| Organizer store still in binary | Tree-shake not guaranteed — acceptable per rules |

---

## Sign-off

- [x] All mock paths grep-reviewed
- [x] Production env false
- [x] Customer Portal API-first
- [ ] CI gate: fail build if prod env has mock true (P2)
