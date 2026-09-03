# Vendor Services & Rentals — Gap Analysis

**Status:** Audit only. No implementation, migrations, API changes, or Flutter changes were made.  
**Date:** 2026-08-24  
**Scope:** Discover how Vendor, Service, Rental, Offering, Category, Booking, and Vendor-as-Buyer exist today, and whether the proposed taxonomy fits without redesigning Vendor CRM.

**Related frozen / canonical docs:** `docs/ARCHITECTURE_FREEZE_PHASES_14_18.md`, `docs/VENDOR_IDENTITY_RESOLUTION_REPORT.md`, `docs/VENDOR_OS_INTEGRATION_REPORT.md`. Vendor CRM (`vendor_event_requests`) is the canonical organizer↔vendor spine and must not be replaced.

---

## 1. Executive Summary

The platform already has **two commercial stacks** that both attach to the same `vendors.id`:

| Stack | Canonical tables | Buyer | Event required? | What it books |
|---|---|---|---|---|
| **Vendor CRM (services)** | `vendor_event_requests`, `vendor_services` | **Organizer** (`organizer_id` NOT NULL) | **Yes** (`event_id` NOT NULL) | A named **service** on a vendor |
| **Rentals marketplace** | `rental_catalog_items`, `rental_bookings` | **User** (`requester_user_id`, optional) | **Yes** (`event_id` NOT NULL) | A **catalog SKU** with quantity |

There is **no unified “Vendor Offering” entity** and **no offering type** (`SERVICE` / `RENTAL`) on taxonomy. Admin `tenant_vendor_categories` is a **single mixed catalogue**: service trades (DJ, catering), fashion, **and** rental equipment slugs (`chairs`, `sound-systems`, …) with **no type discriminator**.

**Vendor-as-buyer is not a first-class role.** The same **User** can activate multiple workspaces (organizer + vendor) without a second login. The same **Vendor ID cannot** currently create CRM requests as a buyer: create-request requires `ORGANIZER_REQUIRED` and writes `organizer_id`. A vendor user **can** theoretically open the customer marketplace and create a **rental booking** as `requester_user_id` **if they have an event** — there is still no `buyer_vendor_id`, no vendor-portal marketplace, and no self-book guard.

The DJ scenario (provide DJ service **and** rent speakers from another vendor, one identity) is **identity-compatible** (one `users.id` → one `vendors.id`) and **commerce-incompatible** until buyer identity on requests/bookings is extended without a second request system.

**Proposed ladder (Admin → Offering taxonomy → Service/Rental → Category → Offering → Marketplace → Booking → Order)** is a **good target model**, but it is **not** how the system is structured today. Fit is **partial**: reuse Vendor identity, `vendor_services`, CRM spine, rental catalog/inventory, and admin categories; do **not** invent a second CRM.

---

## 2. Current Vendor Architecture

### 2.1 Vendor identity (canonical)

```
User (users.id)
  → vendor_profiles (workspace activation, user_id unique per tenant)
  → vendors.id (business; owner_user_id)
```

- Canonical vendor ID = `vendors.id` (UUID). Documented in `docs/VENDOR_IDENTITY_RESOLUTION_REPORT.md`.
- Resolution: `vendor_profiles.vendor_id` COALESCE owned active `vendors.id`.
- Team: `vendor_users` (staff, not a second vendor).
- Status: `vendors.status` (draft / pending_review / active / suspended / …).
- **One vendor row per workspace profile** (unique `vendor_profiles` per user/tenant). Multi-category is stored as text, not multiple vendor identities.

**Classification: A — Canonical and reusable.**

### 2.2 Vendor profile

| Surface | Store | Notes |
|---|---|---|
| Workspace profile | `vendor_profiles` | `category` TEXT (CSV-capable), `services_offered` JSONB, bio, geo, onboarding |
| Extended workspace | later migrations | portfolio, starting price, `available_for_bookings` |
| Business KYC / bank | `vendor_applications`, `vendor_bank_accounts`, `vendor_kyc_*` | Onboarding pipeline |

**Classification: A** (profile). Category field is **B** (string, not FK to taxonomy).

### 2.3 Vendor onboarding

