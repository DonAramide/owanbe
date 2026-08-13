# Vendor Pricing Configuration Completion Report

**Date:** 2026-08-10  
**Status:** Complete  
**Architecture:** Extended existing `platform_vendor_pricing_rules` + `resolveMarkupBps` — no new pricing system.

---

## 1. Architecture changes

- Extended `platform_vendor_pricing_rules` with nullable `vendor_id` → `vendors.id` (canonical vendor identity).
- Centralized deterministic resolution in `resolveMarkupFromRules` (pure util) + `VendorPricingRulesService.resolveMarkupBps(tenantId, serviceKey, vendorId?)`.
- Admin CRUD extended for vendor and vendor+service overrides; existing default/service APIs preserved.
- Marketplace catalog `priceFromMinor` computed server-side: `min(vendor_packages.unit_amount_minor)` × markup → customer price.
- Flutter marketplace no longer invents category fallback prices.
- Control Tower discoverability: **Platform Administration → Commerce Configuration → Open Vendor Pricing** deep-links to the existing `AdminVendorPricingScreen` (no duplicate editor).

```
Admin rules (platform_vendor_pricing_rules)
        │
        ▼
resolveMarkupFromRules / resolveMarkupBps
        │
        ├─ Marketplace browse (customer price from package payout + markup)
        ├─ Vendor CRM create / counter (persist dual prices)
        └─ Funding uses persisted customer_price_minor (historical frozen)
```

---

## 2. Migration details

**File:** `infra/db/064_vendor_pricing_overrides.sql`

| Change | Detail |
|--------|--------|
| Column | `vendor_id UUID NULL REFERENCES vendors(id) ON DELETE CASCADE` |
| Indexes | Partial uniques for service / vendor / vendor+service |
| Data | **No** deletes, **no** rewrites of existing rules or commerce rows |

Apply after `063_multi_service_vendor_commerce.sql`.

---

## 3. Pricing hierarchy implementation

| Priority | `resolvedFrom` | Match |
|----------|----------------|-------|
| 1 | `vendor_service_override` | `vendor_id` + `service_key` |
| 2 | `vendor_override` | `vendor_id`, `service_key` null |
| 3 | `service_category_rule` | `service_key`, `vendor_id` null |
| 4 | `platform_default_rule` | `is_default = true` |
| 5 | `hardcoded_fallback_4000_bps` | 40% safety net |

Documented in util comments, admin list `resolutionOrder`, and Admin UI.

**Identity rule:** Overrides always use `vendors.id`, never `users.id` / auth id. Admin upsert validates vendor belongs to tenant.

---

## 4. Files changed

### Database
- `infra/db/064_vendor_pricing_overrides.sql` (**new**)

### API
- `services/api/src/modules/vendor-operations/vendor-pricing.util.ts`
- `services/api/src/modules/vendor-operations/vendor-pricing-funds.service.ts`
- `services/api/src/modules/vendor-operations/vendor-operations.module.ts` (export `VendorPricingRulesService`)
- `services/api/src/modules/vendor-operations/vendor-crm.service.ts` (pass `vendorId`)
- `services/api/src/modules/platform-admin/admin-vendor-pricing.service.ts`
- `services/api/src/modules/platform-admin/platform-admin.controller.ts`
- `services/api/src/modules/vendors/vendors.service.ts`
- `services/api/src/modules/vendors/vendors.module.ts`
- `services/api/test/vendor-pricing.util.spec.ts`

### Mobile
- `mobile/lib/core/api/admin_vendor_pricing_api.dart`
- `mobile/lib/features/admin/screens/admin_vendor_pricing_screen.dart`
- `mobile/lib/portals/customer/models/marketplace_models.dart`
- `mobile/lib/eos/layout/admin/admin_framework.dart` (Commerce Configuration deep-link)
- `mobile/lib/features/super_admin/executive/executive_overview_screen.dart` (command palette entry)

### Docs
- `docs/VENDOR_PRICING_CONFIGURATION_COMPLETION_REPORT.md` (this file)

---

## 5. APIs changed

| Method | Path | Change |
|--------|------|--------|
| `GET` | `/v1/admin/settings/vendor-pricing-rules` | Returns `vendorRules`, `vendorServiceRules`, updated `resolutionOrder` |
| `PUT` | `/v1/admin/settings/vendor-pricing-rules/default` | Unchanged behavior |
| `PUT` | `/v1/admin/settings/vendor-pricing-rules/service` | Scoped to `vendor_id IS NULL` |
| `DELETE` | `/v1/admin/settings/vendor-pricing-rules/service/:serviceKey` | Scoped to `vendor_id IS NULL` |
| `PUT` | `/v1/admin/settings/vendor-pricing-rules/vendor` | **New** — vendor or vendor+service upsert (`vendorId` = `vendors.id`) |
| `DELETE` | `/v1/admin/settings/vendor-pricing-rules/vendor/:vendorId?serviceKey=` | **New** |
| `GET` | `/v1/vendors` | `priceFromMinor` from pricing engine when packages exist |

Runtime: `resolveMarkupBps(tenantId, serviceKey, vendorId?)` — third arg optional for backward compatibility.

---

## 6. Tables changed

| Table | Change |
|-------|--------|
| `platform_vendor_pricing_rules` | Additive `vendor_id` + partial unique indexes |
| `vendor_event_requests` / funds / negotiations | **Unchanged schema**; historical amounts not rewritten |
| `vendor_packages` | Read-only for marketplace base payout |

---

## 7. Historical price protection

- Admin upsert/delete audit metadata includes `appliesTo: 'future_bookings_only'`.
- No jobs or SQL rewrite `vendor_payout_minor`, `customer_price_minor`, `platform_margin_minor`, allocations, or offers.
- CRM only applies resolution when **creating/updating a new commercial amount** on a request.
- Funding continues to use **persisted** customer prices on the request.

---

## 8. Regression tests

`services/api/test/vendor-pricing.util.spec.ts` — **9 passed**:

- Markup math (40% round-trip)
- Hierarchy: vendor+service → vendor → service → default → 4000 fallback
- Service never wins over vendor+service for same vendor

Also: `tsc --noEmit` clean for API.

### Manual validation checklist

| Check | Expected |
|-------|----------|
| Global default | Used when no higher rule |
| Service rule | Beats default |
| Vendor override | Beats service/default |
| Vendor+service | Beats all above |
| Empty rules | 4000 bps |
| Marketplace | Engine price from packages; no Flutter `_defaultPrice` |
| CRM create/counter | Passes `vendors.id` into resolver |
| Historical rows | Unchanged after rule edits |
| Admin CRUD | Default/service/vendor/vendor+service |
| Auth / RBAC / workspace | Untouched |

---

## Placement

**Single editor:** Platform Admin → Settings → Vendor Pricing Rules  

**Discoverability:** Control Tower → Platform Administration → Commerce Configuration → Open Vendor Pricing  

---

## Final result

✅ Vendor Pricing Configuration Completion COMPLETE
