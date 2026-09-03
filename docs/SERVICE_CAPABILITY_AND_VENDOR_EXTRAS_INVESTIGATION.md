# Service Capability and Vendor Extras — Investigation

**Status:** INVESTIGATION ONLY — no implementation, migrations, APIs, or UI changes.  
**Date:** 2026-08-20  
**Scope:** Admin service/capability catalogue, Vendor services & capabilities, Marketplace display, pricing and historical dependencies.

---

## Verdict (Step 12)

**A. Existing systems can be unified with a small additive change.**

Why:

- The desired product model is **already largely implemented** as two intentional layers, not two competing engines:
  1. **Admin catalogue** = marketplace **service categories** + per-category **capability definitions** (equipment / inclusions).
  2. **Vendor selection** = first-class **bookable services** (`vendor_services`) + per-service **provided** capability flags.
- Marketplace / request flows already show **only** active vendor services and **admin-enabled ∩ vendor-provided** capabilities.
- There is **no** separate Vendor “custom extras” entity today. Free-text **service names** can be invented; free-text **capability keys** cannot (server rejects them).
- Remaining gaps are additive (terminology, optional custom-extra policy, core/optional flags, cleanup of legacy `services_offered` / packages fallback)—not a rebuild.

Do **not** invent a third catalogue. Prefer clarifying and lightly extending the existing Admin→Vendor→Marketplace path.

---

## 1. Existing Admin service system

### What it actually is

The Admin UI labeled “Service Categories” / “Vendor Capabilities” manages **tenant marketplace categories** and nested **capability catalogues**. It is **not**:

- a bookable product SKU table
- a package table
- a pricing rules editor (pricing is a separate Control Tower screen)

It **is**:

| Concept | Representation |
|--------|----------------|
| Marketplace service category | `tenant_vendor_categories` row (`dj`, `catering`, …) |
| Capability / inclusion / equipment | JSON array in `tenant_vendor_categories.metadata.capabilities` |
| Admin on/off for a capability | `enabled: true\|false` on that JSON entry |
| Category visibility | `tenant_vendor_categories.is_active` |

Admin does **not** create the bookable “DJ service” for a vendor. Vendors create/activate `vendor_services` rows. Admin defines which **capability options** may appear under a category slug that matches a vendor service.

### UI / routes / providers

| Piece | Location |
|-------|----------|
| Hub | `CommerceConfigurationScreen` → `/super-admin/commerce` |
| List | `AdminVendorCategoriesScreen` → `/super-admin/commerce/vendor-capabilities` |
| Detail (toggle / add capabilities) | `AdminVendorCapabilityDetailScreen` → `/super-admin/commerce/vendor-capabilities/:categoryId` |
| Provider | `adminVendorCategoriesProvider` in `admin_vendor_categories_screen.dart` |
| Client | `EventConfigApi.adminListVendorCategories` / `adminSaveVendorCategoryCapabilities` |

Copy on the list screen states the intended model explicitly: *Admin enables capabilities. Vendors declare what they provide. Organizers request from that list.*

### APIs / controllers / services

| Method | Route | Behaviour |
|--------|-------|-----------|
| GET | `/v1/event-config/vendor-categories` | Public/tenant list: **active categories only**; capabilities filtered to **enabled** |
| GET | `/v1/admin/settings/vendor-categories` | Admin list: all categories + full capability defs (enabled + disabled) |
| POST | `/v1/admin/settings/vendor-categories` | Patch capabilities JSON for one category `id` |

Implemented in:

- `services/api/src/modules/event-config/event-config.controller.ts`
- `services/api/src/modules/event-config/event-config.service.ts` (`listVendorCategories`, `adminListVendorCategories`, `adminPatchVendorCategoryCapabilities`)
- Shared parse helpers: `vendor-capability.util.ts`

### Database

**Table:** `tenant_vendor_categories` (`infra/db/027_phase_event_v2.sql`)

| Column | Role |
|--------|------|
| `id` | UUID PK |
| `tenant_id` | Tenant scope |
| `slug` / `label` | Category identity (e.g. `dj` / `DJ`) |
| `icon_key`, `sort_order` | UI |
| `is_active` | Category-level activation |
| `metadata` | Added in `068_vendor_availability_and_capabilities.sql` |

**Capability shape (in metadata):**

```json
{
  "capabilities": [
    { "key": "sound_system", "label": "Sound System", "enabled": true },
    { "key": "led_screen", "label": "LED Screen", "enabled": false }
  ]
}
```

Seeded defaults for DJ / photographer / catering / decorator / drinks exist in migration `068`.

### Activation / toggle logic

