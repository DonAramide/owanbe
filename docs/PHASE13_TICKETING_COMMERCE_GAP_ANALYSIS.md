# PHASE 13 — TICKETING & COMMERCE GAP ANALYSIS

**Date:** 2026-07-28  
**Scope:** Organizer Ticketing & Commerce — from **decide to sell access** through **tickets ready for purchase** (plus purchase-path readiness)  
**Method:** Read-only audit of Flutter (`mobile/`) and NestJS (`services/api/`) + DB (`infra/db/`)  
**Constraint:** Audit only — no code changes, no redesign, no fixes  

---

## Executive verdict

| Dimension | Finding |
|-----------|---------|
| **Sell path** | Organizer can create/edit tiers via `TicketsTabV3` / `TicketManagementScreen` / Wizard V2 Tickets step → `POST/PATCH` tiers |
| **Buy path** | Public + attendee select → checkout → order → payment → entitlements (Phase 5 rail) |
| **Product depth** | Strong on CRUD-lite, capacity, pause, paid NGN pricing, platform fee bps; weak on windows enforcement, promo/tax, archive/duplicate/reorder, purchase rules, holds |
| **Overall classification** | **Partially Implemented** |

Organizers can put tickets on sale and buyers can purchase. Commerce **product completeness** (rules, promos, inventory holds, sales-by-tier reporting, delete UX) is incomplete.

---

## Classification legend

| Label | Meaning |
|-------|---------|
| **Implemented and Working** | End-to-end usable on live sell / buy path |
| **Implemented but Hidden** | Built; not reachable via current routing |
| **Implemented but Not Wired** | UI or API/provider exists; not connected |
| **Backend Complete / Frontend Missing** | API/DB ready; insufficient organizer UX |
| **Frontend Complete / Backend Missing** | UI present; API stubbed/unenforced/absent |
| **Partially Implemented** | Meaningful pieces; gaps block Phase 13 completeness |
| **Not Implemented** | No meaningful product implementation |

---

## Architecture map (reuse)

### Flutter

| Asset | Path | Role |
|-------|------|------|
| Per-event tickets | `command_center_v3/tabs/tickets_tab_v3.dart` | Primary manage UI (`/events/:id/tickets/manage`) |
| Organizer Tickets tab | `screens/ticket_management_screen.dart` | Phase 11 EOS shell `/organizer` |
| Tier editor | `widgets/organizer_ticket_tier_editor.dart` | Create/edit sheet |
| Wizard tickets | `wizard_v2/event_create_wizard_v2_screen.dart` | Lightweight public-event seed |
| Readiness | `event_creation_readiness_panel.dart` | Post-create “Create tickets” CTA (Phase 12) |
| Persistence | `organizer_persistence.dart` | `addTicketTier` / `updateTicketTier` / draft sync |
| Events API | `core/api/events_api.dart` | `createTier` / `patchTier` / **`deleteTier` unwired in UI** |
| Commerce API | `core/api/ticket_commerce_api.dart` | Orders + payments |
| Checkout | `TicketCheckoutCoordinator`, public/attendee ticket select + checkout screens | Purchase path |
| Routes | `app_router.dart` | `/events/:id/tickets`, `/tickets/manage`, `/checkout`, attendee mirrors |

### Nest / DB

| Asset | Path | Role |
|-------|------|------|
| Tier CRUD | `event-tiers.service.ts` + `events.controller.ts` | Create / patch / delete / manage list |
| Event sync | `events.service.ts` `insertTier` / `syncDraftTiers` | Wizard draft + PATCH |
| Orders | `ticket-orders.service.ts` | Create order, lock inventory, fees |
| Payments / capture | `ticket-payments.service.ts`, `ticket-capture.service.ts` | Quaser + capture |
| Entitlements | `ticket-entitlements.service.ts` | Issued passes |
| Finance | `organizer-finance` + dashboard KPIs | Revenue aggregates |
| Schema | `016_phase5_ticket_commerce_foundation.sql`, `020_phase5_ticket_tiers_and_capture.sql` | Orders, tiers, entitlements, fee bps |
| **Promo / coupon tables** | — | **None** |

### Key endpoints

