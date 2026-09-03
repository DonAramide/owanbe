# Vendor Services / Rentals — Canonical Marketplace Refinement

**Date:** 2026-08-25  
**Mode:** Routing and UX refinement only. No new Vendor Services/Rentals phase. No CRM, rental-booking, or Finance redesign.

---

## 1. Canonical Marketplace routing

**PASS**

| Path | Role |
|---|---|
| Organizer Workspace → Marketplace | `/vendors` → existing `MarketplaceScreen` |
| Vendor Workspace → Marketplace | `/vendors?vendorBuyer=1` and, once an associated event is chosen, `/vendors?eventId=<id>&vendorBuyer=1` |
| Legacy `/vendor/marketplace` | Redirects to `/vendors?vendorBuyer=1` (not a product shell) |

`VendorMarketplaceScreen` is removed. Catalogue APIs are unchanged (`marketplaceVendorsProvider` / vendors catalogue; `GET rentals/catalog`).

---

## 2. Vendor buyer context

**PASS**

`vendorBuyer=1` on the canonical route sets `MarketplaceScreen.vendorBuyerMode`. Event context is required for buyer transactions. If the vendor opens Marketplace without `eventId`, the same screen shows an associated-event picker (`GET me/rental-buyer-events`). No event is invented. Buyer service requests still use `POST …/vendor-requests/vendor-buyer`. Buyer rentals still use `POST …/rentals/vendor-buyer-bookings`.

---

## 3. Seller context

**PASS**

When `offering.vendor_id` / marketplace vendor `id` equals the signed-in vendor (`canonicalVendorIdProvider`), Marketplace is seller mode:

- Services: **View Availability** + **Manage** (no Request). Bottom bar **Manage**.
- Rentals: **View** + **Manage** (no Rent). Own packages remain listed.

**Manage** deep-links to existing `/vendor/offerings`. Offering editors are not duplicated in Marketplace.

Ownership uses existing IDs only.

---

## 4. Organizer context

**PASS**

Organizer `/vendors` is unchanged as a buyer: Request Service and Request rental / package. `vendorBuyer` is not set. No seller mode.

---

## 5. Self-procurement UX

**PASS**

UI hides Request/Rent on the current vendor’s offerings. Vendor-buyer Request is blocked until an associated event is selected. Server remains authoritative: `SELF_PROCUREMENT_FORBIDDEN`, `SELF_RENTAL_FORBIDDEN`, `EVENT_NOT_ASSOCIATED`, provider/ownership checks were not removed.

---

## 6. API preservation

**PASS**

No new commercial endpoints. No changes to `vendor_event_requests`, `rental_bookings`, `vendor_services`, `rental_catalog_items`, `buyer_kind`, or `buyer_vendor_id` schema. Routing is Flutter-only.

---

## 7. CRM preservation

**PASS**

Organizer → Vendor create path unchanged. Vendor-buyer path unchanged. Provider inbox unchanged. Outgoing service requests and rental-as-buyer history moved from the deleted vendor hub onto **Vendor CRM Inbox** (`/vendor/crm`), not a second marketplace.

---

## 8. Rental engine preservation

**PASS**

Same `rental_catalog_items` / `rental_bookings` flows. Package qty 1 and availability honesty unchanged.

---

## 9. Regression results

**PASS** (static + unit/analyze/build; not Live E2E)

- Nest `npx nest build` — exit 0  
- Jest `rentals-buyer.util.spec.ts` + `vendor-crm-buyer.util.spec.ts` — 3 passed  
- `flutter analyze` on refinement files — no errors (pre-existing dashboard infos only)  
- `flutter test` `marketplace_offering_context_test.dart`, `marketplace_rental_package_test.dart`, `marketplace_search_test.dart` — passed  

| Check | Result |
|---|---|
| Organizer `/vendors` Services / Rentals | Same `MarketplaceScreen` tabs and organizer APIs |
| Vendor opens `/vendors` with `vendorBuyer=1` | Canonical screen + event picker |
| Vendor event context | Query `eventId` after picker |
| Request another vendor’s service | Existing vendor-buyer CRM |
| Rent another vendor’s package | Existing vendor-buyer rental booking |
| Manage own service/rental | Marketplace seller CTAs → `/vendor/offerings` |
| Cannot request/rent own offering | UI; server guards retained |
| Existing CRM / rentals | Unchanged engines |
| Live E2E | Not claimed |

---

## 10. Documentation correction

**PASS**

Phase 3 completion report is **not rewritten**. A superseding note states: vendor-to-vendor **services** landed in Phase 4; Marketplace entry is now `/vendors?vendorBuyer=1`.

---

## 11. Deferred Finance limitations

**PASS** (unchanged)

Vendor-buyer escrow / confirmAgreement / hold-on-issue remain event-organizer-only. No fake paid state. Inventory, logistics, and unique-key product changes were not in this refinement.

---

## Section scorecard

| Section | Status |
|---|---|
| 1. Canonical Marketplace routing | PASS |
| 2. Vendor buyer context | PASS |
| 3. Seller context | PASS |
| 4. Organizer context | PASS |
| 5. Self-procurement UX | PASS |
| 6. API preservation | PASS |
| 7. CRM preservation | PASS |
| 8. Rental engine preservation | PASS |
| 9. Regression results | PASS (not Live E2E) |
| 10. Documentation correction | PASS |
| 11. Deferred Finance limitations | PASS |

---
