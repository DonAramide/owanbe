# Vendor Core + Additional Services Grouping — Report

**Date:** 2026-08-21  
**Verdict:** ✅ VENDOR CORE + ADDITIONAL SERVICES GROUPING COMPLETE

---

## Investigation

### 1. Existing tier source

Admin catalogue: `tenant_vendor_categories.metadata.capabilities[].tier` (`core` | `optional`).

Public Vendor catalogue load:

`GET /v1/event-config/vendor-categories` → enabled capabilities include `{ key, label, tier }`.

Client model: `VendorCategoryCapability.tier` / `isCore` / `isOptional` in `event_config_api.dart`.

### 2. Current Vendor rendering path

```
VendorServicesAvailabilityScreen
  → VendorServiceCapabilityEditor
    → listVendorCategories()  (Admin enabled catalogue + tier)
    → vendorWorkspaceProfileProvider  (provided flags)
    → group by tier for display only
    → SAVE → PATCH /me/vendor-services/:id { capabilities: [{key,label,provided}] }
```

### 3. Why it looked like one continuous list

Grouping by `tier` already existed in the editor, but section headers used the same white body style as switch titles, so Core and Additional blended into one visual list. Empty-state copy was also generic.

**No missing tier field on the happy path** — presentation-only fix.

---

## Files changed

| File | Change |
|------|--------|
| `mobile/lib/features/vendor/widgets/vendor_service_capability_editor.dart` | Clear CORE / ADDITIONAL section headers; always-visible sections; empty-state copy; `vendorCapabilitiesForTier` helper |
| `mobile/test/features/vendor/vendor_core_additional_grouping_test.dart` | Grouping / order / no-duplicate tests |
| `docs/VENDOR_CORE_ADDITIONAL_SERVICES_GROUPING_REPORT.md` | This report |

---

## UI changes

Per bookable service card:

1. Service name + VS code + Available for Requests (unchanged)  
2. Divider + **CORE SERVICES** (champagne/label style) + “Admin-defined basic services.”  
3. Toggles for `tier != optional` (Admin order preserved)  
4. Divider + **ADDITIONAL SERVICES** + “Admin-defined optional/additional services.”  
5. Toggles for `tier == optional`  
6. Empty sections still show headers with:  
   - “No core services have been configured for this category yet.”  
   - “No additional services have been configured for this category yet.”  

Vendor still only toggles `provided`. No add/delete/rename/tier moves.

---

## API / model changes

**None.** Tier already returned by the existing public categories API and parsed by `VendorCategoryCapability`.

---

## Persistence behavior

Unchanged. Save still PATCHes `{ key, label, provided }` only. Tier is never written by the Vendor.

Admin changing Lighting Optional → Core is reflected after catalogue refresh (editor reloads categories on open; hot restart / reopen Services & Availability after Admin save).

---

## Tests

`flutter test test/features/vendor/vendor_core_additional_grouping_test.dart`

- Split by `capability.tier`  
- Preserve order within each group  
- Tier move has no duplicates  
- Legacy missing tier → Core  

---

## Confirmation — no business logic changed

| Area | Status |
|------|--------|
| Capability IDs / keys | Unchanged |
| PATCH contract | Unchanged |
| Provider / profile fetch | Unchanged |
| Pricing / marketplace / CRM requests | Untouched |
| Admin UI | Untouched |
| Organizer profile / request modal | Untouched |

---

## Final result

✅ VENDOR CORE + ADDITIONAL SERVICES GROUPING COMPLETE
