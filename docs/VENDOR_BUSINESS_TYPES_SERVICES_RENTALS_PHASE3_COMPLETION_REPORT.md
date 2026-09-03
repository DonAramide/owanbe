# Vendor Business Types / Services / Rentals — Phase 3 Completion Report

**Date:** 2026-08-25  
**Mode:** Stabilization — marketplace composition + vendor-as-buyer rentals.  
**Did not implement:** rental ledger/payments, inventory, logistics, unified booking table, Vendor CRM redesign, vendor-to-vendor service requests.

> **Superseding note (2026-08-25):** Vendor → Vendor **service** CRM is implemented in Phase 4 (`POST events/:eventId/vendor-requests/vendor-buyer`, `buyer_kind` / `buyer_vendor_id`). Canonical Marketplace routing was later refined so Vendor Workspace opens `/vendors?vendorBuyer=1` (same `MarketplaceScreen`), not a separate `/vendor/marketplace` product. See Phase 4 completion report and `docs/VENDOR_SERVICES_RENTALS_MARKETPLACE_REFINEMENT_COMPLETION_REPORT.md`. Historical sections below are unchanged.

---

## 1. Unified Marketplace

**PASS**

Organizer `/vendors` is one Marketplace experience with **Services** and **Rentals** tabs. Services still come from the existing vendor marketplace catalogue (`vendor_services` via vendors API). Rentals still come from `GET rentals/catalog` (`rental_catalog_items`). No unified booking table.

---

## 2. Organizer Marketplace

**PASS**

Organizers continue to request services via existing Vendor CRM (`RequestVendorSheet` → `vendor_event_requests`). Rentals continue to use `POST events/:eventId/rentals/bookings`. Package cards show components, fee, and deposit from canonical catalog data. Unavailable stock shows **Unavailable** (no invented inventory).

---

## 3. Vendor Marketplace

**PASS**

Vendor Workspace: `/vendor/marketplace` (dashboard + top bar). Vendor picks an associated event, then opens the same Marketplace with `vendorBuyerMode`. Find Services / Find Rentals are the two tabs. Own packages are hidden in the rental list (server still enforces self-book).

---

## 4. Vendor-as-Buyer

**PASS** (rentals) / **DEFERRED** (services)

Buyer is the authenticated `users.id` stored as `rental_bookings.requester_user_id`. No `buyer_vendor_id` column. Vendor id is derived via existing `vendor_profiles` / `vendors.owner_user_id`. Event remains required.

---

## 5. Rental Vendor booking

**PASS**

`POST events/:eventId/rentals/vendor-buyer-bookings` (authenticated) writes the **existing** `rental_bookings` row. Packages book quantity **1**. Fee/deposit copied from catalog (not marked paid). Existing vendor approve/decline/deliver/return and requester notifications unchanged.

---

## 6. Event authorization

**PASS**

Vendor-buyer bookings require one of:

- existing organizer access to the event (`assertOrganizerOwnsEvent`)
- `vendor_event_participations` (not `rejected`)
- accepted CRM stages (`accepted`, `scheduled`, `arrived`, `completed`)

Otherwise `EVENT_NOT_ASSOCIATED`. Published-but-unrelated events from vendor “discover” are **not** treated as authorization.

---

## 7. Self-book protection

**PASS**

Server-side: if the requester user resolves to a vendor id equal to the catalog provider vendor, `SELF_RENTAL_FORBIDDEN`. Applied on both the public booking path (when `userId` is present) and the vendor-buyer path. UI also hides own packages.

---

## 8. Service Vendor path

**PARTIAL PASS** (browse only; booking deferred)

Vendors can browse Services. `vendor_event_requests.createRequest` still requires `resolveOrganizerId` (`ORGANIZER_REQUIRED`). That contract was **not** weakened. Vendor buyer UI explains that vendor-to-vendor service CRM is unavailable. Organizer → Vendor CRM is unchanged.

---

## 9. API changes

**PASS** (additive)

| Method | Path | Role |
|---|---|---|
| GET | `rentals/catalog` | Now includes `isPackage` + `components` from Phase 2 tables |
| POST | `events/:eventId/rentals/bookings` | Existing; plus self-book reject; packages qty=1 |
| POST | `events/:eventId/rentals/vendor-buyer-bookings` | Authenticated vendor-as-buyer |
| GET | `me/rental-bookings` | Bookings for `requester_user_id` |
| GET | `me/rental-buyer-events` | Eligible events for vendor buyer |

