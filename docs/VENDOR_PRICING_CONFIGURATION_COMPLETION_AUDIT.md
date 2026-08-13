# Vendor Pricing Configuration — Completion Sprint Audit

**Status:** Pre-implementation audit only — **DO NOT IMPLEMENT** until approved  
**Date:** 2026-08-10  
**Prerequisite:** `docs/VENDOR_PRICING_CONFIGURATION_AUDIT.md`  
**Rule:** Extend existing architecture. Do not create a parallel pricing system.

---

## Placement recommendation (before any UI change)

| Option | Pros | Cons |
|--------|------|------|
| **A. Keep Platform Admin → Settings → Vendor Pricing Rules** | Already live, wired, audited; single source of truth | Hard to find from Super Admin Control Tower |
| **B. Control Tower → Commerce Configuration → Vendor Pricing** | Matches product discoverability ask | Requires Super Admin nav work; risk of accidental duplicate screens |

**Recommended:**

1. **Keep** Platform Admin Settings screen as the **only** editing UI / API consumer (no duplicate screens).
2. **Add discoverability** from Control Tower → **Platform Admin** shell:
   - Either promote Settings → Vendor Pricing as a visible Commerce card, **or**
   - Add a Control Tower deep-link labeled **Vendor Pricing** that navigates into the existing `AdminVendorPricingScreen`.

Do **not** create a second Super-Admin-only pricing editor.

---

## 1. Current pricing flow diagram

```
┌──────────────────────────────────────────────────────────────────┐
│ ADMIN (Platform Admin → Settings → Vendor Pricing Rules)         │
│  CRUD → platform_vendor_pricing_rules                            │
│  APIs: /v1/admin/settings/vendor-pricing-rules*                  │
└────────────────────────────┬─────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────┐
│ VendorPricingRulesService.resolveMarkupBps(tenant, serviceKey)   │
│  TODAY:  service_key rule → is_default → 4000 bps                │
│  TARGET: vendor+service → vendor → service → default → 4000      │
└────────────────────────────┬─────────────────────────────────────┘
                             │ markupBps
                             ▼
┌──────────────────────────────────────────────────────────────────┐
│ vendor-pricing.util.ts                                           │
│  customer = payout * (10000 + markupBps) / 10000                 │
│  margin   = customer − payout   (internal only)                  │
└────────────────────────────┬─────────────────────────────────────┘
                             │
        ┌────────────────────┼────────────────────┐
        ▼                    ▼                    ▼
┌───────────────┐   ┌────────────────┐   ┌─────────────────┐
│ Vendor CRM    │   │ Negotiations / │   │ Event vendor    │
│ create/counter│   │ “quotes” /     │   │ funds / escrow  │
│ agreement     │   │ stage contract │   │ (customer price)│
└───────┬───────┘   └───────┬────────┘   └────────┬────────┘
        │                   │                     │
        └───────────────────┴─────────────────────┘
                             │
              Persist on vendor_event_requests:
              vendor_payout_minor | customer_price_minor | platform_margin_minor
                             │
        ┌────────────────────┴────────────────────┐
        ▼                                         ▼
 Organizer DTO:                           Vendor DTO:
 final price only                         payout only
 (no markup %, no margin)                 (no customer margin)

MARKETPLACE BROWSE (TODAY — OUT OF ENGINE):
  GET /vendors → priceFromMinor: null
  mobile marketplace_models._defaultPrice(category)  ← REMOVE in completion
```

---

## 2. Existing pricing tables

### Config (extend — do not replace)

**`platform_vendor_pricing_rules`** (`infra/db/063_multi_service_vendor_commerce.sql`)

| Column | Today | Needed for completion |
|--------|-------|------------------------|
| `id` | UUID PK | keep |
| `tenant_id` | required | keep |
| `service_key` | nullable TEXT (normalized label) | keep as category/service key |
| `markup_bps` | 0–9000 | keep |
| `is_default` | one per tenant | keep |
| `vendor_id` | **absent** | **ADD** nullable FK → `vendors(id)` for vendor / vendor+service overrides |
| timestamps | yes | keep |

