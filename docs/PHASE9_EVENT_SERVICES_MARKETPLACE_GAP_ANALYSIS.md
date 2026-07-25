# PHASE 9 — EVENT SERVICES & MARKETPLACE GAP ANALYSIS

**Date:** 2026-07-25  
**Scope:** Attendee Event Services & Marketplace (marketplace home, vendor discovery, F&B, merch, ancillary services, bookings, payments, vendor communication)  
**Method:** Read-only audit of Flutter (`mobile/`) and NestJS (`services/api/`) + DB (`infra/db/`)  
**Constraint:** Audit only — no code changes, no redesign, no fixes  

---

## Executive verdict

| Dimension | Finding |
|-----------|---------|
| **Live QA** | Confirmed — **no dedicated attendee Event Services / Marketplace experience** is visible in the attendee workspace |
| **Attendee product (Phase 9 target)** | **Not implemented** as a guest-facing in-event store |
| **Related platform capability** | **Organizer–vendor marketplace** (browse vendors, CRM hire, rentals, attire) exists and is **partially working** |
| **Overall classification** | **Partially implemented** |

The attendee shell is intentionally isolated from the public/organizer marketplace:

```12:12:mobile/lib/features/public/screens/attendee_dashboard_screen.dart
/// Attendee Workspace — immersive guest experience isolated from the public marketplace.
```

“Marketplace” wording in Attendee Discover refers to **event discovery**, not vendors/services (`attendee_discover_tab.dart`).

**Naming collision:** `infra/db/026_phase9_integrations.sql` is **Production Integrations** (notifications/media), not this product Phase 9. Attendee roadmap Phase 9 was marked **Not started** after Phase 8 networking.

---

## Classification legend

| Label | Meaning |
|-------|---------|
| **Implemented and Working** | End-to-end usable for the intended persona |
| **Implemented but Hidden** | Built but not discoverable in primary UX |
| **Implemented but Not Wired** | Code exists; routes/providers not connected to attendee flows |
| **Backend Complete / Frontend Missing** | API/DB ready; no consumer UI (or wrong persona UI) |
| **Frontend Complete / Backend Missing** | UI present; API synthetic, stubbed, or absent |
| **Partially Implemented** | Meaningful pieces exist; gaps block MVP |
| **Not Implemented** | No meaningful product implementation |

---

## Why Phase 9 is unavailable (Live QA)

| Check | Result |
|-------|--------|
| Attendee routes for services/marketplace | **None** under `AttendeeRoutes` / `attendee_commerce_routes.dart` |
| Links from Event Detail / Live Hub / Discover | **None** to `/vendors`, rentals, merch, F&B, or services |
| Grep `marketplace` / `vendors` under `portals/attendee/` | Only Discover marketing copy |
| Ticket cart/checkout | **Working** — wrong commerce domain (tickets, not services) |

Guests can deep-link to public `/vendors` (organizer discovery), but the **attendee product does not expose or scope** that as event services.

---

## Stack map (shared evidence)

### Flutter — organizer / public marketplace (not attendee Phase 9)

| Asset | Path |
|-------|------|
| Marketplace home | `portals/customer/screens/marketplace_screen.dart` → `/vendors` |
| Vendor detail | `marketplace_vendor_detail_screen.dart` → `/vendors/:vendorId` |
| Rentals browse | `marketplace_rentals_screen.dart` → `/vendors/rentals` |
| Providers | `marketplace_providers.dart`, `marketplace_filters.dart` |
| Models | `marketplace_models.dart` (synthetic ratings/reviews via `buildVendorProfile`) |
| Vendor APIs (client) | `core/api/vendors_api.dart`, `vendor_crm_providers.dart`, `rentals_providers.dart` |
| Event modules | Marketplace, Vendor Pipeline, Rentals, Attire (`event_module_registry.dart`) |
| Vendor B2B portal | `features/vendor/*` — `/vendor`, catalog, CRM, rentals |

### NestJS — organizer–vendor hire + rentals (not attendee store)