- Screen: `mobile/lib/features/vendor/screens/vendor_onboarding_screen.dart`.
- Prompt is **not** “What type of vendor are you?” as a single enum. It is **“Select one or more categories that describe your business.”**
- Categories are a **hardcoded Flutter list** (`_vendorCategories`), including `'Rentals'` as **one chip among service trades** — not admin taxonomy, not offering type.
- Persist: `vendor_profiles.category` as **CSV**; first chip used as package `category` when seeding catalog.
- Also: application/KYC/bank (`infra/db/003_vendor_onboarding.sql`).

**Classification: B** (works; taxonomy not canonical).

### 2.4 Vendor categories (admin)

Table `tenant_vendor_categories` (`infra/db/027_phase_event_v2.sql`): `slug`, `label`, `icon_key`, `sort_order`, `is_active`, later `metadata` (capabilities). No `offering_type` column. The same table holds service trades (e.g. `dj`), fashion slugs, and rental equipment slugs (e.g. `chairs`, `sound-systems`).

Seeded as **one list**: DJ/photographer/… **plus** fashion **plus** rental equipment slugs (`033_rentals_categories.sql`, `ensureRentalCategories`).

**Classification: A** as tenant config; **B** as offering taxonomy (no SERVICE vs RENTAL).

### 2.5 Marketplace

Two **parallel** customer-portal markets:

1. **`/vendors`** — `MarketplaceScreen` lists **vendors** (`GET /vendors` catalog). Filter by category/service string. Detail lists **`vendor_services`** offerings. Organizer (event-scoped) sends CRM request for a **service**.
2. **`/vendors/rentals`** — `MarketplaceRentalsScreen` lists **`rental_catalog_items`** (SKU + vendor name). Book via `rental_bookings` for an **event**.

**Classification: A** for both listings; **E** as two markets, not one offering index.

### 2.6 Vendor CRM / requests / pipeline / inbox / dashboard / workspace

| Piece | Reality |
|---|---|
| CRM spine | `vendor_event_requests` — unique `(event_id, vendor_id, service_key)` |
| Stages | new → negotiating → accepted → scheduled → arrived → completed / declined / cancelled |
| Pipeline UI | Organizer event vendors tab; vendor inbox/incoming requests |
| Conversation | Request id is conversation identity |
| Change requests | `vendor_request_change_requests` (additive; capability/date/venue) |
| Dashboard | Vendor home: requests, calendar, services, finance — **provider** surfaces |
| Event 360 | Vendor workspace for a booked event |
| Inbox | Canonical vendor identity → incoming **provider** requests |

**Classification: A.** Do not replace. Buyer is **always organizer**.

### 2.7 Availability

- **Services:** `vendor_service_availability`, blackouts, `vendor_calendar_blocks`, derived from CRM + rentals (`vendor-calendar.service.ts` loads `rental_bookings` as `rental_delivery`).
- **Rentals:** `available_quantity` / reserved on catalog; `rental_blackout_dates`.

**Classification: A** (two models, both real).

### 2.8 Contracts / negotiations / orders

| Piece | Classification | Notes |
|---|---|---|
| `vendor_negotiations` + offers | **A / B** | Organizer↔vendor; linked to request |
| AI `negotiation_sessions` | **E** | Parallel; identity report treated as non-canonical |
| In-memory contract UI | **C / D** | Not CRM spine |
| `bookings` + `payments` (core schema) | **E** | Package booking + PSP; `client_user_id` buyer; **not** CRM |
| OMS mock orders in vendor UI | **D** | Demo |

### 2.9 Existing booking structures (inventory of names)

1. `vendor_event_requests` — **canonical event service booking/request**.  
2. `rental_bookings` — **canonical event rental reservation**.  
3. `bookings` — **legacy/package** commercial aggregate (user client → vendor package).  
4. Ticket orders — **not vendor offerings**.

---

## 3. Current Service / Rental Architecture

Search coverage: service(s), rental(s), offering, product, package, vendor category/type, booking, reservation, inventory, availability, price/pricing, catalog, listing.