| Method | Path |
|--------|------|
| GET | `/events/:eventId/tiers` (public), `/tiers/manage` (organizer) |
| POST | `/events/:eventId/tiers` |
| PATCH | `/tiers/:tierId` |
| DELETE | `/tiers/:tierId` |
| POST | `/events/:eventId/ticket-orders` |
| POST | `/ticket-orders/:orderId/payments` |
| GET | `/organizers/me/dashboard`, `/events/:eventId/finance/summary` |

---

## 13.1 Ticket Management

| Feature | Classification | Evidence |
|---------|----------------|----------|
| Create Ticket | **Implemented and Working** | Editor + `POST /events/:id/tiers`; CTAs on TicketsTabV3, TicketManagementScreen, Wizard V2 |
| Edit Ticket | **Implemented and Working** | Same editor + `PATCH /tiers/:id` |
| Delete Ticket | **Backend Complete / Frontend Missing** | `DELETE /tiers/:id` blocks if sold (`TIER_HAS_SALES`); `EventsApi.deleteTier` / repo exist — **no screen calls them** |
| Archive Ticket | **Not Implemented** | No archive status; only `sales_paused` or hard delete |
| Duplicate Ticket | **Not Implemented** | Event duplicate copies tiers into wizard; no per-tier duplicate |
| Ticket ordering | **Not Implemented** | No `sort_order`; list `ORDER BY price_minor ASC` |
| Ticket status | **Partially Implemented** | `sales_paused` + UI chips (`on_sale` / `paused` / `sold_out`); no draft/live/archived workflow |
| Draft tickets | **Not Implemented** | Event drafts exist; tiers are live rows once written |

---

## 13.2 Ticket Tiers

| Feature | Classification | Evidence |
|---------|----------------|----------|
| General Admission | **Implemented and Working** | `tier_type` / Flutter `regular` |
| VIP | **Implemented and Working** | `vip` / `vvip` enum + API text |
| Early Bird | **Partially Implemented** | Label/type only — **no auto pricing or window rules** |
| Group Tickets | **Partially Implemented** | Label only — **no group-size pricing** |
| Complimentary | **Not Implemented** | No complimentary type or free-fulfill path |
| Custom tiers | **Partially Implemented** | Free-text `tier_type` accepted; no enum validation |
| Unlimited quantity | **Not Implemented** | `capacity` required; `0` behaves as sold out, not unlimited |
| Limited quantity | **Implemented and Working** | `capacity` + `remaining` + CHECK |

---

## 13.3 Pricing

| Feature | Classification | Evidence |
|---------|----------------|----------|
| Free tickets | **Partially Implemented** | `price_minor = 0` allowed; no Free toggle; still payment-shaped order flow |
| Paid tickets | **Implemented and Working** | Price → `priceMinor`; order lines |
| Currency | **Partially Implemented** | CHAR(3) + mismatch check; editor hardcodes **NGN** |
| Price validation | **Partially Implemented** | `>= 0`; no floor/ceiling product rules |
| Tax support | **Not Implemented** | No tax on tiers/orders (profile tax IDs only) |
| Service fees | **Backend Complete / Frontend Missing** | `ticket_platform_fee_bps` applied at order create; shown on attendee order detail — **not** checkout preview / organizer fee UI |
| Discounts | **Not Implemented** | No line/order discount fields |
| Promo codes | **Not Implemented** | No schema, DTO, or UI |

---

## 13.4 Sales Windows

| Feature | Classification | Evidence |
|---------|----------------|----------|
| Sales start | **Partially Implemented** | Stored in tier `metadata.salesStartAt`; editor date pickers |
| Sales end | **Partially Implemented** | `metadata.salesEndAt` |
| Scheduled sales | **Frontend Complete / Backend Missing** | UI configures windows; **order create does not read them** |
| Automatic close | **Not Implemented** | No job/trigger to pause at `salesEndAt` |
| Sold out | **Implemented and Working** | `remaining == 0` → `INSUFFICIENT_INVENTORY`; UI labels |
| Hidden tickets | **Partially Implemented** | `metadata.visibility`; Flutter public map filters hidden; **API returns all**; **checkout does not reject hidden** |

---

## 13.5 Inventory

| Feature | Classification | Evidence |
|---------|----------------|----------|
| Capacity | **Implemented and Working** | Column + editor |
| Remaining inventory | **Implemented and Working** | Decremented at order under `FOR UPDATE` |
| Reserved inventory | **Not Implemented** | No reservation/hold table |
| Hold inventory | **Not Implemented** | Immediate decrement at order (pre-payment) |
| Oversell protection | **Partially Implemented** | Row lock prevents concurrent oversell; **no restore on abandoned/failed payment or refund** |