| Module | Role |
|--------|------|
| `modules/vendors` | `GET /v1/vendors`, vendor create, packages (vendor-admin) |
| `modules/vendor-operations` | Event vendor requests, stages, counter-quotes, messages, calendar |
| `modules/rentals` | Public catalog + event rental bookings |
| `modules/bookings` | Hire-vendor `bookings` rail — **read/status/pay; no POST create** |
| `modules/commerce` | **Ticket** orders/payments only |
| `events` + `aso-ebi.service` | Event fabric catalogue + reservations (partial pay) |

### Database (marketplace-adjacent)

| Object | Source | Phase 9 relevance |
|--------|--------|-------------------|
| `vendors`, `vendor_packages` | `owanbe_core.sql` | Organizer vendor directory |
| `bookings`, `payments` | core + fintech migrations | Client→vendor hire escrow |
| `vendor_event_requests` | `036_vendor_crm.sql` | Organizer enquiry pipeline |
| `rental_catalog_items`, `rental_bookings` | `032_rentals_equipment.sql` | Equipment rental |
| `event_aso_ebi_*` | `030_aso_ebi.sql` | Event attire products |
| Merch / F&B menu / parking / cart | — | **Absent** |
| Vendor reviews tables | — | **Absent** (`ratingAverage` always null in API) |

---

## 9.1 Event Marketplace

| Feature | Classification | Evidence | Why unavailable to attendees | Effort |
|---------|----------------|----------|------------------------------|--------|
| Event Marketplace | **Partially Implemented** (organizer) / **Not Implemented** (attendee) | `/vendors` + `MarketplaceScreen`; no `/attendee/.../services` | Attendee shell excludes marketplace; no event-scoped guest store | **Large** |
| Marketplace Home | **Implemented and Working** (organizer/public) | `marketplace_screen.dart`, `EventNavigator.openMarketplace` | Not linked from attendee UX | **Medium** to wire attendee-scoped home |
| Browse Services | **Partially Implemented** | Category filters on vendor list (`Photographer`, `Catering`, … in `vendors_api.dart`) | Taxonomy + directory only; not attendee service catalogue | **Medium** |
| Browse Products | **Not Implemented** | No merch/SKU browse API or attendee UI | Only rentals catalog + aso-ebi fabrics + vendor packages (vendor-admin) | **Large** |
| Featured Vendors | **Partially Implemented** / **Frontend Complete / Backend Missing** | UI ordering/filters; no dedicated featured API | Client-side / mock enrichment | **Small** |
| Categories | **Implemented and Working** (organizer) | `GET /v1/event-config/vendor-categories`, `tenant_vendor_categories` | Not exposed in attendee Event OS | **Small** to reuse |
| Search | **Implemented and Working** (organizer) | Marketplace filter bar / query on `/vendors` | Same — wrong persona | **Small** |
| Filters | **Implemented and Working** (organizer) | `marketplace_filters.dart`, `MarketplaceFilterBar` | Same | **Small** |

---

## 9.2 Vendor Discovery

| Feature | Classification | Evidence | Why incomplete | Effort |
|---------|----------------|----------|----------------|--------|
| Vendor Directory | **Implemented and Working** (public/organizer) | `GET /v1/vendors`, `VendorsApi.listCatalog()`, `/vendors` | **Implemented but Not Wired** into attendee | **Medium** (attendee entry + event scope) |
| Vendor Profiles | **Partially Implemented** | `MarketplaceVendorDetailScreen`; API has list but **no** dedicated `GET /vendors/:id` (client scans catalog) | Trust fields synthetic in Flutter | **Medium** |
| Vendor Categories | **Implemented and Working** | Event-config categories + marketplace filters | Not attendee-facing | **Small** |
| Vendor Ratings | **Frontend Complete / Backend Missing** | `buildVendorProfile` / `_seedReviews` in `marketplace_models.dart`; API `ratingAverage`/`reviewCount` **null** | No review tables; design only (`docs/phase40/MARKETPLACE_TRUST_LAYER_DESIGN.md`) | **Large** |
| Vendor Contact | **Partially Implemented** | `VendorContactBar` (Request + copy phone); CRM request sheet | Organizer hire flow, not guest contact | **Medium** |
| Vendor Availability | **Partially Implemented** | `GET/POST …/vendors/:id/calendar`, `037_vendor_calendar.sql` | Vendor calendar for hire; not attendee slot booking UX | **Medium** |