| Concept | Where | Class | Reusable? |
|---|---|---|---|
| **vendor_services** | 065+066+068+069 | **A** | Bookable service entity, price, capabilities, extras, status |
| **services_offered JSON** | vendor_profiles | **B** | Compat labels |
| **service_key / service_label** on requests | 063 | **A** | Request line identity |
| **Capabilities** (DJ controller, speakers, mics) | category `metadata` + `vendor_services.capabilities` | **A** as **flags on a service**, **F** as rentable SKUs |
| **custom_extras** | 069 JSON on service | **B** | Add-ons, not inventory |
| **vendor_packages** | core | **B / E** | Pricing tiers; not marketplace primary |
| **rental_catalog_items** | 032 | **A** | Inventory SKU, fee, deposit, qty |
| **rental_bookings** | 032 | **A** | Lifecycle pending→returned |
| **rental_blackout_dates** | 032 | **A** | |
| **VendorRentalsScreen** | Flutter | **D** when demo mode; empty otherwise — **not** wired to 032 API |
| **Attendee event services hub** | rentals module | **B** | Event-scoped services/rentals MVP |
| **VendorCatalogType.rentals** | Dart enum | **C** | UI type mapping |
| **product** | — | **F** | No product catalog |
| **offering / offering_type** | — | **F** | Comment-only “offering” on API DTOs |
| **inventory** (warehouse/QR) | Vendor rentals demo | **D** | Real inventory is `rental_catalog_items` quantities |
| **listing** | vendor catalog + rental catalog | **A** (split) | |

**Important:** DJ “needs a controller” is modeled today as an **admin capability checkbox on the DJ service**, not as “this DJ lists a Controller rental” and not as “this DJ rents Vendor B’s controller.” Mixing those will confuse organizers.

---

## 4. Admin Taxonomy Audit

**System:** `tenant_vendor_categories` + Admin UI “Service Categories & Capability Catalogue” (`admin_vendor_categories_screen.dart`).

| Capability | Exists? |
|---|---|
| List categories | Yes (admin + public `event-config/vendor-categories`) |
| Add | **Partial** — seed/ensure inserts; **no first-class Admin “create category” product flow** in the Flutter list (open row → capabilities). Server can INSERT in seed helpers. |
| Edit label/slug | Seed/ensure updates labels on conflict for fashion/rentals; capability PATCH is the live admin path |
| Activate / deactivate | **Yes** — `is_active` via admin patch (`isActive`) |
| Archive | **No** dedicated archive; inactive is the closest |
| Reorder | Column `sort_order` exists; **no Admin reorder UI** found on the categories screen |
| Service vs rental type | **No** |
| Offering types | **No** |
| Capability catalogue per category | **Yes** (core/optional tier in metadata) |

Rental **item** categories are the **same table** (`chairs`, `sound-systems`, …), not a child of `rentals-equipment`.

---

## 5. Vendor Onboarding Audit

| Question | Answer | Location |
|---|---|---|
| “What type of vendor are you?” | **Not as a typed enum.** Multi-select chips. | `vendor_onboarding_screen.dart` `_categoryStep` |
| One vs many categories | **Many** (Set → CSV on profile) | `categoryCsv`; `primaryCategory = _categories.first` for packages |
| Services | **Yes** — named services + optional prices seeded as packages | same screen |
| Rentals | Chip **“Rentals”** only; **does not** create `rental_catalog_items` | |
| Multiple offerings | **Yes** for services (`vendor_services` after profile). **No** rental SKU onboarding | |
| Bound to admin taxonomy? | **No** — hardcoded labels (`DJ` vs slug `dj`) | |

---

## 6. Marketplace Audit

**What Marketplace represents today:**

- **Primary `/vendors`:** **Vendors**, with nested **service offerings**. Buyer selects **vendor + service** (and optional capabilities), not a rental SKU.
- **`/vendors/rentals`:** **Offerings (SKUs)** attributed to a vendor. Buyer selects **item + quantity**, not “the vendor as a whole.”

**Organizer can currently select:**

| Target | `/vendors` | `/vendors/rentals` |
|---|---|---|
| Vendor | Yes | Indirect (via item.vendorName) |
| Service | Yes (`vendor_services`) | No |
| Rental (SKU) | No | Yes |
| Specific offering | Service id | Catalog item id |

Search is vendor-centric on the main market (name, city, category, `services_offered` / `vendor_services`). Rental search is catalog + category slug.

**Vendor portal does not host this marketplace** as a buyer UX.

---

## 7. Vendor-as-Buyer Audit

