# Vendor Business Types / Services / Rentals — Scope and Gap Analysis

**Mode:** Stabilization. Additive extension only.  
**Date:** 2026-08-25  
**Status:** Scope definition + gap analysis. **No application, API, Flutter, schema, or migration changes.**  
**Does not redesign:** authentication, user identity, organizer, attendee, vendor identity, Vendor CRM, RBAC, organization, finance, analytics, reporting, automation, integrations, compliance, control plane.

**Prior discovery:** `docs/VENDOR_SERVICES_RENTALS_GAP_ANALYSIS.md` (architecture audit). This document **locks the agreed product model** (capabilities, packages, Super Admin ownership, vendor-as-buyer) against that architecture.

---

## 1. Executive Summary

Owanbe already has **one canonical Vendor identity** and **two commercial stacks** on that identity:

| Capability (intended) | Existing stack | Buyer today | Event |
|---|---|---|---|
| **Service Provider** | `vendor_services` + `vendor_event_requests` (Vendor CRM) | Organizer only | Required |
| **Rental Provider** | `rental_catalog_items` + `rental_bookings` | Any authenticated `requester_user_id` | Required |

**Vendor capability** (Service Provider / Rental Provider / both) **does not exist** as a first-class flag. Onboarding treats “Rentals” as one **category chip** among DJ/Catering, which **collapses** “DJ” (service) with “DJ equipment rental” (rental).

**Service default requirements** (DJ needs controller, mixer, speakers) are **not** a master catalogue. The closest system is **Admin capability flags** on a service category (what the vendor *declares they provide*), plus organizer **selected capabilities** on a CRM request. That is **not** a kit BOM and **not** rental sourcing.

**Rental packages/sets** are **not** first-class. The rental catalogue is **SKU + quantity**. Booking API is `quantityRequested` against one item — the opposite of “book one Wedding DJ Equipment Set.”

**Architecture choice (from existing code, not preference):** **Option A.** Keep Service CRM and Rental bookings **separate internally**. Unify **marketplace and workspace UX**. Do **not** create a unified offering table or a second CRM.

**Vendor-as-buyer** is identity-compatible (same `users.id` / `vendors.id`) and **commerce-incomplete**. First additive path: event-scoped **rental_bookings** from Vendor Workspace. Do **not** change Vendor CRM in this initiative.

**Rental money:** amounts stored on catalog and booking rows. **MISSING** from Finance ledger, refunds, and settlement (`commerce_kind` has TICKET / BOOKING / REFUND / PAYOUT / SETTLEMENT — no RENTAL; rental module never writes ledger).

---

## 2. Existing Vendor Identity Architecture

```
User (users.id)
├── Organizer workspace  → organizers / organizer_profiles
├── Attendee workspace   → attendee_profiles
└── Vendor workspace     → vendor_profiles.vendor_id → vendors.id
```

- Canonical vendor = `vendors.id`.
- One `vendor_profiles` row per user/tenant.
- Staff via `vendor_users`, not extra vendor identities.
- Multi-workspace is **role activation**, not a second login.

**Rule (locked):** Do not create service-vendor users, rental-vendor users, or a vendor-buyer identity. Capability is **on the vendor**, not a new user type.

**Classification:** Canonical. Reuse as-is.

---

## 3. Vendor Capability Model

**Agreed model**

```
Vendor
├── Service Provider?  (boolean, independent)
└── Rental Provider?   (boolean, independent)
```

Not mutually exclusive. Not equal to identity.

**Current state:** **F — not implemented.**

| What exists | Why it is not capability |
|---|---|
| `vendor_profiles.category` CSV | Trade labels; “Rentals” is a category, not a capability bit |
| `tenant_vendor_categories` | Mixed service trades + rental equipment slugs; no `kind` |
| `vendors.status` | Marketplace/KYC lifecycle |
| `vendor_services` presence | Implies service activity but not an explicit capability |
| `rental_catalog_items` presence | Implies rental activity but not an explicit capability |

