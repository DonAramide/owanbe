# Service Capability + Vendor Extras — UI Regression Investigation

**Status:** INVESTIGATION ONLY — no code, schema, or API changes.  
**Date:** 2026-08-21  
**Trigger:** Admin Capability Catalogue visible; Vendor Standard Capabilities + Custom Extras differentiation not observed after migration 069 + API/Flutter restart.

---

## Verdict

**⚠ VENDOR UI IMPLEMENTATION INCOMPLETE**

Not because the Vendor editor widgets are missing from the codebase — they exist and are wired — but because the required Vendor differentiation is **not reliably visible in the app the operator is using**, and the Vendor screen **suppresses both sections** when the account has no bookable `vendor_services` rows. Live Vendor-session confirmation against the currently authenticated Vendor was not established in this investigation (active Control Tower session is Admin-only).

---

## 1. Exact Vendor UI location

| Piece | Location |
|--------|----------|
| Screen | `VendorServicesAvailabilityScreen` |
| File | `mobile/lib/features/vendor/screens/vendor_services_availability_screen.dart` |
| Route | `/vendor/services` (nested under `/vendor` in `mobile/lib/router/app_router.dart`) |
| Entry points | Vendor home top-bar icon (`vendor_home_screen.dart`); dashboard card “SERVICES & AVAILABILITY” (`vendor_dashboard_screen.dart`) |
| Widget | `VendorServiceCapabilityEditor` (`mobile/lib/features/vendor/widgets/vendor_service_capability_editor.dart`) |
| Provider | `vendorWorkspaceProfileProvider` → `VendorProfileRepository.fetch()` → `GET /v1/me/vendor-profile` |
| Also embedded | Edit Profile sheet (`vendor_profile_edit_sheet.dart`) — same editor |

**Application separation:**

| Entrypoint | Binary | What you get |
|------------|--------|--------------|
| `flutter run -t lib/main_admin.dart` | Control Tower / Admin | Commerce → Service Categories → Capability Catalogue |
| `flutter run` / `lib/main.dart` | General Owanbe app | Vendor Workspace → Services & Availability |

**Observed runtime:** Terminal `1.txt` is actively running `flutter run -t lib/main_admin.dart`. That process can show Admin DJ · Capability Catalogue. It is **not** the Vendor workspace UI for Standard Capabilities / Custom Extras.

---

## 2. Whether Standard Capabilities UI exists

**Yes — in Vendor code only.**

In `VendorServiceCapabilityEditor.build`, once `data.services` is non-empty, each service card includes:

- Heading: **`Standard Capabilities`**
- Copy: Admin catalogue; toggle what you provide; cannot invent keys
- Controls: `SwitchListTile` per Admin-enabled capability (`provided` on/off)
- Orphaned Admin-disabled selections: read-only switches with explanation

Source lines (editor): section title `"Standard Capabilities"` and catalogue-driven switches.

---

## 3. Whether Custom Extras UI exists

**Yes — in Vendor code only.**

Same editor, per service card:

- Heading: **`Custom Extras`**
- **Add** → dialog (name, description, optional price, active, public)
- **Edit** → same dialog
- Active toggle on each row
- Public/private in dialog (`isPublic`)
- Persisted via **SAVE CHANGES** → `PATCH /me/vendor-services/:id` with `customExtras`

Empty extras still show the section + “No custom extras yet.” + Add.

---

## 4. Exact provider / API / data path

```
VendorServicesAvailabilityScreen
        ↓
VendorServiceCapabilityEditor
        ↓
vendorWorkspaceProfileProvider
        ↓
GET /v1/me/vendor-profile
        ↓
VendorProfileService.toView
        ↓
VendorServicesService.listForVendor (includeInactive)
        ↓
vendor_services
  - capabilities JSONB   (Vendor provided flags)
  - custom_extras JSONB  (migration 069)
        ↓
SAVE: PATCH /v1/me/vendor-services/:serviceId
  body: { status?, capabilities?, customExtras? }

Standard Capabilities catalogue (read-only source):
        ↓
EventConfigApi.listVendorCategories()
        ↓
GET /v1/event-config/vendor-categories
        ↓
tenant_vendor_categories.metadata.capabilities
  (enabled-only for Vendor selection)
```

Marketplace public path (separate):

```
GET /v1/vendors/:vendorId/services
  capabilities = Admin-enabled ∩ Vendor-provided
  customExtras = active && isPublic
        ↓
MarketplaceVendorService (Flutter)
        ↓
marketplace_vendor_detail_screen (“Provided by this vendor” / “Custom extras”)
```

---

## 5. Why the differentiation is not visible

### Primary cause (matches what you described)

**B — UI exists but you are on the Admin Capability Catalogue route, not the Vendor Services screen.**

What you listed (DJ · Capability Catalogue, Category active, Sound System / Microphones / … checkboxes) is **exactly** `AdminVendorCapabilityDetailScreen` under Control Tower. That screen is **Admin catalogue management**. It must **not** show Vendor “what I provide” toggles or Custom Extras. Separation is correct.

Active Flutter process: **`main_admin.dart`**. Vendor differentiation lives in **`main.dart` → `/vendor/services`**.

### Secondary cause (if Vendor app was opened)

**G + F — Conditional empty-state hides both sections.**

```dart
if (services.isEmpty) {
  return EosSurfaceCard(
    child: Text('No bookable services yet. Add service labels in Edit Profile…'),
    // + optional Open Edit Profile
  );
}
```

When `GET /me/vendor-profile` returns `services: []`:

- **No** “Standard Capabilities” heading  
- **No** “Custom Extras” heading  
- **No** Add Custom Extra  

So a Vendor with only profile labels not synced into `vendor_services` (or zero rows) will look like the feature was never built.

### Ruled out / not primary

