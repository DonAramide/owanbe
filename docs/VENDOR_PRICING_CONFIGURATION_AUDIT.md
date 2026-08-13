# Vendor Pricing Configuration — Architecture Audit

**Status:** Audit only — no implementation  
**Date:** 2026-08-10  
**Scope:** Admin Control Tower / Platform Admin pricing configuration  
**Constraint:** Do not change user/organizer/vendor auth, RBAC, or workspace switching

---

## Executive answers

| # | Question | Answer |
|---|----------|--------|
| 1 | Does Vendor Pricing already exist? | **Yes — partial.** Tenant default + service-key markup rules exist end-to-end (DB, API, Admin UI, CRM runtime). |
| 2 | Does markup logic already exist? | **Yes.** Pure util + resolution service + CRM application. |
| 3 | Does Vendor Commerce calculate final prices? | **Yes** on negotiation/funding. **No** on marketplace browse. |
| 4 | Are prices hardcoded? | **Partially.** Markup fallback `4000` bps; marketplace UI uses client category fallbacks; Super Admin Vendor 360 shows placeholder “5% commission”. |
| 5 | Are marketplace prices stored directly? | **Not as list `priceFromMinor`.** Catalog API returns `null`; packages/`starting_price` exist but are not driving browse cards. |
| 6 | Do quotes/contracts use a pricing engine? | **Partial.** Negotiations use the markup util. No separate quote/contract pricing engine. |

**Why you don’t see it on Control Tower:**  
The nav you listed (Overview → Platform Admin) is **Super Admin**.  
**Vendor Pricing Rules** lives under **Platform Admin → Settings → Commerce / Vendor Pricing**, not as a top-level Super Admin tab.

---

## 1. Current pricing architecture

### A. Vendor commerce markup engine (canonical for multi-service CRM)

```
Vendor payout (vendor-facing)
        ↓  + markup_bps
Customer / organizer price (organizer-facing)
        ↓
platform_margin = customer − payout  (never returned to organizer/vendor clients)
```

**Resolution order today:**

1. Service-specific rule (`platform_vendor_pricing_rules.service_key`)
2. Tenant default rule (`is_default = true`)
3. Hardcoded fallback **4000 bps (40%)**

**Applied when:**

- Organizer creates / funds a vendor request (customer amount → derive payout)
- Vendor counters (payout → derive customer price)
- Escrow / event vendor funds use `customer_price_minor`

**Audience rule (already enforced in CRM DTOs):**

- Organizer sees final service / customer price only
- Vendor sees payout only
- Markup % and margin are admin-internal

### B. Parallel concepts (not the same engine)

| Concept | Store | Purpose |
|---------|--------|---------|
| Ticket / booking platform fee | `tenant_finance_settings.ticket_platform_fee_bps`, `vendor_platform_fee_bps` | Fee on ticket/booking subtotal |
| Vendor package list price | `vendor_packages.unit_amount_minor` | Vendor catalog packages |
| Profile display strings | `vendor_profiles.starting_price`, `price_range` (TEXT) | Onboarding/profile copy |
| Marketplace browse price | API `priceFromMinor: null` + mobile `_defaultPrice` | Display-only fallbacks |

These must not be confused with `platform_vendor_pricing_rules`.

---

## 2. Existing files

### Backend — markup engine

| File | Role |
|------|------|
| `services/api/src/modules/vendor-operations/vendor-pricing.util.ts` | `customerPriceFromVendorPayout` / `vendorPayoutFromCustomerPrice` |
| `services/api/src/modules/vendor-operations/vendor-pricing-funds.service.ts` | `VendorPricingRulesService.resolveMarkupBps`; funds |
| `services/api/src/modules/vendor-operations/vendor-crm.service.ts` | Applies markup on create / counter / agreement |
| `services/api/src/modules/vendor-operations/vendor-operations.controller.ts` | Vendor ops routes |
| `services/api/src/modules/platform-admin/admin-vendor-pricing.service.ts` | Admin CRUD |
| `services/api/src/modules/platform-admin/platform-admin.controller.ts` | `GET/PUT/DELETE …/admin/settings/vendor-pricing-rules*` |
| `services/api/test/vendor-pricing.util.spec.ts` | Unit tests |

### Backend — adjacent (fees / catalog)

| File | Role |
|------|------|
| `services/api/src/modules/commerce/tenant-finance-policy.service.ts` | Finance fee BPS |
| `services/api/src/modules/commerce/commerce.types.ts` | `computePlatformFeeMinor` |
| `services/api/src/modules/vendors/vendors.service.ts` | Marketplace catalog; `priceFromMinor: null` |
| `services/api/src/modules/vendors/vendor-packages.service.ts` | Package amounts |

### Frontend — Admin (exists)

| File | Role |
|------|------|
| `mobile/lib/features/admin/screens/admin_vendor_pricing_screen.dart` | **Vendor Pricing Rules** UI |
| `mobile/lib/features/admin/screens/admin_settings_screen.dart` | Entry: Settings → Vendor Pricing Rules |
| `mobile/lib/core/api/admin_vendor_pricing_api.dart` | Admin API client |

### Frontend — Super Admin (no real pricing module)

| File | Note |
|------|------|
| `mobile/lib/features/super_admin/…` | Control Tower tabs only |
| `vendor_360_workspace_screen.dart` | Placeholder “5% Platform commission” — not wired |

### Docs

| File | Note |
|------|------|
| `docs/MULTI_SERVICE_VENDOR_COMMERCE_IMPLEMENTATION.md` | Multi-service commerce + markup context |