**Recommended extension (not implemented):** Additive flags on `vendor_profiles` or `vendors` (e.g. `is_service_provider`, `is_rental_provider`), **or** derived from whether the vendor has active services / rental packages — Super Admin still owns the **definitions**; vendors opt in at onboarding. Prefer **stored flags + validation** so a rental-only vendor is not forced through DJ service CRM.

**DJ Mike vs SoundPro:** same `vendors` table; different capability flags and different offering rows.

---

## 4. Service Model

**Agreed:** A service is something the vendor **performs**. Organizer books the **service**, not each component.

**Current (canonical):** `vendor_services`

- `service_key` / `service_name`, `status` (active/inactive/archived)
- `base_payout_minor`, `currency`
- `capabilities` JSON — vendor toggles from **Admin catalogue**
- `custom_extras` JSON — vendor-priced add-ons
- Marketplace: organizer selects `vendorServiceId` → `POST .../vendor-requests`

**Organizer does not buy microphones separately** in CRM today: they book DJ service and optionally tick capability keys (sound system, mics, etc.). Those ticks mean **“vendor says they include this with the service,”** not “platform sources a rental.”

**vendor_packages:** pricing tiers (`per_guest` / `fixed` / `hourly` / `custom_quote`). **Not** service requirement kits. **Not** rental sets.

**Classification:** Service performance model = **A**. Service-as-kit-fulfillment = **F**.

---

## 5. Rental Model

**Agreed:** Buyer books a **defined package/set**, not “give me 2 microphones.”

**Current:** `rental_catalog_items` is one named item with:

- `category_slug`, `name`, `description`
- `total_quantity` / `available_quantity` / `reserved_quantity`
- `rental_fee_minor`, `deposit_minor`

**Booking:** `rental_bookings.quantity_requested` (and approve/counter quantities). Status: pending → approved / countered / declined → delivered → returned.

**Classification:** Individual SKU + quantity = **A**. Package/set as the **primary** offering = **F** (gap). A vendor could **name** an item “Wedding DJ Equipment Set” and set `total_quantity = 1`, stuffing the kit into `description` — that is **convention**, not a component model, and the API still asks for **quantity**.

Do **not** replace `rental_catalog_items` in this scope. Extend later toward packages (see §7).

---

## 6. Service Requirement Model

**Intended:** Super Admin defines default components for a service type (DJ → controller, mixer, speakers, mics, cables). Organizer still books the **service**.

**Search result — what is NOT a requirement BOM**

| Candidate | What it actually is | Class |
|---|---|---|
| Admin `tenant_vendor_categories.metadata.capabilities` | Catalogue of **flags** (core/optional) per **category slug** | **B** — closest; “does this DJ include speakers?” not “default kit to deliver DJ” |
| `vendor_services.capabilities` | Vendor ON/OFF against that catalogue | **B** |
| Organizer `selectedCapabilities` on request | Snapshot of requested flags | **B** |
| `SPECIAL_REQUIREMENT` change request | Free-text note | **C** operational text |
| `custom_extras` | Priced add-ons | **B** commercial extras |
| Attendee `accessibility_requirements` | Unrelated | — |
| Equipment ownership / rental sourcing | **None** | **F** |

**Do not invent:** there is no `service_requirements`, no master resource table, no “source remaining kit from marketplace” engine.

**Recommended extension:** Super Admin **master resource catalogue** + **service default requirement** rows (service category → resource keys). Vendor workspace can later mark “I own this” vs “source from rental.” **v1 of this initiative should not auto-procure rentals when a service is booked** (that would mix CRM and rentals). v1: definitions + copy so organizers understand included kit vs renting a package.

---

## 7. Rental Package Model

**Intended primary unit:** one offering, e.g. *Wedding DJ Equipment Set* including fixed line items (5 mics, 2 speakers, …). Buyer books **the package**.