---

## 13.6 Purchase Rules

| Feature | Classification | Evidence |
|---------|----------------|----------|
| Minimum quantity | **Partially Implemented** | DTO `@Min(1)` only — not per-tier configurable |
| Maximum quantity | **Not Implemented** | Client caps at `remaining` only |
| Per-user limits | **Not Implemented** | No buyer/tier purchase caps |
| Invite-only tickets | **Partially Implemented** | Event `listingVisibility` / access mode; **order create checks published/live only**, not invite eligibility |
| Eligibility rules | **Not Implemented** | No age/membership gates at checkout |

---

## 13.7 Checkout Readiness

| Feature | Classification | Evidence |
|---------|----------------|----------|
| Public availability | **Partially Implemented** | Public tier endpoints; client filters paused/hidden; server list raw |
| Purchase validation | **Partially Implemented** | Pause + inventory + currency; missing window / hidden / eligibility |
| Checkout integration | **Implemented and Working** | Dual public/attendee paths; `TicketCheckoutCoordinator`; payments + entitlements |
| Ticket visibility | **Partially Implemented** | Client-side hidden filter; not server-enforced |
| Purchase eligibility | **Partially Implemented** | Event must be saleable; invite/access not gated on order |

---

## 13.8 Reporting

| Feature | Classification | Evidence |
|---------|----------------|----------|
| Ticket counts | **Implemented and Working** | Dashboard `ticketsSold`; tier sold = capacity − remaining |
| Revenue summary | **Implemented and Working** | Dashboard + `GET events/:id/finance/summary` |
| Sales by tier | **Not Implemented** | No per-tier sales breakdown API (line data exists in `ticket_order_lines`) |
| Sold out indicators | **Implemented and Working** | UI chips / labels on manage screens |
| Inventory status | **Partially Implemented** | Capacity/remaining on list; no ledger / hold report |

---

## 13.9 Technical Quality

| Feature | Classification | Evidence |
|---------|----------------|----------|
| Validation | **Partially Implemented** | Capacity/sales/pause checks; thin price/window rules |
| Loading states | **Implemented and Working** | `AsyncValue.when` + spinners on manage/select |
| Error handling | **Partially Implemented** | Manage Retry card; checkout banners; inconsistent codes UX |
| Empty states | **Implemented and Working** | “No tickets yet” + Create CTA |
| Offline behaviour | **Not Implemented** | No dedicated ticket offline mode |
| Performance | **Partially Implemented** | Fine for small tier sets; no pagination on manage |

---

## 13.10 Architecture review

| Layer | Status | Notes |
|-------|--------|-------|
| Routes | Working | Manage + select + checkout wired; delete unused |
| Screens / widgets | Working | Dual organizer UIs share editor (Phase 11/12 reuse) |
| Controllers / services | Working | Clear tiers vs commerce split |
| DTOs / entities | Thin | Free-text types; windows in JSON metadata |
| Repositories | Working | Flutter `IEventsRepository.deleteTier` unused by UI |
| DB schema | Solid foundation | Phase 5 tables; **no promo/hold/sort_order** |
| Business rules | Incomplete | Pause + remaining enforced; windows/hidden/invite not |

**Technical debt**

1. Sales windows & hidden stored but **not enforced** server-side → purchasable outside organizer rules.  
2. Inventory held at order create with **no release** on abandon/fail/refund.  
3. `deleteTier` client **Implemented but Not Wired**.  
4. Tier types are **labels**, not rule engines (early bird / group / complimentary / unlimited).  
5. Dual organizer surfaces (`TicketsTabV3` vs `TicketManagementScreen`) — intentional Phase 11 reuse, not debt unless they diverge.  
6. Free tickets still require payment-shaped flow.  
7. No sales-by-tier reporting despite line-level data.

---

## Existing capabilities (keep / reuse)

- Tier create / edit with type, price, capacity, pause, sales window fields, visibility  
- Wizard V2 ticket seed + Phase 12 publish gate (`TICKETS_REQUIRED`) + readiness CTA  
- Public & attendee purchase → order → payment → entitlement  
- Platform fee bps + organizer finance summary + dashboard ticket KPIs  
- Concurrent inventory decrement (`FOR UPDATE`)  
- Soft delete-if-unsold API already present — wire UI only  