- **Capability disabled by Admin** → omitted from public `GET event-config/vendor-categories`; Vendor editor only lists enabled catalogue items; Vendor PATCH rejects unknown/disabled keys (`CAPABILITY_INVALID`); Organizer cannot newly select them (`allowedCapabilitySet`).
- **Does not** automatically strip already-stored `vendor_services.capabilities` rows or historical request snapshots.
- **Category `is_active = false`** → hidden from public category list; admin list still returns it.

### Tenant / global scope

**Tenant-scoped.** Categories and capability catalogues are per `tenant_id`, with seed/ensure helpers on read.

### Core / optional / recommended

**Not present.** Only `enabled` boolean. No `required`, `core`, `optional`, or `recommended` fields.

---

## 2. Existing Vendor service system

### Bookable services (first-class)

**Table:** `vendor_services` (`infra/db/065_vendor_services.sql` + `066` price + `068` capabilities)

| Column | Role |
|--------|------|
| `id` | Bookable service UUID |
| `service_key` / `service_name` | Normalized key + display name |
| `service_code` | Human code `VS-######` |
| `status` | `active` \| `inactive` \| `archived` — **Available for Requests** |
| `base_payout_minor` / `currency` | Vendor base price |
| `capabilities` | JSONB vendor declarations `{ key, label, provided }` |
| Unique | `(vendor_id, service_key)` |

**UI:**

- `VendorServicesAvailabilityScreen` (`/vendor/...` services & availability)
- `VendorServiceCapabilityEditor` (embedded there and in profile edit)
- Profile onboarding / edit still syncs free-text **Services Offered** labels

**API (examples):**

- List/sync via identity vendor profile (`servicesOffered` → `VendorServicesService.syncFromOfferedLabels`)
- `PATCH` owned service status + capabilities (`VendorServicesService.patchOwnedService`)
- Public marketplace: `GET /vendors/:vendorId/services`

### Legacy label list

**Column:** `vendor_profiles.services_offered` (JSONB string array, migration `052`)

Still written on profile upsert and used as search/fallback when entity list is empty. Comment in `065`: kept for compatibility; **canonical bookable identity is `vendor_services`**.

### Vendor capabilities (selection)

Vendors do **not** invent capability keys. Flow:

1. Load Admin catalogue for matching category (`listVendorCategories` → enabled caps).
2. Match category ↔ service via slug/label/name stem (`categoryMatchesService`).
3. Vendor toggles `provided` per key.
4. Persist on `vendor_services.capabilities`.
5. Server re-validates against Admin-enabled catalogue on PATCH.

### Packages (older commercial surface)

**Table:** `vendor_packages` — named packages with `unit_amount_minor`. Still used as **price fallback** when `base_payout_minor` is null (name match). Not the capability system.

---

## 3. Existing Vendor extras system

**Finding: there is no dedicated “Vendor Custom Extras” product entity.**

| Desired “extra” | Current reality |
|-----------------|-----------------|
| Custom bookable offering | Vendor can add arbitrary **service names** via `servicesOffered` → upserted into `vendor_services` with a derived `service_key` |
| Custom capability / inclusion | **Blocked** — keys must exist and be Admin-enabled for a matching category |
| Separate extras table / pricing / visibility flags | **Does not exist** |
| Public/private extra flags | **Does not exist** |

So “extras” today = **custom service labels**, not a second catalogue under a service.

---

## 4. Marketplace data flow

```
Vendor profile / vendor_services (active)
        ↓
GET /vendors  (catalog)  +  GET /vendors/:id/services?from&to
        ↓
VendorsService.listCatalog / listVendorServices
  - services from vendor_services (active)
  - capabilities: providedVendorCapabilities(...)
  - price: base_payout_minor → markup → customer price
        ↓
MarketplaceVendor / MarketplaceVendorService (Flutter)
        ↓
Filters: category / city / query / rating / price
  (marketplace_filters.dart — category matches servicesOffered / services)
        ↓
Vendor detail: Services Offered cards
  - capability checklist (“Provided by this vendor”)
  - Request sheet: Organizer selects from provided ∩ enabled
        ↓
POST vendor-requests with selectedCapabilities
  - validated; snapshot frozen on request metadata
```

### Sources Marketplace actually reads

| Source | Used for |
|--------|----------|
| `vendor_services` | Primary bookable list, codes, prices, provided capabilities |
| `vendor_profiles.services_offered` | Search/filter fallback / legacy offered labels |
| `tenant_vendor_categories` | Indirect: capability allow-list when building public capability lists and validating requests |
| `platform_vendor_pricing_rules` | Markup for customer-facing price |
| `vendor_packages` | Price fallback by name match |
| Hardcoded / mock | Marketplace category chip fallbacks in providers when API fails; not the live services path |

