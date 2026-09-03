# Admin-Controlled Vendor Capability Model — Report

**Date:** 2026-08-21  
**Verdict:** ✅ ADMIN CONTROLLED VENDOR CAPABILITY MODEL COMPLETE

---

## Investigation (pre-implementation)

### ROOT CAUSE

The previous sprint treated **Optional / Additional** as **Vendor-created Custom Extras** (`vendor_services.custom_extras` + Vendor “Add Custom Extra” UI). That inverted catalogue ownership: Vendors were allowed to invent marketplace offerings outside the Admin catalogue.

### CURRENT MODEL (before this correction)

| Layer | Behavior |
|-------|----------|
| Admin | Single flat capability list per category (`enabled` only) |
| Vendor | Toggle Admin caps **and** create free-form Custom Extras |
| Marketplace | Admin∩Vendor capabilities **+** active/public custom extras |
| Requests | Selected from Admin∩Vendor capabilities only (extras were display-only) |

### INCORRECT PART

1. Vendor Custom Extras editor / `custom_extras` product path  
2. No Admin `core` vs `optional` classification  
3. Organizer/product language implying Vendor-owned catalogue entries  

### MINIMUM FIX (implemented)

1. Add Admin-owned `tier: core | optional` on existing capability JSON (no new catalogue table).  
2. Remove Vendor Custom Extras UI and stop exposing extras on Marketplace.  
3. Vendor UI: **Core Services** + **Additional Services** — ON/OFF only.  
4. Keep `vendor_services.custom_extras` column (unused; **0 rows** had data) — do not drop blindly.  
5. Preserve Admin∩Vendor for profile + request modal; preserve historical `selectedCapabilities`.

---

## 1. Current architecture (after correction)

```
ADMIN (tenant_vendor_categories.metadata.capabilities)
  { key, label, enabled, tier: core|optional }
        ↓
VENDOR (vendor_services.capabilities)
  { key, label, provided }
        ↓
PUBLIC (Marketplace profile + Request modal)
  Admin enabled ∩ Vendor provided
        ↓
CRM REQUEST
  metadata.selectedCapabilities (frozen snapshot)
```

Bookable commercial identity remains `vendor_services` (VS codes, status, `service_key` pricing). Capabilities are offerings/requirements, not a second pricing engine.

---

## 2. Incorrect previous behavior

- Vendor could add Karaoke / MC Services as **Custom Extras** outside Admin catalogue.  
- Marketplace could show those Vendor-invented items.  
- Admin had no Core vs Optional split — only enable/disable.

**Data impact of Custom Extras:** local DB had **0** `vendor_services` rows with non-empty `custom_extras`. Safe to retire the product path without historical rewrite.

---

## 3. Final domain model

| Concept | Owner | Vendor action |
|---------|-------|---------------|
| Category | Admin | — |
| Core capability | Admin create/edit/enable/disable | Provide ON/OFF |
| Optional capability | Admin create/edit/enable/disable | Provide ON/OFF |
| Bookable service (`VS-######`) | Vendor (existing) | Active/inactive for requests |
| Custom Extra catalogue entry | **Removed** | Not allowed |

Public rule (profile + request):

`SHOW / SELECTABLE ⇔ Admin.enabled && Vendor.provided`

Admin OFF → never show / never newly select.  
Existing request snapshots unchanged.

---

## 4. Admin UI

**Control Tower → Commerce Configuration → Service Categories → Category**

- Category active toggle  
- **Core Capabilities** section (enable + move to Optional)  
- **Optional / Additional Capabilities** section (enable + move to Core)  
- Add capability with Core / Optional segmented control  

Vendors never appear as catalogue authors here.

---

## 5. Vendor UI

**General app → Services & Availability** (`/vendor/services`)

Per bookable service:

- Available for Requests  
- **Core Services** — Admin core ∩ enabled → ON/OFF  
- **Additional Services** — Admin optional ∩ enabled → ON/OFF  
- Admin-disabled leftovers: read-only note  

**Removed:** Add Custom Extra / Edit Extra / public-private extras.

---

## 6. Organizer Vendor Profile

Marketplace service card lists every capability from the public API (`Admin ON ∩ Vendor ON`) as “Provided by this vendor”. Core vs Optional is **not** required on this surface — Organizer sees the full offer set.

---

## 7. Organizer Request Modal

`RequestVendorSheet` “Required capabilities” checkboxes bind to the same `service.capabilities` public list. Organizer can only select Admin∩Vendor items. Selections freeze on the CRM request as `selectedCapabilities`.

---

## 8. Database

| Change | Notes |
|--------|-------|
| `070_admin_capability_tier.sql` | Annotates existing capability JSON with `tier` |
| `069 custom_extras` column | **Left in place**, unused by product path |
| No new catalogue table | One Admin catalogue remains |

---

## 9. APIs

| Endpoint | Change |
|----------|--------|
| Admin/public vendor-categories | Capabilities include `tier` |
| Admin PATCH vendor-categories | Persists `tier` |
| `GET /vendors/:id/services` | Capabilities = Admin∩Vendor only; **no customExtras** |
| `PATCH /me/vendor-services/:id` | Capabilities selection unchanged; extras no longer used by UI |
| Request create | Still validates selectedCapabilities against Admin∩Vendor |

---

## 10. Historical-data protection

- Request `selectedCapabilities` snapshots are not rewritten when Admin disables a key.  
- Vendor stored `provided` flags for Admin-disabled keys are preserved on PATCH (read-only in UI).  
- `custom_extras` column retained; no DROP; no request rows referenced Vendor extras.

---

## 11. Files changed

**DB:** `infra/db/070_admin_capability_tier.sql`

**API:**  
`vendor-capability.util.ts`, `event-config.service.ts`, `vendors.service.ts`  
(`vendor-custom-extras.util.ts` retained unused for column compatibility)

**Admin Flutter:**  
`event_config_api.dart`, `admin_vendor_capability_detail_screen.dart`, `commerce_configuration_screen.dart`

**Vendor Flutter:**  
`vendor_service_capability_editor.dart`, `vendor_services_availability_screen.dart`

**Marketplace Flutter:**  
`vendors_api.dart`, `marketplace_vendor_detail_screen.dart`

**Tests:**  
`vendor-availability-capabilities.spec.ts`, `vendor_custom_extras_test.dart` (retargeted to Admin tier model)

---

## 12. Tests

| Suite | Result |
|-------|--------|
| API `vendor-availability-capabilities.spec.ts` | Pass (incl. tier parse) |
| Flutter `vendor_custom_extras_test.dart` | Pass (core/optional + marketplace ∩) |
| Migration 070 applied locally | DJ keys annotated core/optional |

---

## 13. Remaining technical debt

1. Fuzzy category↔service matching can still yield empty Vendor catalogues for oddly named services.  
2. `vendor_services.custom_extras` column and util remain for safe obsolescence — drop only after explicit cleanup approval.  
3. Legacy dual-write `services_offered` vs `vendor_services` unchanged.  
4. Optional: Admin drag-reorder within Core/Optional arrays (order today = array order on save).

---

## Final result

✅ ADMIN CONTROLLED VENDOR CAPABILITY MODEL COMPLETE
