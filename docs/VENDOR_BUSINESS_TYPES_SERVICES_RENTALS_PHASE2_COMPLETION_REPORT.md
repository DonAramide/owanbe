# Vendor Business Types / Services / Rentals — Phase 2 Completion Report

**Date:** 2026-08-25  
**Mode:** Stabilization — additive vendor configuration consuming Phase 1 Super Admin taxonomy.  
**Did not implement:** marketplace unification, vendor-as-buyer, inventory, rental ledger, CRM redesign.

Phase 1 (`071_vendor_taxonomy_configuration.sql`) is unchanged. Vendor remains one identity (`users` → `vendors.id`). Capabilities `SERVICE_PROVIDER` and `RENTAL_PROVIDER` are independent flags.

---

## 1. Vendor onboarding

**PASS**

Existing `VendorOnboardingScreen` is extended, not replaced. Step 2 loads Super Admin definitions via public Phase 1 APIs (`GET event-config/vendor-business-capabilities`, `vendor-offering-categories`, `vendor-resource-catalog`). After profile save, the flow PUTs the vendor’s capability keys and category selections. Hardcoded category chip list was removed.

---

## 2. Capability selection

**PASS**

Vendors select one or both active capability definitions from Super Admin (not mutually exclusive). Validation requires at least one capability. UI labels come from the API. Keys are still the Phase 1 canonical strings (`SERVICE_PROVIDER` / `RENTAL_PROVIDER`) because that is the contract the API returns; they are not a second identity.

Possible states: service only, rental only, both.

---

## 3. Service Provider configuration

**PASS**

When Service Provider is selected, onboarding shows **active** `offeringKind=service` categories from `tenant_vendor_categories`. Workspace **My Services** lets the vendor add a named `vendor_services` row with a service category FK. No duplicate category table.

---

## 4. Rental Provider configuration

**PASS**

When Rental Provider is selected, onboarding shows **active** `offeringKind=rental` categories. Workspace **My Rental Packages** creates packages against those slugs. Existing `rental_catalog_items` / `rental_bookings` are not replaced.

---

## 5. Service Blueprints

**PASS**

`vendor_service_blueprint_resources` stores required (default) master-catalogue resources per `vendor_services` row. Blueprints describe standard delivery requirements. They are **not** inventory and **not** organizer purchases. Optional vs required is supported (`is_required`); quantity logic is not used on blueprints.

---

## 6. Rental Packages

**PASS**

A rental package is a `rental_catalog_items` row with `is_package = true` plus `rental_package_components` (resource × quantity). The commercial offering is the package. Buyer-side “give me 2 speakers” is not implemented. Existing non-package catalog rows default `is_package = false`. Package-level `rental_fee_minor` / `deposit_minor` reuse existing catalog pricing. No payment success, ledger, or Finance wiring.

---

## 7. Resource relationships

**PASS**

Blueprint rows and package components FK to `tenant_vendor_resource_catalog` only. No second master catalogue.

---

## 8. Vendor Workspace

**PASS**

Same vendor workspace. Route `/vendor/offerings` (`VendorMyOfferingsScreen`):

- Service only → My Services  
- Rental only → My Rental Packages  
- Both → both  

Entry points: vendor dashboard tile and top-bar icon. Availability CRM (`/vendor/services`) is unchanged.

---

## 9. API changes

**PASS**

Public (Phase 1, unchanged this phase except already present):

| Method | Path |
|---|---|
| GET | `event-config/vendor-business-capabilities` |
| GET | `event-config/vendor-offering-categories?kind=` |
| GET | `event-config/vendor-resource-catalog` |

Vendor-owned (existing `CommerceAuthGuard` + `EventsAccessService.resolveVendorId` must match path `vendorId`):

| Method | Path |
|---|---|
| GET | `vendors/:vendorId/offerings-config` |
| PUT | `vendors/:vendorId/business-capabilities` |
| PUT | `vendors/:vendorId/offering-categories` |
| GET | `vendors/:vendorId/offering-services` |
| POST | `vendors/:vendorId/services` (creates/upserts `vendor_services` with `category_id`) |
| GET/PUT | `vendors/:vendorId/services/:serviceId/blueprint` |
| GET | `vendors/:vendorId/rental-packages` |
| POST | `vendors/:vendorId/rental-packages` (create or update if `id` present) |

CRM list/create request APIs and rental booking APIs were not redesigned.

---

## 10. Database changes

**PASS**

**File:** `infra/db/072_vendor_offerings_blueprints_packages.sql` (apply after `071`).

| Change | Detail |
|---|---|
| `vendor_business_capability_assignments` | Vendor-selected keys; PK `(vendor_id, capability_key)` |
| `vendor_offering_category_selections` | Vendor-selected taxonomy categories |
| `vendor_services.category_id` | Nullable FK to `tenant_vendor_categories` |
| `vendor_service_blueprint_resources` | Blueprint ↔ master resources |
| `rental_catalog_items.is_package` | Default `false` (existing items preserved) |
| `rental_package_components` | Package definition quantities |