Marketplace does **not** list Admin-disabled capabilities, and does **not** invent capabilities the vendor did not mark `provided`.

---

## 5. Database tables (summary)

| Table | Domain role |
|-------|-------------|
| `tenant_vendor_categories` | Admin marketplace categories + capability catalogue (metadata) |
| `vendor_services` | Vendor bookable services + provided capabilities |
| `vendor_profiles.services_offered` | Legacy string list |
| `vendor_packages` | Optional package prices |
| `vendor_event_requests` | Bookings; `service_key`, `vendor_service_id`, metadata.selectedCapabilities |
| `platform_vendor_pricing_rules` | Markup by service_key / vendor / default |

---

## 6. APIs (summary)

| Area | Endpoints |
|------|-----------|
| Admin catalogue | `GET/POST admin/settings/vendor-categories`, `GET event-config/vendor-categories` |
| Vendor profile / services | Identity vendor profile upsert (`servicesOffered`), vendor-services PATCH |
| Marketplace | `GET /vendors`, `GET /vendors/:vendorId/services` |
| Requests | `POST …/vendor-requests` (+ capability validation & snapshot) |
| Pricing | Separate Admin vendor pricing routes (unchanged by capability toggles) |

---

## 7. Providers / repositories

| Layer | Key types |
|-------|-----------|
| Admin Flutter | `adminVendorCategoriesProvider`, `EventConfigApi` |
| Vendor Flutter | `VendorServiceCapabilityEditor`, `vendorProfileRepositoryProvider`, workspace profile models |
| Marketplace Flutter | `marketplaceVendorsProvider`, `marketplaceVendorServicesProvider`, `marketplaceVendorServicesForEventProvider`, `marketplaceVendorServicesForRangeProvider` |
| API | `EventConfigService`, `VendorServicesService`, `VendorsService`, `VendorCrmService`, `vendor-capability.util.ts` |

---

## 8. Duplicate / overlapping concepts

| Overlap | Nature | Risk |
|---------|--------|------|
| `services_offered` vs `vendor_services` | Same “what I offer” at two storage layers | Search/display drift if not synced |
| `vendor_packages` vs `base_payout_minor` | Two price sources | Fallback by name match can surprise |
| Admin **category** vs Vendor **service** | Related by fuzzy slug/name match, not FK | Mis-match if vendor names “Wedding Buffet” vs category `catering` |
| UI labels “Service Categories” vs “Vendor Capabilities” | Same route, different cards | Operator confusion, not data duplication |
| Capability keys vs service_key | Both use similar normalization | Different domains; do not merge tables |

**Not duplicates:** Admin capability catalogue vs Vendor bookable services — layered by design.

---

## 9. Historical data dependencies

| Consumer | Dependency | Effect of Admin disable |
|----------|------------|-------------------------|
| `vendor_event_requests.service_key` / `vendor_service_id` | Bookable service identity | **Unaffected** by capability toggle |
| `metadata.selectedCapabilities` | Frozen snapshot at request create | Historical labels remain; new requests cannot select disabled caps |
| Negotiations / contracts / escrow | Driven by request stage & money fields | **No** catalogue FK |
| Tickets | Event ticketing | **Independent** |
| Pricing rules | `service_key` on markup rules | Capability disable does **not** remove pricing rules |

Changing/disabling a catalogue capability does **not** rewrite history. It only constrains **new** vendor declarations and **new** organizer selections.

Deleting or renaming a **vendor_service** / `service_key` can affect requests and pricing lookups — treat as high blast radius; out of scope for catalogue toggles.

---

## 10. Pricing relationship

```
vendor_services.base_payout_minor (or package fallback)
        ↓
platform_vendor_pricing_rules (default → service_key → vendor → vendor+service)
        ↓
customer-facing price on marketplace / request snapshot
```

- Capability catalogue **does not** drive markup.
- Commerce Configuration UI separates **Vendor Pricing** from **Vendor Capabilities**.
- Do **not** add a second pricing relationship for capabilities unless product explicitly prices inclusions later.

---

## 11. Recommended unified architecture (evaluate only — do not implement)

Align naming with what already exists:

```
ADMIN SERVICE CATEGORY CATALOGUE
  tenant_vendor_categories
  + metadata.capabilities[{ key, label, enabled }]
        ↓
VENDOR BOOKABLE SERVICES
  vendor_services (active/inactive, VS code, base price)
        ↓
VENDOR CAPABILITY SELECTION
  vendor_services.capabilities[{ key, label, provided }]
  ⊆ Admin-enabled ∩ category match
        ↓
(OPTIONAL LATER) VENDOR CUSTOM EXTRAS
  New additive fields OR tightly governed free-text
  — not present today for capabilities
        ↓
PUBLIC MARKETPLACE / REQUESTS
  Active services + provided capabilities
  Selected capabilities frozen on request
```