---

## 9.3 Food & Beverage

| Feature | Classification | Evidence | Effort |
|---------|----------------|----------|--------|
| Food Vendors | **Not Implemented** (as F&B vertical) | Catering/drinks appear only as **vendor category slugs** | **Large** |
| Menu | **Not Implemented** | No menu entities/endpoints/screens | **Large** |
| Place Order | **Not Implemented** | No F&B order API; ticket/rental/aso-ebi are different domains | **Large** |
| Pickup | **Not Implemented** | — | **Medium** (after orders) |
| Delivery | **Not Implemented** | — | **Large** |
| Digital Menu | **Not Implemented** | — | **Large** |

---

## 9.4 Merchandise

| Feature | Classification | Evidence | Effort |
|---------|----------------|----------|--------|
| Event Merchandise | **Not Implemented** | No merch schema or attendee merch routes | **Large** |
| Product Catalogue | **Not Implemented** (attendee merch) | Closest: `vendor/packages` (vendor-admin), rentals catalog, aso-ebi fabrics | **Large** |
| Product Detail | **Not Implemented** | — | **Medium** |
| Add to Cart | **Not Implemented** | `cartProvider` is **ticket tiers only** (`public_providers.dart`) | **Large** |
| Purchase | **Not Implemented** | Marketplace has no product checkout | **Large** |
| Digital Receipts | **Not Implemented** (marketplace) | Ticket order receipts exist in ticket commerce — wrong domain | **Medium** (after orders) |

**Near-miss:** Aso-Ebi (`/events/:id/attire`, `GET/POST …/aso-ebi/*`) is event-scoped guest-capable attire commerce — **Partially Implemented**, **Implemented but Not Wired** from attendee event detail.

---

## 9.5 Event Services

| Feature | Classification | Evidence | Effort |
|---------|----------------|----------|--------|
| Parking | **Not Implemented** | No API/UI/DB | **Large** |
| Transport | **Not Implemented** | Budget/wizard labels only | **Large** |
| Accommodation | **Not Implemented** | Website JSON flag `accommodation` in `028_event_website.sql` — display flag, not booking | **Large** |
| Equipment Rental | **Partially Implemented** | Nest `rentals` module + Flutter `/vendors/rentals`, `/events/:id/rentals`; **no PSP** on rentals | **Medium** to attendee-wire; **Large** with payments |
| Photography | **Not Implemented** as bookable service | Category `photographer` + CRM hire only | **Medium** (reuse CRM) / **Large** (guest checkout) |
| Printing | **Not Implemented** | Vendor rental “print label” snackbar only | **Large** |
| Concierge | **Not Implemented** | Marketing/seed copy only | **Large** |
| Other Event Services | **Partially Implemented** | Organizer CRM request to any category vendor | **Medium** (expose read-only directory) |

---

## 9.6 Bookings

| Feature | Classification | Evidence | Effort |
|---------|----------------|----------|--------|
| Book Service | **Partially Implemented** | CRM `POST /events/:eventId/vendor-requests` (organizer); rentals `POST …/rentals/bookings`; **no** `POST /bookings` for package hire | **Large** for attendee service book |
| Reserve Slot | **Partially Implemented** | Vendor calendar blocks; rental availability endpoint | **Medium** |
| Booking History | **Partially Implemented** | `GET /v1/bookings`, rental lists, aso-ebi reservations — **not** attendee marketplace history UI | **Medium** |
| Booking Status | **Partially Implemented** | Booking status PATCH (vendor); rental approve/decline workflow | **Small**–**Medium** |
| Booking Confirmation | **Partially Implemented** | CRM stages + notifications; rental workflow | **Medium** |
| Booking Cancellation | **Partially Implemented** | Booking cancel status; aso-ebi cancel; rental decline | **Small** |