**Indexes today:** unique default per tenant; unique `(tenant_id, service_key)` where service set.

**Index needs after extension:** unique constraints that allow:

- `(tenant_id)` where `is_default`
- `(tenant_id, service_key)` where `vendor_id IS NULL` and service set
- `(tenant_id, vendor_id)` where `vendor_id IS NOT NULL` and `service_key IS NULL`
- `(tenant_id, vendor_id, service_key)` where both set

### Runtime commerce prices (do not redesign)

On `vendor_event_requests` (063):

- `vendor_payout_minor`
- `customer_price_minor`
- `platform_margin_minor`

Related: `event_vendor_funds`, `vendor_request_fund_allocations`

### Adjacent (out of scope for markup hierarchy — do not merge blindly)

- `tenant_finance_settings.*_platform_fee_bps` — ticket/booking fees
- `vendor_packages.unit_amount_minor` — catalog base amounts
- `vendor_profiles.starting_price` / `price_range` — TEXT profile fields

---

## 3. Existing APIs

| Method | Path | Purpose |
|--------|------|---------|
| `GET` | `/v1/admin/settings/vendor-pricing-rules` | List default + service rules + resolution order |
| `PUT` | `/v1/admin/settings/vendor-pricing-rules/default` | Upsert global default `%` |
| `PUT` | `/v1/admin/settings/vendor-pricing-rules/service` | Upsert service-key rule |
| `DELETE` | `/v1/admin/settings/vendor-pricing-rules/service/:serviceKey` | Delete service rule |

**Runtime (not admin CRUD):**

- `VendorPricingRulesService.resolveMarkupBps(tenantId, serviceKey)`
- CRM create / counter / fund paths in `vendor-crm.service.ts` / `vendor-pricing-funds.service.ts`

**Missing APIs (completion):**

- Upsert / delete **vendor override** (`vendor_id`, no service)
- Upsert / delete **vendor + service override** (`vendor_id` + `service_key`)
- Optionally: `POST` preview endpoint `resolve` for admin testing
- Marketplace/catalog: return engine-derived **customer** `priceFromMinor` (from package/base + markup), never invent in Flutter

---

## 4. Existing UI screens

| Screen | Path | Role |
|--------|------|------|
| **Vendor Pricing Rules** | `mobile/lib/features/admin/screens/admin_vendor_pricing_screen.dart` | Edit default + service markups |
| Settings entry | `mobile/lib/features/admin/screens/admin_settings_screen.dart` | Card → navigate to pricing |
| API client | `mobile/lib/core/api/admin_vendor_pricing_api.dart` | Wired to admin endpoints |
| Super Admin Control Tower | `super_admin_home_screen.dart` + tabs | **No pricing module** |
| Vendor 360 placeholder | `vendor_360_workspace_screen.dart` | Static “5% commission” — disconnect |

**Marketplace hardcodes to remove:**

- `mobile/lib/portals/customer/models/marketplace_models.dart` → `_defaultPrice`, `* 1.35` range when API null

---

## 5. Missing override model

### Rule shapes (logical)

| Rule type | `is_default` | `vendor_id` | `service_key` | Example |
|-----------|--------------|-------------|---------------|---------|
| Global default | `true` | null | null | 40% |
| Service category | `false` | null | `catering` | Catering 40% |
| Vendor override | `false` | set | null | Jollof & Co 25% |
| Vendor + service | `false` | set | `catering` | Jollof catering 20% |

### Resolution (target — never reverse)

```
1. vendor_id + service_key
2. vendor_id only
3. service_key only
4. is_default
5. hardcoded 4000 bps (safety net only)
```

### What exists today

Only rows (1-equivalent without vendor) and (4): service_key + default.

### Data safety

- Do **not** drop or truncate `platform_vendor_pricing_rules`
- Existing default + service rows remain valid after `vendor_id` column added (`NULL`)
- Existing CRM request dual-price columns unchanged
- Changing rules does **not** rewrite historical `vendor_event_requests` prices (current admin service already documents this)

---