CRM APIs unmodified.

---

## 10. Flutter changes

**PASS**

| Surface | Change |
|---|---|
| `marketplace_screen.dart` | Services / Rentals tabs |
| `marketplace_rentals_screen.dart` | Taxonomy filters, package contents, Unavailable, vendor-buyer book |
| `marketplace_vendor_detail_screen.dart` | `vendorBuyerMode` blocks CRM request |
| `vendor_marketplace_screen.dart` | Event picker + my rental requests |
| `rentals_models.dart` / `rentals_providers.dart` | Package JSON + new endpoints |
| Vendor dashboard / home / router | Marketplace + offerings entry |

---

## 11. Database changes

**PASS** (none required)

No new tables. Relies on `072` (`is_package`, `rental_package_components`) and existing `rental_bookings.requester_user_id`.

---

## 12. Security

**PASS**

Authenticated vendor-buyer route uses `CommerceAuthGuard`. Event association reused from organizer + participation + accepted requests. Self-rental rejected server-side. Package must be `active`. Stock check uses existing `available_quantity` (honest Unavailable). No new RBAC matrix.

---

## 13. Regression

**PARTIAL PASS**

| Check | Result |
|---|---|
| Organizer → Service Vendor | **PASS** (static: CRM createRequest untouched) |
| Organizer → Rental booking | **PASS** (static: existing POST preserved; additive self-book/package qty) |
| Vendor Marketplace access | **PASS** (route + UI) |
| Vendor → Rental Vendor | **PASS** (new endpoint on existing table) |
| Vendor cannot book itself | **PASS** (unit + service) |
| Vendor CRM unchanged | **PASS** (no CRM file edits) |
| Rental engine canonical | **PASS** (same `rental_bookings`) |
| Super Admin taxonomy | **PASS** (rental chips load Phase 1 public categories) |
| Live click-through | **PARTIAL PASS** — not executed this session |

---

## 14. Test results

**PASS** (build + unit; not Live QA)

- Nest `npx nest build` — exit 0  
- Jest `rentals-buyer.util.spec.ts` + `vendor-taxonomy.util.spec.ts` — 6 passed  
- `flutter analyze` on Phase 3 marketplace files — no errors (infos only)  
- `flutter test` `marketplace_rental_package_test.dart` — passed

Minimum matrix:

1. Organizer service — static CRM  
2. Organizer rental — existing booking path  
3. Vendor → rental — new endpoint  
4. Self-book — `isSelfRental` + Forbidden  
5. Unauthorized event — `EVENT_NOT_ASSOCIATED`  
6. CRM regression — no CRM edits  
7. Rental engine — no replacement  

---

## 15. Deferred items

**PASS** (explicit)

- Vendor → Vendor **service** CRM  
- Rental payment / ledger / refunds / settlement  
- Inventory, warehouse, delivery  
- Non-event rentals  
- Unified booking database  
- AI / ratings / ads marketplace  

---

## 16. Known limitations

**PARTIAL PASS**

- Apply migrations `071` and `072` or catalog `is_package` / components fail.  
- Vendor buyer needs a real event association; empty picker is honest.  
- Catalog `available_quantity` is existing SKU math, not component-level inventory.  
- Service request from vendor workspace is explained, not implemented.  
- Live organizer/vendor E2E was not run in this session.

---

## Section scorecard

| Section | Status |
|---|---|
| 1. Unified Marketplace | PASS |
| 2. Organizer Marketplace | PASS |
| 3. Vendor Marketplace | PASS |
| 4. Vendor-as-Buyer | PASS (rentals) |
| 5. Rental Vendor booking | PASS |
| 6. Event authorization | PASS |
| 7. Self-book protection | PASS |
| 8. Service Vendor path | PARTIAL PASS |
| 9. API changes | PASS |
| 10. Flutter changes | PASS |
| 11. Database changes | PASS |
| 12. Security | PASS |
| 13. Regression | PARTIAL PASS |
| 14. Test results | PASS (unit/build) |
| 15. Deferred items | PASS |
| 16. Known limitations | PARTIAL PASS |

---

✅ Vendor Business Types / Services / Rentals Phase 3 Implementation Complete
