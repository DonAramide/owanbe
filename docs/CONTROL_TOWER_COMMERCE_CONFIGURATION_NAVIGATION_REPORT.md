# Control Tower Commerce Configuration Navigation Report

**Date:** 2026-08-10  
**Scope:** Admin Control Tower visibility + routing + Super Admin RBAC for vendor pricing only  
**Status:** Complete

---

## 1. Files changed

| File | Change |
|------|--------|
| `mobile/lib/eos/navigation/eos_role_destinations.dart` | Added **Commerce Configuration** to Super Admin destinations |
| `mobile/lib/features/super_admin/super_admin_home_screen.dart` | Tab 8 → Commerce hub; Platform Admin → tab 9 |
| `mobile/lib/features/super_admin/screens/commerce_configuration_screen.dart` | **New** hub: Vendor Pricing / Service Categories / Fee Rules |
| `mobile/lib/router/app_router.dart` | Route `/super-admin/commerce/vendor-pricing` → existing `AdminVendorPricingScreen` |
| `mobile/lib/features/admin/screens/admin_vendor_pricing_screen.dart` | Back action for standalone Control Tower route |
| `mobile/lib/features/super_admin/executive/executive_overview_screen.dart` | Command palette → commerce route / tab 8–9 |
| `mobile/lib/eos/layout/admin/admin_framework.dart` | Platform Admin panel deep-link uses same route |
| `services/api/src/common/permission-matrix.ts` | Added `VENDOR_PRICING_ADMIN_ROLES` (includes `super_admin`) |
| `services/api/src/modules/platform-admin/platform-admin.controller.ts` | Vendor-pricing endpoints use `VENDOR_PRICING_ADMIN_ROLES` |

**Not changed:** pricing engine, DB schema, marketplace, CRM, customer/organizer/vendor workspaces, finance calculation endpoints.

---

## 2. Routes added

| Path | Screen |
|------|--------|
| `/super-admin/commerce/vendor-pricing` | Existing `AdminVendorPricingScreen` (single editor) |

Landing `/super-admin` behaviour unchanged (still Control Tower home).

---

## 3. Navigation changes

Super Admin rail order:

0 Overview → 1 Tenants → 2 Finance → 3 Health → 4 Flags → 5 Audit → 6 Analytics → 7 Security → **8 Commerce Configuration** → 9 Platform Admin

**Commerce Configuration** hub:

```
Commerce Configuration
  ├── Vendor Pricing     → /super-admin/commerce/vendor-pricing (existing editor)
  ├── Service Categories → existing AdminVendorCategoriesScreen
  └── Fee Rules          → Coming soon (placeholder)
```

No duplicate pricing UI.

---

## 4. Permission changes

Previous: vendor-pricing APIs used `ADMIN_FINANCE_CONTROL_ROLES` = `admin_super`, `admin_ops` only — **Control Tower `super_admin` was excluded**.

Now:

```ts
VENDOR_PRICING_ADMIN_ROLES = ['super_admin', 'admin_super', 'admin_ops']
```

Applied **only** to:

- `GET/PUT/DELETE /v1/admin/settings/vendor-pricing-rules*`

`ADMIN_FINANCE_CONTROL_ROLES` unchanged (finance power actions not broadened).

---

## 5. Regression checks

| Check | Result |
|-------|--------|
| Login Admin app → `/super-admin` | Unchanged landing |
| See Commerce Configuration in nav | Yes (tab 8) |
| Open Vendor Pricing | Loads existing `AdminVendorPricingScreen` |
| Single editor | Yes — same screen as Settings path |
| Pricing APIs allow `super_admin` | Yes via `VENDOR_PRICING_ADMIN_ROLES` |
| Pricing engine / DB / marketplace | Untouched |
| Customer / organizer / vendor apps | Untouched |

**Manual:** hot-restart `flutter run -t lib/main_admin.dart`, open **Commerce Configuration** → **Vendor Pricing**, confirm rules list/save.

---

## Final result

✅ Control Tower Commerce Configuration Available