## 6. Migration strategy

### DB (additive only)

1. New migration e.g. `064_vendor_pricing_overrides.sql` (name TBD):
   - `ALTER TABLE platform_vendor_pricing_rules ADD COLUMN IF NOT EXISTS vendor_id UUID NULL REFERENCES vendors(id) ON DELETE CASCADE`
   - Drop/replace unique indexes carefully so service-only uniqueness remains when `vendor_id IS NULL`
   - Add partial unique indexes for vendor and vendor+service as above
2. No seed deletion of existing defaults
3. Backfill: none required (overrides are optional)

### API

1. Extend `AdminVendorPricingService` DTOs with `vendorId`, `vendorName?`
2. Extend `listRules` response sections: `defaultRule`, `serviceRules`, `vendorRules`, `vendorServiceRules`
3. Update `resolutionOrder` string array to match target hierarchy
4. Extend `VendorPricingRulesService.resolveMarkupBps(tenantId, serviceKey, vendorId?)`
5. Update CRM call sites to pass `vendor_id` when resolving markup
6. Marketplace/vendors list: compute `priceFromMinor` server-side from catalog base (package min or profile) × markup — **no Flutter invention**

### UI

1. Extend **existing** `AdminVendorPricingScreen` with sections/tabs:
   - Default
   - Service categories
   - Vendor overrides
   - Vendor + service overrides
2. Add Control Tower / Platform Admin deep-link only (no second editor)
3. Remove `_defaultPrice` / client markup simulation from marketplace models

### Consistency verification checklist (post-implementation QA)

| Surface | Must use |
|---------|----------|
| Marketplace browse | Engine-derived customer price |
| Vendor request create | `resolveMarkupBps` + util |
| Negotiation / counter | same |
| Agreement / “contract” stage | persisted customer/payout columns from same util |
| Funding / finance escrow | `customer_price_minor` |
| Organizer UI | final price only |
| Vendor UI | payout only |

---

## 7. Files affected (when approved)

### Database

- `infra/db/064_*.sql` (**new**, additive)

### Backend

- `services/api/src/modules/vendor-operations/vendor-pricing-funds.service.ts` — resolve signature
- `services/api/src/modules/vendor-operations/vendor-crm.service.ts` — pass vendorId into resolve
- `services/api/src/modules/vendor-operations/vendor-pricing.util.ts` — likely unchanged math
- `services/api/src/modules/platform-admin/admin-vendor-pricing.service.ts` — CRUD for overrides
- `services/api/src/modules/platform-admin/platform-admin.controller.ts` — new routes
- `services/api/src/modules/vendors/vendors.service.ts` — marketplace `priceFromMinor`
- `services/api/test/vendor-pricing.util.spec.ts` (+ resolution tests)

### Frontend

- `mobile/lib/core/api/admin_vendor_pricing_api.dart`
- `mobile/lib/features/admin/screens/admin_vendor_pricing_screen.dart`
- `mobile/lib/features/admin/screens/admin_settings_screen.dart` (optional copy only)
- Super Admin discoverability entry (Control Tower / Platform Admin shell) — deep-link only
- `mobile/lib/portals/customer/models/marketplace_models.dart` — remove hardcodes
- Possibly marketplace API models / providers if price shape changes

### Explicitly out of scope

- Auth / RBAC / workspace switching
- Redesign of Vendor CRM, Finance modules, escrow product model
- Deleting or replacing `platform_vendor_pricing_rules`
- Ticket fee BPS policy (`tenant_finance_settings`) unless product later unifies fees vs markup

---

## Summary

| Capability | Status |
|------------|--------|
| Global default | Exists |
| Service category rules | Exists as `service_key` |
| Vendor override | **Missing** |
| Vendor + service override | **Missing** |
| Shared util + CRM apply | Exists |
| Admin UI + APIs | Exists (extend) |
| Marketplace engine parity | **Missing** (client hardcodes) |
| Control Tower discoverability | **Missing** (deep-link preferred) |

**STOP.** Awaiting approval before any migration, API, UI, or marketplace changes.