| Code | Finding |
|------|---------|
| A | Wired: screen → editor → provider → API → `vendor_services` |
| C | Provider is standard FutureProvider; empty list is valid data, not a load failure |
| D | API maps `customExtras` from `custom_extras`; PATCH accepts `customExtras` |
| E | Migration **069 is present** in local DB (`vendor_services.custom_extras` exists) |
| H | Not backend-only; Flutter Vendor UI + Marketplace display code exist |
| Feature flag | None found |

### Sample data check (DB)

Vendor `ddaf7c26-…` (known live marketplace vendor) has bookable services (`DJ`, `CATERING`, `PHOTOGRAPHY`) with capability JSON; `custom_extras` length 0. For **that** Vendor, opening `/vendor/services` in **`main.dart`** should show Standard Capabilities (matched to Admin DJ catalogue) **and** Custom Extras (empty + Add). Extras length 0 does **not** hide the Custom Extras section.

---

## 6. Whether migration 069 is correctly wired

| Check | Result |
|-------|--------|
| Column `vendor_services.custom_extras` | Present (`jsonb NOT NULL DEFAULT '[]'`) |
| API SELECT/UPDATE/map | Present in `vendor-services.service.ts` |
| Profile response includes `customExtras` | Present in `vendor-profile.service.ts` `toView` |
| Flutter model parse | `VendorServiceEntity.customExtras` |
| Flutter PATCH | `IdentityApi.patchVendorService(..., customExtras:)` |

**069 is correctly wired.** Missing Custom Extra **rows** is expected until a Vendor adds them; that is not a migration failure.

---

## 7. Admin vs general-user separation

| Concern | Status |
|---------|--------|
| Admin catalogue in Control Tower | Yes — `/super-admin/commerce/vendor-capabilities` |
| Vendor selection + extras in Vendor workspace | Yes — `/vendor/services` in general app |
| Vendor controls inside Admin Capability Catalogue | **No** (correct) |
| Admin catalogue editor inside Vendor screen | **No** (correct; Vendor only consumes enabled catalogue via public categories API) |
| Entrypoints | `main_admin.dart` (`SharedBootstrap.isAdmin = true`) vs `main.dart` (`isAdmin = false`) |

**Separation is correct.** Looking for Vendor differentiation inside Admin DJ catalogue will always fail by design.

---

## 8. Exact files responsible

**Vendor visibility**

- `mobile/lib/features/vendor/screens/vendor_services_availability_screen.dart`
- `mobile/lib/features/vendor/widgets/vendor_service_capability_editor.dart` (**empty-services early return**)
- `mobile/lib/features/vendor/providers/vendor_profile_providers.dart`
- `mobile/lib/features/vendor/models/vendor_workspace_profile.dart`
- `mobile/lib/core/api/identity_api.dart`
- `mobile/lib/router/app_router.dart` (`/vendor/services`)

**Admin (what you are seeing)**

- `mobile/lib/features/admin/screens/admin_vendor_capability_detail_screen.dart`
- `mobile/lib/features/admin/screens/admin_vendor_categories_screen.dart`
- `mobile/lib/main_admin.dart` / `bootstrap_admin.dart`

**API / DB**

- `infra/db/069_vendor_service_custom_extras.sql`
- `services/api/src/modules/vendors/vendor-services.service.ts`
- `services/api/src/modules/identity/vendor-profile.service.ts`
- `services/api/src/modules/vendors/vendors.service.ts` (marketplace filter)

**Marketplace**

- `mobile/lib/portals/customer/screens/marketplace_vendor_detail_screen.dart`
- `mobile/lib/core/api/vendors_api.dart`

---

## 9. Minimum fix required (do not implement in this sprint)

1. **Operational (no code):** Open general app — `flutter run` / `lib/main.dart` — sign in as Vendor → Services & Availability (`/vendor/services`). Do not expect Vendor toggles on Admin DJ · Capability Catalogue.
2. **Data prerequisite:** Ensure the Vendor has ≥1 `vendor_services` row (Edit Profile → add service labels → save, or existing sync). Empty `services` hides both sections.
3. **Small UX fix (if product requires sections always visible):** Soften or remove the `services.isEmpty` early return so Standard Capabilities / Custom Extras scaffolding (or an inline “create first bookable service”) appears without leaving the screen. That is the only code gap that makes the feature look unimplemented for zero-service Vendors.
4. **Verify Marketplace** after Vendor toggles + adds a public active extra: refresh Vendor detail; confirm Admin-disabled / unselected / inactive extras stay hidden.

---

## Step checklist answers

| Step | Answer |
|------|--------|
| 1 Vendor UI | `/vendor/services` + `VendorServiceCapabilityEditor` — sections exist in code |
| 2 Data path | Profile → `vendor_services.capabilities` + `custom_extras` — wired |
| 3 Custom Extras controls | Add/Edit/Active/Public/Save exist; hidden only when `services.isEmpty` or wrong app |
| 4 Standard Capabilities | Loaded from Admin-enabled categories; toggle `provided` only |
| 5 Why not visible | **B** primary (Admin app / Admin screen); **G+F** secondary (empty services gate) |
| 6 Real Vendor session | Not verified in Admin-running terminal; DB sample vendor would show sections in Vendor app |
| 7 Marketplace | Intersection + public extras implemented in API/UI; extras empty until Vendor adds |
| 8 Separation | Correct; do not put Vendor controls in Control Tower |

---

## Final result

**⚠ VENDOR UI IMPLEMENTATION INCOMPLETE**

(Code for Standard Capabilities + Custom Extras exists and is API-wired; required Vendor differentiation is not verified visible under the current Admin-entrypoint observation, and is fully suppressed by the empty-`vendor_services` UI gate.)

**STOP. No implementation in this investigation.**
