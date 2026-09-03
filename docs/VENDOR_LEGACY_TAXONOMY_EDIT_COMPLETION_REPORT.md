# Vendor Legacy Taxonomy Edit — Completion Report

**Date:** 2026-08-27  
**Scope:** Existing-Vendor Business Type & Offerings reconciliation in Edit Business Profile only.  
**Out of scope:** Marketplace redesign, CRM redesign, mass backfill, QA Pack changes, new onboarding system.

---

## Executive summary

Implemented **Business Type & Offerings** on the existing **Edit Vendor Profile** sheet. Vendors can select **Service Provider** and/or **Rental Provider**, pick canonical categories from Super Admin taxonomy, reconcile legacy labels with confirmation (not blind migration), and save via existing **`PUT /v1/vendors/:id/business-capabilities`** and **`PUT /v1/vendors/:id/offering-categories`**.

Legacy fields (`vendor_profiles.category`, `vendor_profiles.services_offered`, `vendor_services`, packages, bookings) are **not modified** by offerings save.

---

## 1. Legacy compatibility

**Status: PASS**

| Requirement | Result |
|-------------|--------|
| Preserve `vendor_profiles.category` | ✅ Offerings save does not PATCH profile |
| Preserve `vendor_profiles.services_offered` | ✅ Unchanged by offerings APIs |
| Preserve `vendor_services` | ✅ No delete/sync on capability save |
| No mass backfill | ✅ No migration script |
| No blind auto-assign | ✅ High-confidence labels require **Confirm**; ambiguous require explicit choice or **Leave unchanged** |
| No max-3 limit | ✅ No cap in UI or API |

---

## 2. Edit Business Profile

**Status: PASS**

**File:** `mobile/lib/features/vendor/screens/vendor_profile_edit_sheet.dart`

- Added **`VendorBusinessOfferingsEditor`** section after About, before Bookable services.
- Same sheet — no second profile screen.
- Unsaved-changes guard covers offerings draft + existing capability editor.
- Profile save remains separate from offerings **SAVE CHANGES** (explicit save pattern).

---

## 3. Capability management

**Status: PASS**

**File:** `mobile/lib/features/vendor/widgets/vendor_business_offerings_editor.dart`

- Loads active definitions from `EventConfigApi.listPublicBusinessCapabilities()`.
- FilterChips for **Service Provider** / **Rental Provider** (both allowed).
- Persists via `VendorOfferingsApi.putCapabilities`.
- Unchecking a capability clears draft category selections for that kind (does not delete underlying services/packages).

**Backend refinement:** `VendorOfferingsService.putCapabilities` now allows an **empty** capability list (clears assignments) so vendors can return to the prior empty state without API error.

---

## 4. Service category management

**Status: PASS**

- Loads `listPublicOfferingCategories(kind: 'service')` — no hardcoded list.
- Multi-select FilterChips; no artificial maximum.
- Saved only when **Service Provider** is enabled in draft.
- Selecting a service category auto-enables **Service Provider** in draft.

---

## 5. Rental category management

**Status: PASS**

- Loads `listPublicOfferingCategories(kind: 'rental')`.
- Multi-select FilterChips when **Rental Provider** enabled.
- Saved only when **Rental Provider** is enabled in draft.
- Ambiguous legacy **Rentals** resolves via rental category ActionChips (vendor choice).

---

## 6. Legacy mapping

**Status: PASS**

**File:** `mobile/lib/features/vendor/models/vendor_legacy_taxonomy_mapping.dart`

Verified high-confidence aliases against live taxonomy slugs:

| Legacy | Canonical |
|--------|-----------|
| DJ | `service` / `dj` |
| CATERING | `service` / `catering` |
| PHOTOGRAPHY | `service` / `photographer` |

Mapping runs against **live** taxonomy passed from API, not static IDs.

**Tests:** `mobile/test/features/vendor/vendor_legacy_taxonomy_mapping_test.dart` (12 passed).

---

## 7. Ambiguous-value handling

**Status: PASS**

Labels in `ambiguousLegacyLabels` (Rentals, Entertainment, Videography, Equipment rental, etc.) are **never** auto-applied.

- **High confidence:** Confirm / Leave unchanged.
- **Ambiguous / typo (e.g. PHOTPGRAPHY):** Optional suggestion + explicit Confirm, or pick from full service/rental catalogue, or **Neither / leave unchanged**.
- Dismissed labels are session-only; legacy DB fields untouched.

---

## 8. Data preservation

**Status: PASS**