**Scenario:** Vendor A (DJ) searches marketplace, finds Vendor B, requests/rents equipment.

| Step | What happens today |
|---|---|
| Same account, no second vendor identity | **Supported** at identity layer (one user, one vendor profile). |
| Vendor A in Vendor workspace opens marketplace | **Not a vendor-workspace flow.** Marketplace lives on **customer/organizer** routes (`MarketplaceScreen`, event-scoped `eventId`). |
| Vendor A creates CRM request to Vendor B | **Blocked** unless A also has an **active organizer** and **owns the event**. `createRequest` → `resolveOrganizerId` → `ORGANIZER_REQUIRED`. Insert requires `organizer_id`. Unique key is `(event_id, vendor_id, service_key)` — **no buyer_vendor_id**. |
| Vendor A creates rental booking | **Possible as a user** if authenticated and an **event exists**. Buyer is `requester_user_id`, not vendor id. No check that requester is not the same vendor. No vendor inbox “my outgoing rentals.” |
| New identity required? | **No** for login. **Yes** today for CRM: must **also** be organizer (second **workspace**, not second vendor). |
| Attendee identity | Unrelated; tickets/RSVP. Not the buyer of vendor CRM. |
| Extension of Vendor ID as buyer | **Not implemented.** Compatible as an **additive** buyer actor on existing request/booking rows if product allows. |

**Would require (analysis only, not implementation):**

- **Not** a second Vendor row.  
- **Not** a second CRM table if buyer can be modeled as `buyer_user_id` / optional `buyer_vendor_id` **or** vendor-as-organizer of a personal/event context.  
- **Would** require access-control changes (who may `createRequest`) and UI in vendor workspace.  
- Using “activate organizer workspace” as the only path is an **identity workaround**, not Vendor-as-Buyer.

---

## 8. Booking / Request Audit

### 8.1 `vendor_event_requests`

| Field | Meaning today | Vendor→Vendor? |
|---|---|---|
| `organizer_id` | Buyer **must** be organizer | **Cannot** represent vendor buyer without schema/semantics change |
| `vendor_id` | Provider | Reusable |
| `event_id` | Required | Event-only |
| `vendor_service_id` / `service_key` | Offering = service | Rentals not first-class |
| `stage` | CRM lifecycle | Service-shaped (arrived/completed), not pickup/return |
| Negotiation / pricing / funds | Organizer event funds | Tied to organizer/event |
| Availability | Service window vs event | |

**Organizer → Vendor:** **Yes, this is the system.**

**Vendor → Vendor without a second request system:** **Not safely, as-is.** Reuse is possible only if:

- Buyer is still an organizer of **an** event, **or**
- Additive nullable `buyer_vendor_id` / generalize `organizer_id` (breaking freeze of CRM contracts — **needs approval**).

Rentals already cover equipment reservation **without** CRM. Forcing gear onto `vendor_event_requests` would overload `service_key` and uniqueness.

**Recommendation:** Keep CRM for **services**. Keep `rental_bookings` for **rentals**. Do not merge into one request table in v1. Optionally share **conversation/notification** patterns, not the row type.

---

## 9. Event Context Audit

| Path | Event-scoped? |
|---|---|
| CRM request | Always (`event_id` NOT NULL, CASCADE) |
| Rental booking | Always (`event_id` NOT NULL, CASCADE) |
| Core `bookings` | Event times on row; not `events.id` FK in original core table |
| Ticket commerce | Event-scoped (frozen Phases 14–17) |

**Business rules already in code:** vendor work is **event work**. Calendar, funds (`event_vendor_funds`), change requests, and uniqueness are event-keyed.

| Option | Fit to existing architecture |
|---|---|
| **A. Event-specific vendor booking** | **Matches current CRM + rentals.** DJ renting speakers for Owambe X attaches to event X. |
| **B. General marketplace rental (no event)** | **Does not exist.** Would need nullable `event_id`, new buyer/pay path, and a product exception to “everything vendor is an event.” |
| **C. Both** | Possible later; **not** current. |

**Recommendation from existing architecture (not an arbitrary product invention):**

