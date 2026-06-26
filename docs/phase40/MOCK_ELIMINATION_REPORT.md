# Phase 40 — Mock Elimination Report

**Date:** 4 June 2026  
**Flag:** `ALLOW_MOCK_PERSISTENCE_FALLBACK=false` (production default in `mobile/assets/env/supabase.env`)

---

## Summary

| Category | Mock write paths | API-backed | Blocker for public beta |
|----------|------------------|------------|------------------------|
| Customer guests & invitations | 0 (prod) | Yes | No |
| Event create (customer wizard) | 0 (prod) | Yes | No |
| Organizer publish / tiers / vendors | Fallback only | Partial | **Yes** |
| Vendor catalog & orders | 0 (prod) | Yes | No |
| Operations check-in / incidents | Fallback only | Partial | Medium |
| Public event catalog reads | Fallback only | Yes (API first) | Low |
| Marketplace vendors list | Fallback only | Yes (API first) | Low |

**Production rule:** When `ALLOW_MOCK_PERSISTENCE_FALLBACK=false`, all guarded paths throw or skip mocks. Unguarded paths below are **hard blockers**.

---

## Remaining mock write paths

### Critical — unconditional (no flag guard)

| File | Write | Replacement API | Status |
|------|-------|-----------------|--------|
| *(none)* | — | — | **P40.1/P40.2 closed** — vendor writes API-first; mock only when `ALLOW_MOCK_PERSISTENCE_FALLBACK=true` |

### High — fallback writes when API fails (guarded by flag)

| File | Mock store | Primary API | Removal plan |
|------|------------|-------------|--------------|
| `organizer_persistence.dart` | `OrganizerEventStore` create/publish/goLive/tiers/vendors | `EventsApi` create/patch/publish/tiers | P40.3 — remove catch fallbacks; surface API errors in UI |
| `vendor_persistence.dart` | `VendorStore` apply/accept participation | `VendorEventsApi` | P40.4 — already API-first; delete mock catch blocks |
| `customer_guest_persistence.dart` | `OperationsStore` add/import guests | `EventGuestsApi` | **Done** — API first; mock only if flag true |
| `operations_providers.dart` | `OperationsStore` check-in, incidents, scan | `OperationsApi` | P40.5 — incident status update still mock-only in `incident_center_screen.dart` |

### Medium — read fallbacks (no production writes)

| File | Store | API | Notes |
|------|-------|-----|-------|
| `customer_home_providers.dart` | `OrganizerEventStore.all`, `_mockVendors()` | `EventsApi`, `VendorsApi` | Throws when mocks off |
| `organizer_providers.dart` | `OrganizerEventStore` | `EventsApi` list/get | Throws when mocks off |
| `vendor_providers.dart` | `VendorStore` participations | `VendorEventsApi` | Finance uses separate `ALLOW_MOCK_FINANCE_FALLBACK` |
| `public_event_catalog.dart` | `OrganizerEventStore` | Unused when mocks off | Legacy; delete after public API-only path verified |
| `attendee_events_provider.dart` | `OrganizerEventStore.publishedForPublic` | Should use public events API | P40.6 |
| `customer_event_command_providers.dart` | `OperationsStore` guests/feed | `OperationsApi` | Read fallback when flag true |

### Frozen — intentionally mock-gated

| Feature | File | Status |
|---------|------|--------|
| Contact import | `customer_guest_persistence.dart`, invitations UI | Hidden when mocks off — **do not enable for beta** |

---

## Replacement API map

| Domain | Endpoints | Flutter client |
|--------|-----------|----------------|
| Guests | `GET/POST /events/:id/guests`, `POST .../guests/bulk` | `EventGuestsApi` |
| Invitations | `GET .../invitations`, `POST .../invitations/send` | `EventGuestsApi` |
| RSVP | `GET /invitations/validate`, `POST /invitations/rsvp` | Public + token |
| Events | `POST/PATCH /events`, publish, tiers | `EventsApi` |
| Check-ins | `GET/POST /events/:id/check-ins` | `OperationsApi` |
| Vendor onboarding | `POST/PUT .../onboarding/...` | `OnboardingApi` |
| Vendor events | Vendor participation routes | `VendorEventsApi` |
| Vendor bookings | `PATCH /v1/bookings/:id/status` | `VendorBookingsApi` |
| Vendor catalog | `GET/POST/PATCH /v1/vendor/packages` | `VendorCatalogApi` |
| Marketplace | `GET /vendors` | `VendorsApi` |
| Payments | Quaser initiate + webhook capture | Commerce module |
| Media | `POST /media/presign`, `PUT /media/upload/:key` | API proxy |

---

## Removal plan (sprint order)

1. **P40.1–P40.2** — Fix unconditional vendor writes — **Done**.
2. **P40.3** — Remove organizer persistence fallbacks; hard-fail UI on API errors (2 days).
3. **P40.5** — Wire incident status to `OperationsApi` patch endpoint (1 day).
4. **P40.6** — Point attendee/public catalogs exclusively at `GET /events` (0.5 day).
5. **P40.7** — Delete `public_event_catalog.dart` OrganizerEventStore reads after soak (0.5 day).
6. **P40.8** — Remove mock store classes from release build (optional tree-shake / dev-only flag).

---

## Verification checklist

```bash
# No unconditional store writes in production paths
rg "VendorStore\.instance\.(update|toggle|add)" mobile/lib --glob "*.dart"
rg "OrganizerEventStore\.instance\.(create|publish|setLive)" mobile/lib --glob "*.dart"

# Confirm production flag
grep ALLOW_MOCK mobile/assets/env/supabase.env
```

Expected for beta: **P40.1–P40.2 resolved**; organizer fallbacks acceptable for staging if API uptime ≥ 99%.