**Current primary unit:** one SKU, buyer/API supplies **quantity**.

| Package need | Exists? |
|---|---|
| Named set as catalog row | Only if vendor names it that way |
| Structured component list | **No** |
| Fixed included quantities | **No** (request quantity is free) |
| Package rules owned by Admin | **No** |
| Hide à-la-carte qty from buyer UX | **No** — marketplace and API are item+qty |

**Recommended extension:** Additive `rental_packages` (or JSON `components` on catalog item) **later**. Until then, treat **one catalog row = one bookable package** with `quantity` constrained to 1 in **product rules**, without replacing the table. À-la-carte qty remains **DEFERRED** as primary UX (architecture rule).

---

## 8. Super Admin Configuration Model

**Do not create a parallel Admin system.** Own this under existing **Control Tower → Commerce Configuration**.

**Existing owner**

| Surface | Role |
|---|---|
| `CommerceConfigurationScreen` | Hub: Vendor Pricing, Vendor Capabilities, Service Categories, Fee Rules placeholder |
| `AdminVendorCategoriesScreen` + `GET/POST` event-config `vendor-categories` | Tenant `tenant_vendor_categories` list, `is_active`, capability JSON |
| `AdminVendorPricingScreen` | Markup rules (`platform_vendor_pricing_rules`) |
| `event-config.service.ts` `ensureRentalCategories` | Seeds rental slugs into the **same** category table |

**Gap vs Super Admin master definitions**

| Super Admin should own | Current | Extension |
|---|---|---|
| Vendor capabilities (Service / Rental Provider) | Missing | Definitions in Commerce Configuration; vendor opt-in on profile |
| Service categories | Partial — mixed with rentals/fashion | Split **kind** on existing table or filter in Admin UI |
| Rental categories | Slugs exist (`chairs`, `sound-systems`, `rentals-equipment`, …) | Same table + `kind = rental`; optional grouping under “DJ Equipment” |
| Master resource/component catalogue | Missing (capabilities are service-category-scoped flags, not a global resource list) | New **config** data owned by same event-config / commerce admin APIs |
| Service default requirements | Missing | Config rows: service category → resource keys |
| Rental package rules | Missing | DEFERRED until package entity exists |

**Control plane** (`infra/db/061_control_plane.sql`) is **not** the vendor taxonomy store. Do not relocate categories there.

---

## 9. Vendor Onboarding Model

**Current:** `vendor_onboarding_screen.dart` — “Select one or more categories” from a **hardcoded** list including Catering, DJ, **Rentals**, Logistics, etc. Persists CSV on `vendor_profiles.category`. Optionally seeds `vendor_packages`. Completes vendor workspace onboarding. KYC/application remains separate (`vendor_applications`).

**Intended (not final UI):**

1. What type of vendor? ☐ Service Provider ☐ Rental Provider (one, the other, or both).  
2. If service: what services?  
3. If rental: what rental categories?

**Fit:** Same wizard, **additive steps**. Still one `completeOnboarding(workspace: vendor)`. Bind chips to **Admin-active** service vs rental categories, not hardcoded strings. Do not create a second onboarding product.

**Gap:** No capability step; Rentals chip ≠ rental inventory; category list ≠ `tenant_vendor_categories`.

---

## 10. Organizer Marketplace Model

**Services path (canonical):** Organizer event workspace → `/vendors?eventId=` → vendor cards → service list → `request_vendor_sheet` → CRM `vendor_event_requests`.

**Rentals path (existing, separate route):** `/vendors/rentals?eventId=` or `/events/:id/rentals` → catalog items → `POST events/:eventId/rentals/bookings`.

**Organizer-as-buyer of services:** **PASS** (CRM).  
**Organizer-as-buyer of rentals:** **PARTIAL** (SKU marketplace exists; not package-first; not unified with services market).