- **v1: A — event-specific.** Vendor-as-buyer still books **against an event** (the gig they are hired for, or an event they organize).  
- **B deferred** until there is a non-event wallet and fulfillment model.  
- If the DJ is hired on Organizer O’s event, the **rental should hang on that same event** (provider = Vendor B, requester = DJ’s user id). Organizer visibility is a **product** follow-up (today organizer sees event rentals; requester is a name/user).

---

## 10. Data Model Audit

| Need | Existing | Extend safely? |
|---|---|---|
| Vendor | `vendors` | Yes — no second identity |
| Vendor offering (unified) | **None** | Prefer **two subtypes** (`vendor_services`, `rental_catalog_items`) over a new supertype in v1 |
| Offering type | **None** | Add later on category or subtype tables; do not fake via capabilities |
| Category | `tenant_vendor_categories` | Yes — additive `kind` / `offering_class` if approved |
| Booking (service) | `vendor_event_requests` | Extend buyer only with freeze approval |
| Booking (rental) | `rental_bookings` | Additive `buyer_vendor_id`; event already present |
| Request | same as service booking | Do not clone CRM |
| Order | ticket orders **A**; vendor funds **B**; rental **no order**; `bookings` **E** | Do not dual-write frozen ticket ledger |
| Availability | service windows + rental qty/blackouts | Reuse |
| Inventory | `rental_catalog_items` quantities | Reuse; warehouse/QR is demo |
| Pricing | service base + markup rules; rental fee+deposit | Separate calculators; don’t force 40% markup on deposits without a rule |

**Safe extensions (conceptual):** additive columns, new FKs nullable, no drop of `organizer_id` NOT NULL without a migration plan and freeze review.

---

## 11. Payment Audit

| Flow | Exists | Missing |
|---|---|---|
| **Ticket purchases** | Canonical (orders, ledger, payout). Frozen Phase 17. | — |
| **Vendor CRM requests** | Listed prices, markup snapshot, `funding_status`, `event_vendor_funds` / allocations | Not the ticket PSP path; organizer **funds the event**, not a per-SKU checkout |
| **Vendor negotiations** | Offer amounts on negotiation tables | Settlement still via request/funds, not a separate PSP product |
| **Vendor services** | `base_payout_minor` + platform markup → customer price | Capture/release coupled to funding stages |
| **Rentals** | `rental_fee_minor`, `deposit_minor` on catalog and booking | **No** ledger, **no** deposit hold, **no** damage capture, **no** payout to rental vendor in rentals module |
| **Legacy `payments` ↔ `bookings`** | Package booking PSP | Parallel to CRM; not marketplace CRM |

**Do not** pipe rental deposits through ticket commerce without explicit Phase 17 approval.

---

## 12. Recommended Architecture

Compatible with existing identity:

```
User
  → Vendor Profile
  → Vendor ID
  → Vendor Offerings (services and/or rental SKUs)
```

Same Vendor ID as **provider**. Same **User** (and optionally same Vendor ID recorded as buyer) as **buyer**. **No second Vendor identity.**

### 12.1 Vendor identity model

Keep current chain. Multi-role = **workspaces** (vendor + organizer + client), not multiple `vendors` rows.

### 12.2 Offering model

**Two offering kinds, one vendor:**

- `vendor_services` = SERVICE offerings (labor/performance).  
- `rental_catalog_items` = RENTAL offerings (counted assets).  

Do not collapse into one table until a real polymorphic need appears. Optional later `offering_id` view for search.

### 12.3 Service vs Rental model

| | SERVICE | RENTAL |
|---|---|---|
| Book via | `vendor_event_requests` | `rental_bookings` |
| Identity of line | `vendor_service_id` | `catalog_item_id` |
| Capabilities | Included kit **with the service** | Separate SKUs |
| Inventory | No (or capacity later) | Quantity now |

### 12.4 Category model

Keep `tenant_vendor_categories`. Add a **kind** when implementing: `service_trade` | `rental_asset` | `fashion` (or similar). Stop treating `chairs` as the same class as `dj`.

### 12.5 Admin taxonomy model

Reuse list + `is_active` + capabilities for **service trades**. Rental slugs configure **SKU categories**. Add/edit/reorder as product gaps (P1), not a new taxonomy service.

### 12.6 Vendor onboarding model

Replace hardcoded chips with **admin-active categories**, allow **both** service trades and rental asset categories, and branch: services editor vs inventory create. Still **one** vendor.