**Critical gap:** Nest `bookings` controller exposes **GET / PATCH status / payments** only — create path missing in `services/api/src` (inserts appear in tests only).

---

## 9.7 Payments

| Feature | Classification | Evidence | Effort |
|---------|----------------|----------|--------|
| Marketplace Checkout | **Not Implemented** | No multi-vendor cart/checkout for services/merch | **Large** |
| Payment Integration | **Partially Implemented** | Quaser on **ticket** rail + **booking** payments (`POST /bookings/:id/payments`); rentals/aso-ebi pay **stubbed/absent** in prod | **Large** to unify |
| Wallet Support | **Partially Implemented** (vendor) | Vendor finance balance/payout; not attendee marketplace wallet | **Large** |
| Order History | **Implemented and Working** (tickets) / **Not Implemented** (marketplace) | `GET /me/ticket-orders`, attendee orders screens | **Medium** for services history |
| Receipts | **Partially Implemented** (tickets) | Ticket order detail; no marketplace receipts | **Medium** |
| Refund Support | **Partially Implemented** (tickets/disputes) | Ticket refunds + booking disputes; not merch/F&B | **Large** |

---

## 9.8 Vendor Communication

| Feature | Classification | Evidence | Effort |
|---------|----------------|----------|--------|
| Contact Vendor | **Partially Implemented** | Phone copy + CRM request (`RequestVendorSheet`) | **Medium** |
| Vendor Chat | **Partially Implemented** | CRM `POST …/vendor-requests/:id/messages` (organizer↔vendor); **no** attendee chat; `chat_threads` unused by Nest | **Large** for guest chat |
| Vendor Enquiry | **Implemented and Working** (organizer) | `POST /events/:eventId/vendor-requests` | **Medium** to add attendee enquiry (policy change) |
| Request Quote | **Partially Implemented** | CRM counter + AI negotiations (`044_ai_negotiation_engine.sql`); platform `MarketplaceService.requestQuote` stub returns success | **Medium** |

---

## 9.9 Technical Quality

| Concern | Classification | Evidence | Effort |
|---------|----------------|----------|--------|
| Loading States | **Implemented and Working** (organizer marketplace) | Async providers + skeletons on customer marketplace screens | **Small** to reuse patterns |
| Error States | **Partially Implemented** | API failures often fall back to **mock vendors** (`allowMockPersistenceFallback`) — can hide real outages | **Medium** |
| Empty States | **Implemented and Working** (organizer modules) | Pipeline/rentals empty states | **Small** |
| Offline Behaviour | **Partially Implemented** | Attendee ticket flows have offline banners; marketplace/services lack attendee offline story | **Medium** |
| Responsive Layout | **Implemented and Working** (EOS customer/vendor) | Marketplace uses EOS surfaces | **Small** |
| Performance | **Partially Implemented** | Full catalog scan for vendor detail; synthetic review generation client-side | **Medium** |

**Attendee Phase 9 UX quality:** **Not Implemented** (no screens to evaluate).

---

## Persona boundary (critical)

| Persona | What exists today | Phase 9 target |
|---------|-------------------|----------------|
| **Attendee** | Tickets, passes, live, networking, event discover | In-event services & marketplace |
| **Organizer / Customer Event OS** | Vendor marketplace, CRM hire, rentals, attire | Out of scope for attendee Phase 9 completion (reuse allowed) |
| **Vendor** | Catalog, CRM inbox, rental fulfillment, finance | Supply side — not guest storefront |

Reusing organizer marketplace **as-is** for attendees would expose **planning/hire** flows (wrong jobs-to-be-done) unless scoped and productized as guest services.

---

## Effort summary (attendee Phase 9 lens)