| Asset | On offerings save |
|-------|-------------------|
| `vendor_profiles.category` | Unchanged |
| `vendor_profiles.services_offered` | Unchanged |
| `vendor_services` rows | Unchanged |
| `vendor_packages` / rental packages | Unchanged |
| CRM requests / bookings | Unchanged |
| Marketplace catalogue | Unchanged (still legacy-driven) |

---

## 9. Onboarding compatibility

**Status: PASS**

- **`VendorOnboardingScreen`** unchanged — new vendors still select capabilities + categories during onboarding.
- Existing vendors use **Edit Business Profile** for reconciliation.
- Single onboarding route; no parallel system.

---

## 10. Security

**Status: PASS**

- Reuses existing vendor-owned endpoints guarded by **`VendorOfferingsService.assertOwns`**.
- No admin bypass added.
- No cross-vendor mutation path introduced.

---

## 11. Audit

**Status: PASS**

- Existing `AuditLogService` actions on capability/category PUT unchanged.
- No second audit system.

---

## 12. Regression

**Status: PASS**

| Area | Impact |
|------|--------|
| Marketplace | None — no marketplace files changed |
| CRM | None |
| Organizer flows | None |
| Phases 14–18 frozen flows | Not touched |
| QA Packs 1–25 | Not modified |

---

## 13. Test results

**Status: PASS**

| Command | Result |
|---------|--------|
| `flutter analyze` (changed vendor files) | ✅ No issues |
| `flutter test test/features/vendor/vendor_legacy_taxonomy_mapping_test.dart` | ✅ 12/12 passed |
| `npm run build` (services/api) | ✅ Success |
| `npm test -- --testPathPattern=vendor-offerings` | ✅ 2/2 passed |

### Manual QA checklist (existing vendor e.g. `invify-services`)

| # | Check | Expected |
|---|-------|----------|
| 1 | Legacy data present | category CSV + services_offered intact |
| 2 | Edit profile opens | Business Type & Offerings section visible |
| 3–5 | Service / Rental / Both | Multi-select capabilities work |
| 6–7 | Canonical categories | Loaded from Super Admin API |
| 8 | High-confidence suggestions | DJ, Catering, Photography suggest Confirm |
| 9–10 | Ambiguous / no blind classify | Rentals requires vendor choice |
| 11–12 | Save + refresh | PUT persists; reload shows selections |
| 13 | My Services & Rentals | Unlocks after SERVICE_PROVIDER / RENTAL_PROVIDER saved |
| 14–17 | Existing data | services, packages, CRM, marketplace unchanged |
| 18 | Security | assertOwns on vendor APIs |
| 19 | New onboarding | Still functional |
| 20 | No max-3 | Unlimited category chips |

---

## 14. Deferred items

**Status: N/A**

| Item | Reason |
|------|--------|
| Mass backfill script | Explicitly out of scope — vendor confirmation required |
| Admin assign-capabilities-to-vendor UI | Separate additive feature (QA workaround: re-run onboarding or DB) |
| Marketplace dual-read from taxonomy selections | Marketplace not redesigned in this refinement |
| Replace legacy VendorCatalogType dropdown in profile | Left in place; legacy CSV preserved; taxonomy is authoritative for offerings |
| Auto-link `vendor_services.category_id` on reconcile | Optional follow-up |

---

## Files changed

| File | Change |
|------|--------|
| `mobile/lib/features/vendor/models/vendor_legacy_taxonomy_mapping.dart` | **New** — legacy label analysis + suggestions |
| `mobile/lib/features/vendor/widgets/vendor_business_offerings_editor.dart` | **New** — Business Type & Offerings UI + save |
| `mobile/lib/features/vendor/screens/vendor_profile_edit_sheet.dart` | Integrated editor + dirty guards |
| `mobile/test/features/vendor/vendor_legacy_taxonomy_mapping_test.dart` | **New** — mapping unit tests |
| `services/api/src/modules/vendor-operations/vendor-offerings.service.ts` | Allow empty capability assignment (clear all) |

---

## Section scorecard

| # | Section | Result |
|---|---------|--------|
| 1 | Legacy compatibility | **PASS** |
| 2 | Edit Business Profile | **PASS** |
| 3 | Capability management | **PASS** |
| 4 | Service category management | **PASS** |
| 5 | Rental category management | **PASS** |
| 6 | Legacy mapping | **PASS** |
| 7 | Ambiguous-value handling | **PASS** |
| 8 | Data preservation | **PASS** |
| 9 | Onboarding compatibility | **PASS** |
| 10 | Security | **PASS** |
| 11 | Audit | **PASS** |
| 12 | Regression | **PASS** |
| 13 | Test results | **PASS** |
| 14 | Deferred items | Documented |

---

✅ Legacy Vendor Taxonomy Edit Complete

**STOP.**