**Do not** add a third marketplace. Unify **navigation/copy** (Services vs Rentals tabs) over the two existing catalogs.

---

## 11. Vendor-as-Buyer Model

**Locked:** Same vendor identity. Flow:

Vendor Workspace → Select Event → Marketplace → Rentals → Rental Provider → Package → Book/Request.

**Current**

| Need | State |
|---|---|
| Same vendor id | PASS |
| Vendor workspace marketplace | MISSING |
| Select event then rent | Event required on `rental_bookings` — PASS at data layer |
| Buyer recorded as vendor | MISSING (`requester_user_id` only) |
| CRM service request as vendor buyer | BLOCKED (`ORGANIZER_REQUIRED`) — **out of this scope** (do not modify CRM) |
| Self-rent guard | MISSING |

**Recommended first extension:** Vendor Workspace deep-link into **existing** rental catalog APIs with `eventId` of an event the vendor is **already on** (CRM accepted/scheduled) or an event they organize if they also have organizer workspace. Persist `requester_user_id`; optional later `buyer_vendor_id` on `rental_bookings` only.

---

## 12. Vendor-to-Vendor Model

Same conceptual buyer/provider; both sides are vendors.

| Path | Can existing rental architecture support it first? |
|---|---|
| **Rental V→V** | **Yes, additively.** Provider = `rental_bookings.vendor_id`. Buyer = user (already). Event = required. Missing: workspace UX, buyer_vendor_id, self-book guard, package-first UX. **No second booking system required.** |
| **Service V→V (CRM)** | **Not in this scope.** `vendor_event_requests.organizer_id` NOT NULL. Reuse later would be additive buyer semantics — **requires freeze/CRM change-control.** Do **not** implement in this initiative. Do **not** create a second CRM. |

---

## 13. Event Context

**Locked for initial implementation:** event-scoped.

Both `vendor_event_requests.event_id` and `rental_bookings.event_id` are **NOT NULL**. Calendar already overlays rental deliveries on the vendor calendar.

**Non-event marketplace rentals:** no existing architecture requires them. **Do not introduce.**

Example (in-scope): DJ Vendor → Event Wedding A → Rental Package “Wedding DJ Equipment Set” → `rental_bookings.event_id = Wedding A`.

---

## 14. Existing Database Structures

| Object | Role in this initiative |
|---|---|
| `users` | Buyer/provider principal |
| `vendors` | Canonical vendor |
| `vendor_profiles` | Workspace; category CSV; **no capability flags** |
| `vendor_services` | Service offerings |
| `vendor_event_requests` | Service CRM — **do not modify in this scope** |
| `vendor_request_change_requests` | CRM change proposals — untouched |
| `rental_catalog_items` | Rental SKUs (extend toward packages later) |
| `rental_bookings` | Event rental reservations |
| `rental_blackout_dates` | Rental unavailability |
| `tenant_vendor_categories` | Admin taxonomy (untyped mix) |
| `platform_vendor_pricing_rules` | Service markup only |
| `event_vendor_funds` / allocations | CRM service funding |
| `vendor_packages` | Service price tiers — not rental sets |
| `vendor_calendar_blocks` | Includes `rental_delivery` |
| `bookings` / `payments` | Legacy package PSP — **do not use** as the new rental rail |
| `ledger_transactions.commerce_kind` | TICKET, BOOKING, REFUND, PAYOUT, SETTLEMENT — **no rental** |

---

## 15. Existing APIs

**Identity / services**

- `PATCH /me/vendor-profile`, `PATCH /me/vendor-services/:serviceId`
- `GET /vendors`, `GET /vendors/:vendorId/services`

**CRM (frozen for this initiative)**

- `GET/POST /events/:eventId/vendor-requests`
- Stage, counter, messages, fund, complete, change-requests
- `GET /vendors/:vendorId/requests`, calendar

**Rentals (reuse)**

