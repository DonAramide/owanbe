# Service Capability + Vendor Extras — Implementation Report

**Date:** 2026-08-21  
**Verdict:** ✅ SERVICE CAPABILITY + VENDOR EXTRAS COMPLETE  
**Constraint honored:** No third catalogue, no second service engine, no pricing redesign.

---

## 1. Existing architecture reused

| Layer | Source of truth | Role |
|-------|-----------------|------|
| Admin | `tenant_vendor_categories` + `metadata.capabilities` | Marketplace categories + capability catalogue + enable/disable |
| Vendor bookable | `vendor_services` | VS codes, active/inactive, base price, provided capabilities |
| Requests | `vendor_event_requests.metadata.selectedCapabilities` | Frozen historical snapshots |
| Pricing | `service_key` / `platform_vendor_pricing_rules` | Unchanged — capabilities are not a pricing hierarchy |

Additive only:

- `vendor_services.custom_extras` (JSONB) — **Vendor-owned**, not Admin catalogue keys.

---

## 2. Admin UI changes

**App:** Control Tower / Admin (`Commerce Configuration`).

| Screen | Route | Change |
|--------|-------|--------|
| Commerce hub | `/super-admin/commerce` | Clearer copy: categories + capability catalogues share one editor |
| Category list | `/super-admin/commerce/vendor-capabilities` | Renamed framing to Service Categories & Capability Catalogue |
| Category detail | `/super-admin/commerce/vendor-capabilities/:categoryId` | Capability enable/disable + add; **category active** toggle; disable behavior documented in UI |

Admin can:

1. Browse marketplace categories  
2. Manage capability catalogue under each category  
3. Enable/disable capabilities  
4. Activate/deactivate category Marketplace visibility (`is_active`)  
5. See enabled vs total counts on the list  

No second Admin editor was created.

---

## 3. Vendor UI changes

**App:** General Owanbe Vendor workspace — `Services & Availability`.

`VendorServiceCapabilityEditor` now has clearly separated sections per bookable service:

1. **Available for Requests** (existing status toggle)  
2. **Standard Capabilities** — Admin-enabled catalogue only; ON/OFF; cannot rename/delete/invent keys  
3. **Admin-disabled leftovers** — read-only if previously selected; Marketplace hides them  
4. **Custom Extras** — Vendor-owned add/edit/activate; public/private  

Persistence: existing `PATCH /me/vendor-services/:serviceId` extended with `customExtras`.

---

## 4. Custom Extras model

**Storage:** `vendor_services.custom_extras` JSONB (migration `069`).

**Ownership:** `vendors.id` → `vendor_services.vendor_id` → extras (never `user_id` as vendor identity).

**Shape:**

```json
[
  {
    "id": "extra_karaoke",
    "name": "Karaoke",
    "description": "…",
    "priceMinor": 5000000,
    "currency": "NGN",
    "active": true,
    "isPublic": true
  }
]
```

- Not written into Admin `metadata.capabilities`  
- Optional display price only — **not** wired into markup/pricing rules  
- Marketplace shows only `active && isPublic`

---

## 5. APIs

| Endpoint | Change |
|----------|--------|
| `POST /v1/admin/settings/vendor-categories` | Optional `isActive`; capabilities patch unchanged |
| `PATCH /v1/me/vendor-services/:serviceId` | Accepts `customExtras`; capability PATCH preserves Admin-disabled stored decls |
| `GET /v1/vendors/:id/services` | Capabilities = Admin-enabled ∩ Vendor-provided; includes public custom extras |
| `GET /v1/vendors` catalog | Services JSON includes filtered capabilities + public extras |
| `GET /v1/me/vendor-profile` | Returns `customExtras` on each service for Vendor editor |

---

## 6. Database changes

**File:** `infra/db/069_vendor_service_custom_extras.sql`

```sql
ALTER TABLE vendor_services
  ADD COLUMN IF NOT EXISTS custom_extras JSONB NOT NULL DEFAULT '[]'::JSONB;
```