---

## Missing capabilities (Phase 13 blockers for “production-ready commerce”)

| Priority | Gap |
|----------|-----|
| P0 | Enforce sales windows + hidden visibility on public list **and** order create |
| P0 | Wire Delete (and optional Archive via pause+status) in manage UI |
| P0 | Inventory release on abandoned / failed / cancelled orders (or true holds) |
| P1 | Per-tier min/max quantity + checkout enforcement |
| P1 | Checkout fee preview; free-ticket short-circuit |
| P1 | Sales-by-tier reporting endpoint + manage UI |
| P2 | Promo codes / discounts |
| P2 | Tax lines |
| P2 | Duplicate tier, reorder (`sort_order`), unlimited capacity |
| P2 | Complimentary issuance path |
| P2 | Invite-only purchase gate |

---

## Reuse opportunities

| Existing | Reuse for |
|----------|-----------|
| `organizer_ticket_tier_editor.dart` | Delete confirm, min/max fields, Free toggle |
| `TicketsTabV3` / `TicketManagementScreen` | Single delete/reorder actions |
| `metadata.salesStartAt/EndAt` / `visibility` | Server enforcement — **no schema change required for MVP** |
| `ticket_order_lines` | Sales-by-tier report SQL |
| `ticket_platform_fee_bps` | Checkout fee preview |
| Phase 12 readiness panel | Ticket completeness messaging |
| `DELETE /tiers/:id` | Wire FE only |

---

## Estimated implementation effort

| Workstream | Effort | Notes |
|------------|--------|-------|
| Wire delete + confirm UX | **S** | API exists |
| Server enforce windows + hidden | **M** | Order + public list filters |
| Inventory release / expire pending orders | **M–L** | Job or payment webhook path |
| Min/max qty + Free toggle + fee preview | **M** | FE + DTO + order validation |
| Sales-by-tier report | **S–M** | Aggregate query + UI table |
| Promo codes | **L** | New schema + apply at order |
| Tax | **L** | Policy + line calculation |
| Archive / reorder / duplicate / unlimited | **M** | Schema + UI |
| Complimentary path | **M** | Zero-price fulfill without Quaser |

**S** = days · **M** = ~1 week · **L** = multi-week

---

## Final classification

### ✓ Partially Implemented

Foundation (Phase 5 rail + organizer manage + checkout) is real and sellable. Product completeness for production Ticketing & Commerce — especially **rule enforcement**, **inventory lifecycle**, **delete UX**, **promos/tax**, and **sales-by-tier** — is incomplete.

---

## Phase 13 Completion Sprint — prioritized roadmap

Single sprint goal: **Tickets are correctly managed, correctly gated for sale, and accurately inventoried through purchase** — without building Marketing/Finance OS or full promo platform.

### P0 (must ship)

1. **Wire Delete** in `TicketsTabV3` + `TicketManagementScreen` (respect `TIER_HAS_SALES`).  
2. **Enforce sales windows** on `POST .../ticket-orders` and public `GET .../tiers`.  
3. **Enforce hidden** tiers on public list + reject at order create.  
4. **Inventory release** for expired/cancelled/abandoned `pending_payment` orders (restore `remaining`).  
5. Regression: Wizard seed, publish gate, checkout happy path, pause, sold out.

### P1 (should ship)

6. Per-tier **min/max quantity** (metadata or columns) + checkout validation.  
7. **Free ticket** UX toggle + skip/short-circuit payment when fee+price = 0.  
8. **Platform fee preview** on checkout + organizer note.  
9. **Sales by tier** endpoint + table on manage screens.  
10. Loading / error / empty polish on manage + select.

### P2 (defer if timeboxed)

11. Promo codes / discounts (schema + apply).  
12. Tax lines.  
13. Duplicate tier, drag reorder (`sort_order`), unlimited capacity.  
14. Complimentary issuance.  
15. Invite-only purchase eligibility gate.  
16. Dedicated archive status (vs pause).

### Explicitly out of sprint

- Marketing campaigns, advanced analytics time-series, Live Ops, Vendor CRM, Attendee CRM (later phases)  
- Redesigning Event Workspace or replacing `TicketsTabV3`

---

## STOP

**Do not implement.** Await Phase 13 Completion Sprint authorization after this audit.