- `GET /rentals/catalog`, `GET /rentals/catalog/:itemId/availability`
- `GET/POST/PATCH /vendors/:vendorId/rentals/inventory`
- `GET/POST .../rentals/blackouts`
- `GET /vendors/:vendorId/rentals/bookings` + approve/counter/decline/deliver/return
- `GET/POST /events/:eventId/rentals` / `.../bookings`
- Attendee hub: `GET /events/:eventId/services`, `.../services/rentals`

**Admin**

- `GET event-config/vendor-categories` (public)
- `GET/POST` admin `vendor-categories` (capabilities + `isActive`)
- Admin vendor-pricing-rules

**Missing APIs (scope, not implement):** vendor capability flags; resource catalogue; service default requirements; rental package components; vendor-workspace buyer booking helper.

---

## 16. Existing Flutter Workspaces

| Workspace | Relevant screens | Gap |
|---|---|---|
| **Vendor** | Dashboard, inbox/CRM incoming, `/vendor/services` availability, `ServiceCatalogScreen` (mixed/demo catalog), `VendorRentalsScreen` (**demo inventory**, not 032 API), calendar | No “My Rental Packages”; no buyer marketplace; catalog tab ≠ `vendor_services` only |
| **Organizer / customer event** | `MarketplaceScreen`, `MarketplaceRentalsScreen`, `CustomerEventRentalsScreen`, vendors pipeline CRM | Two markets; SKU not package; no capability vs rental copy |
| **Attendee** | Event services hub (Phase 9) | Parallel attendee rental path — do not expand as vendor-as-buyer |
| **Super Admin** | Commerce Configuration → pricing, capabilities, categories | No vendor-capability (provider type), resource catalogue, or rental package rules |

---

## 17. Finance / Payment Gap

| Question | Finding | Mark |
|---|---|---|
| Where rental amounts are stored | `rental_catalog_items.rental_fee_minor`, `deposit_minor`; copied to `rental_bookings` as fee × qty | **PASS** (storage) |
| Do rental payments enter Finance workspace? | No rental module calls organizer finance / ticket order / vendor funds | **MISSING** |
| Ledger entries? | `commerce_kind` has no rental; rentals.service does not insert `ledger_transactions` | **MISSING** |
| Rental refunds? | Booking can `cancelled` / `declined`; no refund money movement | **MISSING** |
| Rental settlement / payout to rental vendor? | Not in rentals module. CRM funds are **service** requests only | **MISSING** |
| Invent payment success? | Forbidden | **DEFERRED** (do not fake) |
| Ticket / CRM service payments | Unchanged; frozen finance for tickets | **PASS** (out of scope) |
| Markup on rentals | Pricing rules are service-key based; rentals do not use them | **PARTIAL** / **DEFERRED** |

**Do not** route rental capture through ticket orders. Any future rental finance is an **additive** commerce_kind / funds design requiring finance approval — **DEFERRED** for implementation.

---

## 18. Architecture Recommendation

### Critical question: A vs B

**Recommend A:** Keep Service and Rental **commercial stacks separate internally**; one **unified marketplace/workspace experience**.

**Why (from existing architecture, prefer additive reuse):**

1. Different entities (`vendor_services` vs `rental_catalog_items`), different unique keys, different lifecycles (CRM stages vs delivered/returned), different buyers (organizer vs user).
2. Vendor CRM is **certified / not to be redesigned** in this initiative. A unified offering table would pressure CRM and uniqueness (`event_id, vendor_id, service_key`).
3. Rental inventory/quantity and CRM availability are already **partially joined** on the calendar — that is the right seam, not a merged booking table.
4. Creating a unified offering architecture (**B**) is a **replacement**, not an extension, and violates “prefer additive reuse” and “no parallel booking system.”

**B is rejected for this program** unless a later freeze-approved program replaces both stacks (not Stabilization).

### Locked design (scope)