### 12.7 Marketplace model

**Both:** vendor cards (services) **and** SKU cards (rentals). Cross-link: vendor detail shows both service list and rental inventory. Vendor-as-buyer uses the **same catalogs** with event context.

### 12.8 Vendor-as-buyer model

**Existing Vendor identity extension**, not a new account:

- Buyer principal = `users.id`.  
- Optional `buyer_vendor_id` when the user is acting from vendor workspace.  
- CRM create path: either require event + organizer **or** (approved) allow vendor buyer on an event they are already engaged on.  
- Rentals: already user-based; add vendor workspace UX + “cannot rent from self.”

### 12.9 Booking/request model

**Do not create a second CRM.**  
Services → existing requests. Rentals → existing `rental_bookings`. Shared: notifications, calendar blocks (already), later unified “my bookings” inbox.

### 12.10 Event relationship

**Event-specific (A)** for v1, matching both current FKs.

### 12.11 Pricing model

Keep service markup rules for services. Rentals: fee × qty + deposit; **decide later** whether platform markup applies to rental fee (today rental path does not use `platform_vendor_pricing_rules`).

### 12.12 Availability model

Services: calendar/windows. Rentals: quantity + blackouts + delivery date. Calendar already unions rental deliveries.

### 12.13 Inventory requirements

**Now:** quantities on `rental_catalog_items` (already).  
**Defer:** warehouse, QR, maintenance (demo screen only).

### 12.14 Payment requirements

**Now:** keep CRM funding for services.  
**Rentals:** payment is a **gap** (amounts only).  
**Defer:** unified checkout, deposit escrow, vendor-as-buyer paying from vendor wallet.

---

## 13. Gap Table

| Area | Current State | Gap | Reusable Component | Recommended Change | Priority |
|---|---|---|---|---|---|
| Vendor identity | User → profile → `vendors.id` | None for dual role at identity | `vendors`, `vendor_profiles` | Keep; no second vendor | — |
| Offering type SERVICE/RENTAL | Not modeled | No discriminator | Two tables | Document kinds; optional category `kind` | P1 |
| Unified offering | Absent | Split markets | `vendor_services` + `rental_catalog_items` | Facade/search later, not merge | P2 |
| Admin taxonomy | Mixed slugs, capabilities, is_active | No type; weak add/reorder/archive | `tenant_vendor_categories` | Classify slugs; Admin CRUD completeness | P1 |
| Onboarding | Hardcoded multi-category | Not admin-backed; Rentals chip ≠ inventory | Onboarding wizard | Bind to taxonomy; inventory step | P1 |
| Marketplace (services) | Vendor + service | No rental SKUs | `GET /vendors`, CRM create | Cross-link inventory on vendor detail | P1 |
| Marketplace (rentals) | SKU catalog | Isolated from CRM; event required | `GET rentals/catalog` | Vendor-as-buyer UX; self-book guard | P0 |
| Vendor-as-buyer | Workspaces only | CRM organizer-only; no buyer_vendor | User + rental requester | Extend access + optional buyer_vendor_id | P0 |
| CRM for V→V | Organizer→Vendor only | Cannot express vendor buyer | `vendor_event_requests` | Do not fork CRM; additive buyer **or** event+organizer policy | P0 |
| Capabilities vs rentals | Flags on DJ service | Organizers think “has speakers” ≠ “rents speakers” | Capability catalogue | Copy: capabilities = included; rentals = SKUs | P1 |
| Vendor rentals UI | Demo warehouse | Not bound to 032 API | `RentalsService` | Wire vendor inventory to API | P1 |
| Rental payment | Fee/deposit fields | No PSP/ledger | Amounts on booking | Design with finance; not ticket ledger | P1 |
| Service payment | Event funds + markup | — | CRM + funds | Unchanged | — |
| Inventory ops | Qty columns | No warehouse/QR | catalog qty | Defer QR/maintenance | DEFERRED |
| Event-less rental | Impossible (NOT NULL event) | Consumer rental without event | — | Defer | DEFERRED |
| Core `bookings` | Parallel package path | Second booking truth | — | Do not use for this program | P2 |
| Contracts/AI nego | Parallel stacks | Noise | CRM negotiations | Leave frozen; don’t extend for rentals v1 | DEFERRED |