| Area | Dominant effort |
|------|-----------------|
| 9.1 Marketplace (guest) | **Large** |
| 9.2 Vendor discovery (wire + trust) | **Medium**–**Large** |
| 9.3 F&B | **Large** |
| 9.4 Merchandise | **Large** |
| 9.5 Ancillary services | **Large** (except rentals reuse **Medium**) |
| 9.6 Bookings (guest) | **Large** |
| 9.7 Marketplace payments | **Large** |
| 9.8 Vendor communication (guest) | **Medium**–**Large** |
| 9.9 Technical quality | **Medium** (once screens exist) |

---

## Prioritized implementation roadmap (single Phase 9 completion sprint)

Goal: **minimum viable attendee Event Services** — discover and engage event-linked vendors/services — **without** building a full multi-vertical commerce OS in one sprint.

### P0 — Attendee Services Hub (must ship)

1. **Event Services entry** from Event Detail / Live Hub → `/attendee/event/:eventId/services`  
   - Surface **event-scoped or publicly listed vendors** relevant to the event (start: reuse `GET /vendors` + categories; prefer organizers’ linked vendors if CRM links exist)  
   - **Effort: Medium**
2. **Browse + search + category filters** (reuse marketplace filter UX patterns inside attendee shell)  
   - **Effort: Medium**
3. **Vendor profile (read-only)** for attendees — photo, bio, category, contact policy; **no synthetic reviews** unless backend exists  
   - **Effort: Medium** (add `GET /vendors/:id` if needed)

### P1 — One bookable vertical (choose ONE)

Pick the strongest backend reuse:

| Option | Why | Effort |
|--------|-----|--------|
| **A. Equipment rental (recommended)** | Public catalog + `POST …/rentals/bookings` already exist | **Medium** |
| **B. Aso-Ebi / event products** | Event-scoped catalogue + reservations exist; wire from attendee | **Medium** |
| **C. Vendor enquiry only** | Thin `enquiry` to organizer-approved vendors (no cart) | **Medium** |

**Do not** attempt F&B menus + merch cart + parking + concierge in the same sprint.

### P2 — Thin commerce closure for the chosen vertical

4. **Booking status + history** for that vertical in attendee Orders/Activity  
   - **Effort: Medium**
5. **Payment** only if the vertical already has a payment path; otherwise status = “requested / pay at venue” and document **PARTIAL**  
   - Rentals/aso-ebi currently weak on PSP → **Large** if full pay required

### P3 — Explicitly defer (Phase 9B+)

6. Food menus, pickup/delivery  
7. General merchandise cart + multi-vendor checkout  
8. Parking / transport / accommodation / printing / concierge  
9. Real ratings/reviews persistence  
10. Attendee↔vendor free chat / quote negotiation (keep organizer CRM)

### Suggested COMPLETE definition (sprint)

Phase 9 **COMPLETE** when a ticketed attendee can:

1. Open **Event Services** for their event  
2. **Browse / search** vendors or services available for that event  
3. Open a **vendor/service profile**  
4. Complete **one** action: **request/book** the chosen P1 vertical (rental **or** attire reservation **or** enquiry)  
5. See **status/history** for that action  

Full marketplace checkout, F&B, merch, and ancillary verticals may remain **PARTIAL / deferred** if called out in the completion report.

---

## Final determination

| Verdict | **Partially implemented** |
|---------|---------------------------|
| Attendee Event Services & Marketplace product | **Not implemented** (Live QA correct) |
| Organizer–vendor marketplace / CRM / rentals / attire | **Partially implemented / working** for planning persona |
| Backend-only gaps for guest store | Merch, F&B, cart, reviews, `POST /bookings`, rental/aso-ebi production pay |
| Frontend-only gaps | Synthetic ratings; mock marketplace fallbacks; attendee routes absent |
| Strongest reuse for completion sprint | Public vendor list + categories; rentals module; aso-ebi reservations; CRM enquiry patterns |
| Next step | Implementation sprint per P0–P2 roadmap above |

**STOP — audit only. No implementation performed. Do not begin Phase 9 build until explicitly requested.**