1. **Identity:** unchanged User → Vendor.  
2. **Capabilities:** Service Provider and/or Rental Provider on that vendor.  
3. **Offerings:** Services in `vendor_services`; rental packages as evolution of `rental_catalog_items` (not CRM).  
4. **Taxonomy:** Super Admin via **existing** Commerce Configuration + `tenant_vendor_categories` (+ additive kind/resources).  
5. **Organizer:** existing CRM for services; existing rental APIs for packages.  
6. **Vendor-as-buyer:** rental stack first, event-scoped.  
7. **CRM V→V services:** out of scope.  
8. **Payments:** do not invent; rental finance DEFERRED.  
9. **Primary rental UX:** package/set, not à-la-carte quantity.

---

## 19. Gap Analysis Table

| Area | Current State | Existing Source | Gap | Recommended Extension | Priority |
|---|---|---|---|---|---|
| Vendor identity | One vendor per user workspace | `users`, `vendor_profiles`, `vendors` | None | None | — |
| Vendor capability bits | Missing | — | Cannot express service-only / rental-only / both | Additive flags + Admin definitions | **P0** |
| DJ vs DJ equipment | Collapsed in onboarding “Rentals” chip + mixed categories | `vendor_profiles.category`, `tenant_vendor_categories` | Category ≠ capability; service ≠ rental | Category `kind`; copy; onboarding split | **P0** |
| Service offerings | Canonical | `vendor_services`, CRM | No default kit BOM | Keep CRM; add Admin default requirements **config** | **P1** |
| Capability flags | Admin + vendor toggles | category metadata, `vendor_services.capabilities` | Not resources; not sourcing | Keep for “included with service”; do not use as rental SKUs | **P1** |
| Rental SKUs | Canonical item+qty | `rental_catalog_items`, `rental_bookings` | Not packages/sets | Product: one row = package, qty=1; later components JSON/table | **P0** (UX/rules) / **P2** (structured BOM) |
| Rental vendor UI | Demo warehouse | `VendorRentalsScreen` | Not wired to inventory API | Wire “My Rental Packages” to existing inventory APIs | **P0** |
| Service vendor UI | Availability + mixed catalog | `/vendor/services`, `ServiceCatalogScreen` | Catalog tab not clearly “My Services” | Align UI to `vendor_services` | **P1** |
| Onboarding | Hardcoded multi-category | `vendor_onboarding_screen.dart` | No provider-type step | Additive wizard steps bound to Admin lists | **P0** |
| Super Admin taxonomy | Categories + capabilities + pricing | Commerce Configuration, event-config | No provider types, resource catalogue, requirement maps, package rules | Extend **same** hub, no parallel Admin | **P0** |
| Organizer services market | Vendor + service + CRM | `MarketplaceScreen` | Unified IA with rentals | Tabs/copy only | **P1** |
| Organizer rentals market | Item catalog | `MarketplaceRentalsScreen` | Package-first; qty à-la-carte | Constrain UX to packages | **P1** |
| Vendor-as-buyer | Identity only | `requester_user_id` | No vendor workspace flow | Deep-link rental APIs + event | **P0** |
| V→V rentals | Data allows user requester | `rental_bookings` | UX + buyer_vendor_id + self-guard | Additive columns/UX; **no new booking table** | **P0** |
| V→V services CRM | Organizer-only | `vendor_event_requests` | Vendor buyer | **Do not change CRM this initiative** | **DEFERRED** |
| Event scope | Both stacks event-bound | `event_id` NOT NULL | None for v1 | Keep | — |
| Non-event rental | Impossible | — | — | Do not add | **DEFERRED** |
| Rental payment storage | Fee + deposit on rows | catalog + bookings | Not money movement | Leave amounts; no fake success | **PASS** / pay **DEFERRED** |
| Rental ledger/refunds/settlement | None | Finance is tickets + CRM funds + BOOKING kind | Missing | Finance-approved additive later | **DEFERRED** |
| Parallel marketplace | Two routes | `/vendors`, `/vendors/rentals` | Fragmented UX | Unify shell, keep two APIs | **P1** |
| Parallel Admin | Avoided if we extend Commerce Configuration | — | Risk of new config app | Forbidden | — |
| Equipment ownership | None | — | DJ cannot mark “I own speakers” | Later on vendor resources | **P2** |
| Auto-source rentals when service booked | None | — | Would mix CRM + rentals | Forbidden in v1 | **DEFERRED** |
| Legacy `bookings` PSP | Parallel | `bookings` | Second truth | Do not use | — |

