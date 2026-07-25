# PHASE 9 — ATTENDEE EVENT SERVICES HUB COMPLETION REPORT

**Date:** 2026-07-25  
**Scope:** Attendee Event Services Hub, event-scoped vendor directory, Rentals MVP, bookings history/status, service notifications  
**Out of scope:** Global marketplace, F&B, merch cart, vendor chat, ratings, quotes, parking/transport/accommodation/printing/photography/concierge, organizer/vendor portal redesign  
**Method:** Reuse rentals + vendor attachment (`vendor_event_requests` / `vendor_event_participations`) + in-app `notifications`

---

## Verdict

**Phase 9 is COMPLETE** for the Attendee Event Services Hub defined in this sprint.

Ticketed attendees can open Services, pick an event, browse vendors attached to that event, book equipment rentals from those vendors, cancel pending requests, track booking status, and receive in-app service notifications — without building a global ecommerce marketplace.

---

## Certification checklist

| Item | Result | Evidence |
|------|--------|----------|
| Services Hub | **PASS** | `/attendee/services` — upcoming events, my bookings snapshot, notifications entry; event hub at `/attendee/event/:eventId/services` |
| Service Directory | **PASS** | Event-attached vendors only; logo, name, category, description, availability; search + category filter; Book / View details |
| Rentals MVP | **PASS** | `/attendee/event/:eventId/services/rentals` — browse items from attached vendors, book, cancel pending, status + confirmation |
| Booking Flow | **PASS** | `POST events/:eventId/services/rentals/bookings` (ticket + vendor-on-event gated) |
| Booking History | **PASS** | `/attendee/services/bookings` — Upcoming / Active / Completed / Cancelled |
| Booking Status | **PASS** | Mapped: Pending, Confirmed, Ready, Completed, Cancelled, Expired (+ In progress reserved) |
| Notifications | **PASS** | Confirmed / updated / cancelled / completed via `notifications`; inbox at `/attendee/services/notifications` |
| Technical Quality | **PASS** | Skeletons, error/retry, offline banners, pull-to-refresh, EOS layout, 2‑minute hub keepAlive |

---

## Routes & entry points

| Route | Screen |
|-------|--------|
| `/attendee/services` | `AttendeeServicesHomeScreen` |
| `/attendee/event/:eventId/services` | `AttendeeEventServicesHubScreen` |
| `/attendee/event/:eventId/services/rentals` | `AttendeeEventRentalsScreen` |
| `/attendee/services/bookings` | `AttendeeServiceBookingsScreen` |
| `/attendee/services/notifications` | `AttendeeServiceNotificationsScreen` |

**Wired from:** Dashboard command centre (**Services**), Event Detail, Live Hub.

---

## Backend

| Change | File |
|--------|------|
| Attendee event services service | `attendee-event-services.service.ts` |
| Hub / vendors / rentals / book / cancel / notifications | `rentals.controller.ts` |
| Vendor status → attendee notify | approve / counter / decline / deliver / return hooks |
| Module registration | `rentals.module.ts` |

### API surface

- `GET events/:eventId/services`
- `GET events/:eventId/services/vendors`
- `GET events/:eventId/services/rentals`
- `POST events/:eventId/services/rentals/bookings`
- `GET me/service-bookings`
- `POST me/service-bookings/:bookingId/cancel`
- `GET me/service-notifications`

**Event scope:** Vendors must appear in `vendor_event_participations` or `vendor_event_requests` for the event. Rentals catalog is filtered to those vendor IDs. Attendee must hold an issued/checked-in ticket.

---

## Flutter key files

| Path | Role |
|------|------|
| `event_services_api.dart` | HTTP client + models |
| `attendee_event_services_providers.dart` | Riverpod + cache |
| `attendee_services_home_screen.dart` | Global hub + event directory |
| `attendee_event_rentals_screen.dart` | Rentals MVP + bookings + notifications UI |
| `attendee_routes.dart` / `attendee_commerce_routes.dart` | Routing |
| Reused | `rentals_models.dart`, rental booking table, vendor attachment tables |

---

## Status mapping

| Rental status | Attendee service status |
|---------------|-------------------------|
| `pending` / `countered` | Pending |
| `approved` | Confirmed |
| `delivered` | Ready |
| `returned` | Completed |
| `declined` / `cancelled` | Cancelled |
| Pending/confirmed past event end | Expired |

Confirmation number: `OB-` + first 8 hex chars of booking id.

---

## Explicitly not built

- Food ordering, merch store, shopping cart, marketplace checkout  
- Vendor chat, ratings, request quote  
- Parking, transport, accommodation, printing, photography, concierge  
- Global (non–event-scoped) marketplace  

---

## Regression

| Area | Status |
|------|--------|
| Auth / Discover / Tickets / Passes / Networking / Live | Additive CTAs and routes only |
| Organizer marketplace / Vendor portal | Untouched UX; rental vendor actions now also notify attendees |

---

## Known partials (acceptable)

| Item | Note |
|------|------|
| Empty directory when no vendors attached | By design — organizers must attach vendors |
| Rental payment / PSP | Deferred; request + vendor confirmation workflow only |
| “In progress” status | Schema maps delivered→Ready; in_progress reserved for future verticals |
| Global `/vendors` marketplace | Intentionally not linked from attendee shell |

These do **not** block Phase 9 certification for the scoped Attendee Event Services Hub.

---

## Phase gate

| Phase | Status |
|-------|--------|
| Phase 9 Attendee Event Services Hub | **COMPLETE** |
| Phase 10 | **Not started** |

**STOP — do not begin Phase 10.**