---

## 3. Existing tables

### Core pricing config

**Migration:** `infra/db/063_multi_service_vendor_commerce.sql`

```sql
platform_vendor_pricing_rules (
  id, tenant_id, service_key, markup_bps, is_default, created_at, updated_at
)
```

- Default seeded at **4000 bps (40%)** per tenant
- Unique default per tenant
- Unique `(tenant_id, service_key)` for non-null service keys

### Runtime dual prices (per request)

Same migration on `vendor_event_requests`:

- `vendor_payout_minor`
- `customer_price_minor`
- `platform_margin_minor`
- `funding_status`
- Related: `event_vendor_funds`, `vendor_request_fund_allocations`

### Other price-related tables (not markup config)

| Table | Migration | Notes |
|-------|-----------|--------|
| `vendor_packages` | `owanbe_core.sql` | `unit_amount_minor` |
| `bookings` | `owanbe_core.sql` | `subtotal_minor`, `platform_fee_minor`, `pricing_snapshot` |
| `vendor_negotiations` / `vendor_negotiation_offers` | `027_phase_event_v2.sql` | Offer amounts |
| `tenant_finance_settings` | `006_*` / `016_*` | Ticket/vendor fee BPS |
| `vendor_profiles` | `052_vendor_workspace_profile.sql` | `starting_price`, `price_range` TEXT |

---

## 4. Missing pieces (vs desired future model)

Desired hierarchy:

```
Vendor + Service Override
  → Vendor Override
    → Service Category Rule
      → Global Default
```

| Desired | Current | Gap |
|---------|---------|-----|
| Global default markup | Tenant `is_default` | **Met** |
| Service category rules | `service_key` string overrides | **Partial** — not a formal category FK / taxonomy |
| Vendor-specific override | — | **Missing** (`vendor_id` not on rules) |
| Vendor + service override | — | **Missing** |
| Organizer never sees cost / markup % | CRM audience shaping | **Met** for CRM |
| Marketplace shows engine-derived customer prices | Client hardcoded fallbacks | **Missing** |
| Super Admin Control Tower visibility | Only under Platform Admin Settings | **Discovery gap** (not absence of system) |
| Single pricing truth across packages / fees / markup | Three parallel concepts | **Architectural debt** |

---

## 5. Recommended implementation plan (future — do not implement now)

When approved to build, extend the **existing** system; do not invent a second pricing store.

### Phase A — Discoverability (Admin only)

1. Keep source of truth: `platform_vendor_pricing_rules` + `AdminVendorPricingApi`
2. Add a Control Tower / Platform Admin deep-link or top-level **Vendor Pricing** entry that opens the existing `AdminVendorPricingScreen`
3. Replace Vendor 360 “5% commission” placeholder with live default markup readout (read-only or link)

### Phase B — Hierarchy completion

1. Extend rules table (or child table) with optional `vendor_id` (+ optional service key)
2. Update `resolveMarkupBps` order to:

   `vendor+service` → `vendor` → `service_key/category` → `default` → `4000`

3. Keep organizer/vendor DTO redaction unchanged
4. Migrate UI: Default / Category / Vendor overrides tabs on the same Admin screen

### Phase C — Marketplace alignment (optional, separate decision)

1. Stop inventing browse prices in Flutter
2. Either expose package/`starting_price` as customer prices, or apply markup to a declared vendor base for display
3. Never expose markup % on marketplace cards

### Explicit non-goals for this feature

- Do not change organizer/vendor/user auth or workspace switching
- Do not mix ticket `*_platform_fee_bps` into vendor markup rules without a product decision
- Do not redesign Vendor CRM workflows (Phase 14–18 freeze applies to frozen commerce paths; markup config extension should reuse existing CRM apply sites)

---

## 6. Correct Admin module placement

| Placement | Recommendation |
|-----------|----------------|
| **Primary home** | **Platform Admin → Settings → Vendor Pricing Rules** (already exists) |
| **Control Tower** | Optional deep-link under **Platform Admin** destination (Super Admin tab that hosts Admin shell), or a dedicated Settings card — **do not** duplicate APIs |
| **Not recommended** | Separate Super Admin–only pricing DB or parallel “Finance markup” module |

**Correct product naming:**

> Admin Control Tower / Platform Admin → **Vendor Pricing Rules**  
> (Global default + category/service rules + future vendor overrides)

---

## Summary diagram

```
┌─────────────────────────────────────────────────────────┐
│ Admin (Platform Admin → Settings → Vendor Pricing)      │
│  platform_vendor_pricing_rules                          │
│  default + service_key markup_bps                       │
└───────────────────────────┬─────────────────────────────┘
                            │ resolveMarkupBps
                            ▼
┌─────────────────────────────────────────────────────────┐
│ Vendor CRM / Funds                                      │
│  vendor_payout_minor ↔ customer_price_minor             │
│  platform_margin_minor (internal only)                  │
└─────────────────────────────────────────────────────────┘
         │                              │
         ▼                              ▼
   Organizer sees                 Vendor sees
   final Owanbe price only        payout only

Marketplace browse: NOT yet on this engine (client fallbacks).
```

---

## Final audit verdict

**Vendor Pricing Configuration already exists in partial form** and is production-wired for multi-service vendor commerce.  
What is missing is full override hierarchy, Super Admin discoverability, and marketplace price alignment — not a greenfield pricing system.

**STOP — audit complete. No implementation performed.**