This matches the target concept with one clarification: **bookable service** and **capability** must stay distinct. “Wedding DJ” as a **service** vs “Sound System” as a **capability** should not be collapsed into one table without a deliberate redesign.

---

## 12. Migration considerations (future only)

If unifying further:

1. Prefer migrating remaining display off `services_offered` once all vendors have `vendor_services`.
2. Prefer `base_payout_minor` over package name-fallback for new pricing UI.
3. Optional: add FK or explicit `category_slug` on `vendor_services` to replace fuzzy `categoryMatchesService`.
4. Optional: capability `kind` / `required` flags — additive metadata only.
5. Optional: vendor custom extras — **new** policy; requires product rules (moderation, search, pricing).

No migration required to “turn on” the Admin→Vendor→Marketplace capability path; it already runs.

---

## 13. Files that would need changing (only if implementing later)

**Likely (small additive):**

- `event-config.service.ts` / Admin detail UI — core/optional flags or category CRUD if product requires
- `vendor-capability.util.ts` / `VendorServicesService` — custom extras allow-list policy
- Marketplace copy / docs for clearer naming
- Optionally deprecate dual write of `services_offered`

**Do not need rewriting for the stated product model:**

- Availability engine
- Escrow / wallet / pricing rule engine
- Request stage machine
- Vendor identity / VS codes

---

## 14. Risks

| Risk | Detail |
|------|--------|
| Fuzzy category↔service matching | Custom service names may get **empty** capability catalogues |
| Dual storage | `services_offered` vs `vendor_services` can diverge |
| Admin disable expectations | Existing vendor `provided` flags may still show in old payloads until re-saved; new organizer selection already blocked |
| Over-merging domains | Treating capabilities as services (or vice versa) would break booking + pricing |
| Inventing “extras” without rules | Unmoderated free-text can pollute marketplace search |

---

## 15. Exact minimum implementation required (later sprint — not now)

If product wants the stated model with minimal change:

1. **Keep** Admin category capability catalogue and Vendor `provided` toggles (already done).
2. **Document / rename UI** so “Service Category” ≠ “Capability” ≠ “Bookable Service”.
3. **Only if required:** allow Vendor custom extras as an **additive** field (e.g. free-text notes or a separate JSON list) that Marketplace can show **without** entering the Admin key catalogue — with clear non-search or moderated rules.
4. **Only if required:** add `required`/`optional` on Admin capability defs (metadata only); enforce on organizer request UI.
5. **Do not** create a parallel capability table, second marketplace engine, or new pricing link for capabilities.

**STOP. No implementation in this sprint.**

---

## Appendix A — Step answers (checklist)

| Step | Answer |
|------|--------|
| 1 Admin audit | Categories + capability JSON; not packages/products |
| 2 Vendor audit | `vendor_services` + capabilities JSON; legacy `services_offered` |
| 3 Marketplace | Reads `vendor_services` (+ profile fallback); capabilities = provided only |
| 4 Duplication | Layered correctly; mild legacy overlap on labels/packages |
| 5 Desired model | Largely supported today |
| 6 Core vs optional | Not present |
| 7 Vendor control | **C:** predefined capabilities + free-text **services**; not free-text capabilities |
| 8 Admin control | Enable/disable capabilities & category active; does not delete history |
| 9 Historical | Request snapshots retain selected caps; bookable keys separate |
| 10 Pricing | Via `service_key` / base payout; not via capability keys |
| 11 Custom extras | No first-class extras; custom service names yes |
| 12 Recommendation | **A** |

## Appendix B — Key code references

- `infra/db/027_phase_event_v2.sql` — `tenant_vendor_categories`
- `infra/db/065_vendor_services.sql` / `066` / `068`
- `services/api/src/modules/vendor-operations/vendor-capability.util.ts`
- `services/api/src/modules/vendors/vendor-services.service.ts`
- `services/api/src/modules/event-config/event-config.service.ts`
- `mobile/lib/features/admin/screens/admin_vendor_categories_screen.dart`
- `mobile/lib/features/admin/screens/admin_vendor_capability_detail_screen.dart`
- `mobile/lib/features/vendor/widgets/vendor_service_capability_editor.dart`
- `mobile/lib/portals/customer/screens/marketplace_vendor_detail_screen.dart`
- `mobile/lib/features/super_admin/screens/commerce_configuration_screen.dart`