**Apply before using Custom Extras in environments that have not run 069.**

---

## 7. Marketplace changes

Public Vendor service cards show:

1. Standard capabilities (Admin-enabled ∩ Vendor-provided)  
2. Active + public Custom Extras  

Hidden:

- Admin-disabled capabilities  
- Vendor-unselected capabilities  
- Inactive / private extras  

Organizer request flow still selects from public capabilities only (extras are display/commercial notes, not request capability keys).

---

## 8. Search changes

Client `MarketplaceVendor.matchesSearchQuery` / `matchesLabel` now also match:

- capability labels/keys  
- custom extra names/descriptions  
- existing service name / code / category / business name  

Still excludes personal account-holder identity (slug/account name not used as business substitute).

---

## 9. Historical data protection

| Action | Effect |
|--------|--------|
| Admin disables capability | Dropped from public list + new Vendor selection + new organizer selection |
| Vendor still had it selected | Stored `provided` flags preserved on PATCH; Vendor UI shows read-only note |
| Existing requests | `selectedCapabilities` snapshots **not rewritten** |
| Custom extras deactivate | Disappear from Marketplace; row data kept |

---

## 10. Files changed

**DB**

- `infra/db/069_vendor_service_custom_extras.sql`

**API**

- `services/api/src/modules/vendor-operations/vendor-custom-extras.util.ts` (new)
- `services/api/src/modules/vendor-operations/vendor-capability.util.ts`
- `services/api/src/modules/vendors/vendor-services.service.ts`
- `services/api/src/modules/vendors/vendors.service.ts`
- `services/api/src/modules/identity/identity.controller.ts`
- `services/api/src/modules/identity/vendor-profile.service.ts`
- `services/api/src/modules/event-config/event-config.service.ts`
- `services/api/test/vendor-availability-capabilities.spec.ts`

**Flutter Admin**

- `mobile/lib/features/super_admin/screens/commerce_configuration_screen.dart`
- `mobile/lib/features/admin/screens/admin_vendor_categories_screen.dart`
- `mobile/lib/features/admin/screens/admin_vendor_capability_detail_screen.dart`
- `mobile/lib/core/api/event_config_api.dart`

**Flutter Vendor**

- `mobile/lib/features/vendor/screens/vendor_services_availability_screen.dart`
- `mobile/lib/features/vendor/widgets/vendor_service_capability_editor.dart`
- `mobile/lib/features/vendor/models/vendor_workspace_profile.dart`
- `mobile/lib/features/vendor/data/vendor_profile_repository.dart`
- `mobile/lib/core/api/identity_api.dart`

**Flutter Marketplace**

- `mobile/lib/core/api/vendors_api.dart`
- `mobile/lib/portals/customer/screens/marketplace_vendor_detail_screen.dart`

**Tests**

- `mobile/test/features/vendor/vendor_custom_extras_test.dart` (new)

---

## 11. Tests

| Suite | Result |
|-------|--------|
| `services/api` `vendor-availability-capabilities.spec.ts` | Pass |
| `flutter test` `vendor_custom_extras_test.dart` | Pass |
| `marketplace_search_test.dart` | Pass |
| `vendor_services_availability_null_test.dart` | Pass |
| `flutter analyze` (touched files) | Pass |
| `tsc --noEmit` (API) | Pass |

Covered: Admin-enabled ∩ provided, custom extra parse/public filter, marketplace search fields, historical snapshot independence (request parse + no rewrite of disabled keys on public payload).

---

## 12. Remaining technical debt

1. Fuzzy category↔service name matching can still leave empty Standard Capabilities for oddly named services (pre-existing).  
2. Legacy `vendor_profiles.services_offered` dual-write remains for compatibility.  
3. Custom extra optional price is display-only — not booked through CRM pricing.  
4. Catalog list may lag until API restart + migration 069 applied.  
5. No Admin create-new-category UI beyond seeded/ensured core categories (activation toggle only).

---

## Final result

✅ SERVICE CAPABILITY + VENDOR EXTRAS COMPLETE