Not replaced: `vendor_event_requests`, `rental_bookings`, identity tables.

---

## 11. Flutter changes

**PASS**

| File | Role |
|---|---|
| `vendor_onboarding_screen.dart` | Capability + taxonomy selection; persist after profile save |
| `vendor_my_offerings_screen.dart` | Services, blueprints, packages |
| `vendor_offerings_api.dart` | Vendor-owned HTTP client |
| `event_config_api.dart` | Public taxonomy lists |
| `app_router.dart` | `/vendor/offerings` |
| `vendor_dashboard_screen.dart` / `vendor_home_screen.dart` | Navigation |

---

## 12. Authorization

**PASS**

Mutations use existing commerce auth. `VendorOfferingsService.assertOwns` compares path `vendorId` to `EventsAccessService.resolveVendorId`. Vendor A cannot write Vendor B’s offerings. No parallel permission matrix.

---

## 13. Audit

**PASS**

Existing `AuditLogService` / `audit_log`:

- `vendor_offerings.capabilities.update`
- `vendor_offerings.categories.update`
- `vendor_offerings.service.upsert`
- `vendor_offerings.blueprint.update`
- `vendor_offerings.package.create` / `.update`

No second audit system.

---

## 14. Regression results

**PARTIAL PASS**

| Check | Result | Evidence |
|---|---|---|
| Organizer → Vendor CRM | **PASS** (static) | `vendor-crm.service.ts` not redesigned |
| Vendor Inbox | **PASS** (static) | Inbox providers/screens not replaced |
| Vendor marketplace | **PASS** (static) | Marketplace unification not started |
| Rental marketplace / booking | **PASS** (static) | `RentalsService` reused for catalog insert; booking engine not replaced |
| Control Plane | **PASS** (static) | Untouched |
| Super Admin taxonomy | **PASS** (static) | Phase 1 admin APIs retained |
| Vendor identity / RBAC | **PASS** (static) | Single vendor id; existing guards |
| Live CRM / rental / marketplace click-through | **PARTIAL PASS** | Not executed in this session |

---

## 15. Test results

**PASS** (compile + targeted unit tests; not Live QA)

Recorded in this session after implementation:

- Nest `npx nest build` — exit 0  
- Jest `vendor-taxonomy.util.spec.ts` + `vendor-offerings.contract.spec.ts` — 6 passed  
- `flutter analyze` on touched files — no errors (infos only)  
- `flutter test` taxonomy + offerings parse — 5 passed

Live QA of onboarding + package booking was **not** performed.

---

## 16. Deferred items

**PASS** (explicitly not built)

- Unified Marketplace redesign  
- Vendor-as-buyer / Vendor → Vendor purchasing or CRM  
- Rental payment / ledger / refunds / settlement  
- Inventory, delivery, warehouse, advanced availability  
- Dynamic package pricing / AI package generation  
- Vendor contracts redesign  
- Finance connection beyond storing catalog fee/deposit fields  

---

## 17. Known limitations

**PARTIAL PASS** (acceptable for Phase 2)

- Migration `072` must be applied or vendor offering APIs fail.  
- Onboarding capability PUT is best-effort after profile save; a silent catch can leave profile complete without assignments until the vendor retries from offerings (operator should apply `072` first).  
- Package quantity on catalog items remains `1` (the package unit); component quantities live on `rental_package_components` only. Existing rental availability math is not inventory of speakers.  
- Blueprint optional resources are checkboxes (required default true); no per-resource quantity on blueprints.  
- Workspace does not deep-edit capabilities after onboarding (re-onboarding / PUT APIs exist).  
- Live Super Admin + Vendor E2E against migrated DB was not run here.

---

## Section scorecard

| Section | Status |
|---|---|
| 1. Vendor onboarding | PASS |
| 2. Capability selection | PASS |
| 3. Service Provider configuration | PASS |
| 4. Rental Provider configuration | PASS |
| 5. Service Blueprints | PASS |
| 6. Rental Packages | PASS |
| 7. Resource relationships | PASS |
| 8. Vendor Workspace | PASS |
| 9. API changes | PASS |
| 10. Database changes | PASS |
| 11. Flutter changes | PASS |
| 12. Authorization | PASS |
| 13. Audit | PASS |
| 14. Regression results | PARTIAL PASS |
| 15. Test results | PASS (unit/build; not Live QA) |
| 16. Deferred items | PASS |
| 17. Known limitations | PARTIAL PASS |

**Overall:** Phase 2 vendor-side configuration is implemented. Apply `071` then `072`. Do not start marketplace unification or vendor-as-buyer.

---

✅ Vendor Business Types / Services / Rentals Phase 2 Implementation Complete