---

## 14. Risks

1. **CRM freeze / no redesign:** Generalizing `organizer_id` or uniqueness keys is a **contract change**. Prefer rental path for V→V equipment and keep CRM organizer-shaped unless approved.  
2. **Two markets, two truths:** Organizers already juggle vendors vs rentals. Unifying UX without unifying data will confuse.  
3. **Capabilities ≠ inventory:** DJ “speakers” capability vs renting Vendor B’s speakers will double-count or hide shortages.  
4. **Phase 17 finance:** Rental money must not silently enter ticket ledger.  
5. **Self-dealing:** Same vendor booking themselves — no guard.  
6. **Event CASCADE:** Deleting an event deletes rental bookings and CRM rows.  
7. **Demo VendorRentalsScreen** looks like a product; it is not the 032 stack.  
8. **Vendor must become organizer** to use CRM as buyer — violates the stated “no second identity” **intent** even if it is a second **workspace**.  
9. **Architecture freeze 14–18:** Event publish/tickets/door/finance/analytics stay read-only consumers; don’t retarget frozen payment workflows.

---

## 15. Recommended Implementation Phases

*(Planning only — not scheduled work.)*

**Phase 0 — Product rules:** Event-scoped only; capabilities vs SKUs copy; buyer = user (+ optional vendor id); no second CRM.

**Phase 1 — Taxonomy hygiene:** Category `kind`; Admin labels for rental vs service; onboarding reads admin list.

**Phase 2 — Provider completeness:** Wire vendor inventory UI to `rental_catalog_items`; DJ can list services **and** SKUs on one vendor.

**Phase 3 — Vendor-as-buyer (rentals):** Vendor workspace → same rental catalog → `rental_bookings` on the **event**; prevent self-rent; inbox for outgoing requests.

**Phase 4 — Vendor-as-buyer (services):** Only if needed (DJ hiring another DJ). Requires freeze-approved CRM buyer rules. Prefer not in v1.

**Phase 5 — Payment for rentals:** Deposit/fee capture aligned with finance, not tickets.

**Phase 6 — Unified marketplace search (optional):** Offering index over both tables.

---

## 16. Explicitly Deferred Items

- Event-less / consumer rental (model B).  
- Unified polymorphic `vendor_offerings` table.  
- Warehouse, QR, damage/maintenance as operational WMS.  
- Applying service markup bps to rental deposits.  
- Replacing Vendor CRM or merging `rental_bookings` into `vendor_event_requests`.  
- Second vendor account / second `vendors.id` for buyer.  
- Routing rental payments through ticket orders.  
- Redesign of AI negotiation / mock OMS / in-memory contracts.  
- Full Admin archive + drag-reorder (nice-to-have).  
- Capacity model for services (guest count as inventory).  
- Pickup/delivery logistics network.

---

## Fit of the proposed direction (audit, not approval)

```
ADMIN → OFFERING TAXONOMY → SERVICE/RENTAL → CATEGORY → VENDOR OFFERING
  → MARKETPLACE → BOOKING/REQUEST → ORDER/PAYMENT
```

| Layer | Fit |
|---|---|
| ADMIN | Exists for categories + capabilities |
| OFFERING TAXONOMY | **Missing** (mixed category list) |
| SERVICE / RENTAL | **Exists as two stacks**, not one enum |
| CATEGORY | Exists, untyped |
| VENDOR OFFERING | Services **and** rental SKUs, not a single entity |
| MARKETPLACE | Two markets |
| BOOKING / REQUEST | Two books; CRM organizer-only |
| ORDER / PAYMENT | Services: funds; rentals: **amounts only**; tickets: separate |

**Compatible intent:** one vendor, both offering kinds, same user as buyer.  
**Incompatible as a drop-in:** single offering table, CRM for all bookings, vendor ID as CRM buyer without a change-control review.

---

## Conclusion

The codebase is sufficient to decide: **reuse identity + split offerings (services vs rental SKUs) + event-scoped bookings + extend buyer on rentals first.** Remaining questions are **product/freeze** (CRM buyer, rental payments), not missing tables for a first rental marketplace.

✅ Vendor Services & Rentals Gap Analysis Complete