---

## 20. Recommended Implementation Phases

*(Definition only — no build.)*

**Phase 0 — Scope lock (this document):** A not B; CRM untouched; event-scoped; packages not qty-primary; no invented payments.

**Phase 1 — Super Admin config (additive):** Category `kind` (service vs rental); Commerce Configuration copy; master resource list **config**; DJ vs DJ Equipment as different categories.

**Phase 2 — Vendor capability + onboarding:** Service Provider / Rental Provider flags; wizard steps; still one vendor.

**Phase 3 — Provider workspace:** My Services → `vendor_services` (existing). My Rental Packages → existing inventory API; treat item as package (qty 1).

**Phase 4 — Marketplace IA:** Organizer + Vendor Workspace: Services vs Rentals using **existing** endpoints; package-first rental UX.

**Phase 5 — Vendor-as-buyer (rentals):** Event-scoped `POST .../rentals/bookings`; optional `buyer_vendor_id`; self-book guard.

**Phase 6 — Structured package BOM + service default requirements** (Admin), still no auto-procurement.

**Phase 7 — Rental finance** (only with finance approval). **DEFERRED** until then.

**Explicitly not phased here:** Vendor CRM organizer_id changes; unified offering table; non-event rentals.

---

## 21. Deferred Items

- Vendor → Vendor **service** CRM  
- Unified offering schema (Option B)  
- Non-event / consumer rentals  
- À-la-carte “2 microphones” as primary request model  
- Auto-rent when a service is booked  
- Rental ledger, refunds, settlement, markup  
- Warehouse / QR / maintenance (`VendorRentalsScreen` demo)  
- Equipment ownership graph  
- New Admin/control-plane product  
- Second identity of any kind  
- Redesign of finance, analytics, RBAC, CRM

---

## 22. Risks

1. **Treating capabilities as rentals** — organizers think speakers are included; inventory is actually another vendor’s package.  
2. **Quantity API vs package product** — shipping package UX on a qty API without rules will regress to à-la-carte.  
3. **Demo rentals screen** mistaken for production inventory.  
4. **CRM pressure** — implementing V→V services “quickly” would violate freeze and this scope.  
5. **Payment fiction** — showing paid/settled rentals without ledger.  
6. **Mixed `tenant_vendor_categories`** — adding `kind` without a backfill plan leaves DJ and `sound-systems` indistinguishable in filters.  
7. **Vendor-as-buyer event access** — must define *which* events a vendor may attach rentals to (engaged CRM event vs any event) without opening organizer-only APIs incorrectly.  
8. **Attendee rental APIs** — do not repurpose as the vendor-buyer product.  
9. **Stabilization** — any CRM or finance touch needs separate approval.

---

## Scope statement (one paragraph)

Extend the **existing** Vendor ecosystem so a **single** `vendors.id` can be Service Provider, Rental Provider, or both; Super Admin owns typed categories, a resource catalogue, and service default requirements **in Commerce Configuration**; organizers keep CRM for **services** and the rental APIs for **packages**; vendors buy **event-scoped rental packages** through the **existing** `rental_bookings` stack; **do not** modify Vendor CRM, identities, or finance in this initiative; **do not** replace stacks with a unified offering architecture.

---

✅ Vendor Business Types / Services / Rentals Scope Defined
