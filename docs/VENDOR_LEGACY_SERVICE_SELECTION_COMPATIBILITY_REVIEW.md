# Vendor Legacy Service Selection — Compatibility Review

**Date:** 2026-08-27  
**Mode:** Review only. No code, API, Flutter, database, migration, or QA Pack changes.  
**Tenant audited:** `11111111-1111-4111-8111-111111111111` (local dev)  
**Scope:** Legacy vendor category/service selection vs Phase 1/2 capability + taxonomy model.

---

## Executive summary

Legacy vendor selections live in **`vendor_profiles.category`** (text, often CSV) and **`vendor_profiles.services_offered`** (JSONB array of free-text labels), with a synced **`vendor_services`** table. The new model adds **`vendor_business_capability_assignments`** and **`vendor_offering_category_selections`** (FK to `tenant_vendor_categories` with `offering_kind`).

**Current code does not delete or overwrite legacy fields** when Phase 2 APIs run. However, the two models are **not unified in UI or runtime authority**: marketplace discovery, CRM, and pricing still read legacy/`vendor_services`; **My Services & Rentals** and taxonomy-gated flows read the new capability tables (currently **empty for all existing vendors**).

Deterministic label→taxonomy mapping works for common cases (DJ, Catering, Photographer) but **fails or is ambiguous** for legacy enum values like `Rentals`, typos, and CSV/multi-value `category` strings. **Automatic capability derivation without vendor confirmation is unsafe.**

**Verdict:** **PARTIAL PASS** on data preservation; **FAIL** on unified product behavior without an explicit architectural decision and additive reconciliation work.

---

## 1. Legacy onboarding model

**Status: PARTIAL PASS**

### What existed (pre–Phase 1/2)

| Layer | Behavior |
|-------|----------|
| **Flutter** | Vendor onboarding collected business profile + service selections using client-side **`VendorCatalogType`** enum labels (Catering, Photography, Entertainment, Rentals, etc.) and free-text **`services_offered`** labels. |
| **Storage** | `vendor_profiles.category` (single primary label **or** comma-separated list), `vendor_profiles.services_offered` (JSON array). |
| **Sync** | On profile save, Nest **`VendorProfileService`** calls **`VendorServicesService.syncFromOfferedLabels`**, upserting **`vendor_services`** rows (migration 065 backfill + ongoing sync). |
| **Catalog seed** | Onboarding optionally calls **`vendor_catalog_api.createPackage`** for named services with prices → **`vendor_packages`** (best-effort, not canonical). |

### What onboarding does today (Phase 2 overlay)

`VendorOnboardingScreen` step 2 (`_categoryStep`) now loads Super Admin taxonomy:

- Select **`SERVICE_PROVIDER`** / **`RENTAL_PROVIDER`** (from `tenant_vendor_business_capabilities`)
- Select service/rental categories by **UUID** (`tenant_vendor_categories`)
- **`_syncCategoryLabels()`** copies selected taxonomy **labels** into `_categories`
- On submit: **`PUT /v1/me/vendor-profile`** writes legacy fields; then **`putCapabilities`** + **`putCategories`** (wrapped in try/catch — failure does not roll back profile save)

Legacy hydration on re-entry splits `p.category` CSV into `_categories` **but does not** populate `_serviceCategoryIds` / `_rentalCategoryIds` from legacy data.

### Historical “up to 3 services/categories”

Documented team memory references a **3-selection cap**. **No such cap exists in current Flutter, Nest, or DB constraints:**

| Location | Limit found |
|----------|-------------|
| `ProfileChipSelector` | None |
| `UpsertVendorProfileDto.servicesOffered` | `@ArrayMaxSize(48)` |
| `VendorServicesService.syncFromOfferedLabels` | `.slice(0, 48)` |
| `vendor_profiles.category` | `@MaxLength(120)` (string length, not item count) |
| Docs (`MULTI_SERVICE_VENDOR_COMMERCE_IMPLEMENTATION.md`) | Explicit: *“No artificial max of 3”* |

**Observed data:** Two vendors (`invify-services`, `prospersimon159`) have exactly three `services_offered` entries and three `vendor_packages` — consistent with user choice or onboarding UX, **not enforcement**.

---

## 2. Existing storage

**Status: PASS**

### Primary legacy fields (`vendor_profiles`)

| Column | Type | Example (live DB) | Notes |
|--------|------|-------------------|-------|
| `category` | `TEXT` | `"Catering, Photography, DJ"` | May be single `VendorCatalogType` label or CSV of labels |
| `services_offered` | `JSONB` | `["DJ","CATERING","PHOTPGRAPHY"]` | Free-text labels; not taxonomy UUIDs |
| `subcategory` | `TEXT` | optional free text | Separate from taxonomy |

### Derived / parallel tables

| Table | Relationship to legacy | Wipe risk from Phase 2 |
|-------|------------------------|-------------------------|
| **`vendor_services`** | Synced from `services_offered` labels (`service_key` normalized) | **No** — additive upsert; status/capabilities patched separately |
| **`vendor_packages`** | Optional onboarding seed from named services + prices | **No** — not touched by taxonomy PUT |
| **`rental_catalog_items`** | Independent rental marketplace catalogue | **No** — no legacy vendors with rental items in dev DB |
| **`vendor_business_capability_assignments`** | New; per-vendor `SERVICE_PROVIDER` / `RENTAL_PROVIDER` | **No** — separate table; **0 rows** for all vendors today |
| **`vendor_offering_category_selections`** | New; FK to `tenant_vendor_categories.id` | **No** — separate table; **0 rows** today |

### Live dev snapshot (2026-08-27)

| Vendor slug | `category` | `services_offered` | `vendor_services` | Cap assignments | Taxonomy selections | `vendor_packages` |
|-------------|------------|--------------------|--------------------|-----------------|---------------------|---------------------|
| `invify-services` | Catering, Photography, DJ | DJ, CATERING, PHOTPGRAPHY (typo) | 3 rows (`category_id` null) | 0 | 0 | 3 |
| `prospersimon159` | Catering, Photography, DJ | CATERING, PHOTOGRAPHY, DJ | 3 rows | 0 | 0 | 3 |
| `ada-attendee` | Photography, Videography | WEDDING BUFFET | — | 0 | 0 | 0 |
| `jollof-and-co` | (empty) | DJ | 1 row | 0 | 0 | 0 |

**Supabase auth metadata:** onboarding also writes `vendor_category` user attribute as CSV — secondary, not marketplace-canonical.

---

## 3. Existing APIs

**Status: PASS**

### Legacy read/write (unchanged authority for marketplace)

| Method | Path | Service | Legacy fields |
|--------|------|---------|---------------|
| GET | `/v1/me/vendor-profile` | `VendorProfileService.getProfile` | Returns `category`, `servicesOffered`, `services[]` |
| PUT/PATCH | `/v1/me/vendor-profile` | `VendorProfileService.upsertProfile` | Updates `category`, `services_offered`; triggers `syncFromOfferedLabels` |

### Public / organizer catalogue (marketplace)

| Method | Path | Legacy usage |
|--------|------|--------------|
| GET | `/v1/vendors/catalog` (and variants) | `VendorsService.listCatalog` reads `vp.category`, `vp.services_offered`, joins `vendor_services`, `vendor_packages` for pricing |

Search/filter SQL matches `category`, `services_offered` JSON, and `vendor_services.service_key` / `service_name`.

### New Phase 2 APIs (additive; vendor-owned)

| Method | Path | Behavior vs legacy |
|--------|------|-------------------|
| GET | `/v1/vendors/:id/offerings/config` | Returns `capabilityKeys` + taxonomy category selections only |
| PUT | `/v1/vendors/:id/business-capabilities` | DELETE+INSERT assignments; **does not touch** `vendor_profiles` |
| PUT | `/v1/vendors/:id/offering-categories` | DELETE+INSERT `vendor_offering_category_selections`; **does not touch** legacy columns |
| POST | `/v1/vendors/:id/offerings/services` | Creates taxonomy-linked `vendor_services` with **`category_id`** (new path) |

### Super Admin taxonomy (definitions only)

| Method | Path |
|--------|------|
| GET | `/v1/event-config/public/business-capabilities` |
| GET | `/v1/event-config/public/offering-categories?kind=service\|rental` |
| Admin CRUD | `/v1/admin/settings/vendor-*` (capabilities, categories, resources) |

---

## 4. Existing Flutter usage

**Status: PARTIAL PASS**

### Screens that read/write legacy selections

| Screen | Legacy fields | New capability/taxonomy |
|--------|---------------|-------------------------|
| **`VendorOnboardingScreen`** | Writes `category` CSV + `servicesOffered` on submit | Step 2: capabilities + taxonomy UUIDs; legacy labels derived via `_syncCategoryLabels` |
| **`VendorProfileEditSheet`** | Dropdown `VendorCatalogType` + `ProfileChipSelector` “Additional service labels” from `servicesOffered` | **`VendorServiceCapabilityEditor`** — admin capability toggles on existing `vendor_services` rows only; **no** Business Type / taxonomy category picker |
| **`VendorMyOfferingsScreen`** | — | Gated on `capabilityKeys`; empty → blocked message |
| **`VendorDashboardScreen` / CRM / requests** | Uses `vendor_services`, request `serviceKey` | Capability extras from admin taxonomy metadata when present |
| **Organizer marketplace** | `MarketplaceVendor.category`, `servicesOffered`, `services[]` | Does **not** consume `vendor_offering_category_selections` |

### Format of stored values

| Field | Format | IDs/slugs? |
|-------|--------|------------|
| `category` | Human labels; often CSV | **No** — not `tenant_vendor_categories.slug` |
| `services_offered` | JSON string array of labels (often UPPERCASE legacy) | **No** |
| `vendor_services.service_key` | Normalized slug from label (`dj`, `catering`, `photpgraphy`) | Derived, not FK |
| New selections | UUID → `tenant_vendor_categories.id` | **Yes** |

### Profile edit inconsistency

- Legacy onboarding stored **multi-value** `category` CSV (`"Catering, Photography, DJ"`).
- Edit profile uses a **single-select** `VendorCatalogType` dropdown; unknown CSV is appended as one custom dropdown item (preserved on save, not split for editing).
- **`servicesOffered`** chips use `_kServiceOptions` (operational tags like “Equipment rental”) **merged** with entity names on save — distinct from taxonomy categories.

---

## 5. Three-service limit

**Status: PASS** (audited: **no active limit**)

| Question | Finding |
|----------|---------|
| **Where enforced?** | **Nowhere** in Flutter onboarding chips, profile edit, Nest DTO (max 48), or DB. |
| **What depends on “3”?** | Only coincidental sample data (3 packages/services for two vendors). Marketplace builds filter chips dynamically from all `services` / `servicesOffered` / `categoryLabel` — no hardcoded triple. |
| **Safe to remove/extend?** | Limit is already absent; increasing selections is safe from a code perspective. |
| **Should new system replace it?** | **Yes, conceptually** — Super Admin taxonomy + capabilities should become the selection model, but marketplace must keep reading legacy until cutover or dual-read. |

### Recommendation (limit policy)

**Option C — recommended:** Treat “max 3” as **historical UX folklore**, not a constraint. Do **not** reintroduce a cap in Edit Profile. Allow unlimited taxonomy category selections bounded only by `@ArrayMaxSize(48)` / practical UI. If product wants a soft cap, define it at taxonomy level (admin), not legacy chip count.

---

## 6. New capability model (Phase 1/2)

**Status: PASS** (additive; no legacy wipe)

| Concept | Storage | Authority |
|---------|---------|-----------|
| **SERVICE_PROVIDER / RENTAL_PROVIDER** | `tenant_vendor_business_capabilities` (definitions), `vendor_business_capability_assignments` (per vendor) | Super Admin enables definitions; vendor assigns self (onboarding or future admin tool) |
| **Service categories** | `tenant_vendor_categories` where `offering_kind = 'service'` | Super Admin |
| **Rental categories** | `tenant_vendor_categories` where `offering_kind = 'rental'` | Super Admin |
| **Vendor category picks** | `vendor_offering_category_selections` | Vendor (PUT replaces set) |
| **Taxonomy-linked services** | `vendor_services.category_id` | Set when created via offerings API |

Migration **071** explicitly states it does **not** alter existing `vendor_services` rows or assign capabilities to vendors.

---

## 7. Legacy → new taxonomy mapping

**Status: PARTIAL PASS**

Authoritative taxonomy (dev tenant, active rows):

- **22 service** slugs: `dj`, `catering`, `photographer`, `decorator`, …
- **20 rental** slugs: `chairs`, `tables`, `rentals-equipment`, …

### Proposed mapping table (evidence-based)

| Legacy source | Example | Taxonomy target | `offering_kind` | Confidence |
|---------------|---------|-----------------|-----------------|------------|
| `services_offered` / CSV | `DJ` | `service\|dj\|DJ` | service | **High** |
| | `CATERING` | `service\|catering\|Catering` | service | **High** |
| | `PHOTOGRAPHY` | `service\|photographer\|Photographer` | service | **High** (label differs) |
| | `PHOTPGRAPHY` (typo) | `service\|photographer\|Photographer` | service | **Medium** — fuzzy match required |
| | `WEDDING BUFFET` | `service\|catering\|Catering`? | service | **Low** — could be package name, not category |
| `VendorCatalogType` | `Photography` | `photographer` | service | **High** |
| | `Entertainment` | `dj` or `live-band`? | service | **Ambiguous** |
| | `Rentals` | **No** single slug — legacy enum ≠ rental taxonomy | rental? | **Ambiguous** — could mean broad rental business, not a specific rental category |
| | `Rentals & Equipment` | closest: `rentals-equipment` | rental | **Medium** |
| CSV `category` | `Photography, Videography` | `photographer` only; **no `videography` slug** | service | **Partial** — Videography unmapped |
| Chip label | `Equipment rental` (profile edit) | Could imply `RENTAL_PROVIDER` + multiple rental slugs | mixed | **Ambiguous** — operational tag, not taxonomy |

### Rules for safe automated mapping

1. Match normalized label → `tenant_vendor_categories.label` (case-insensitive) **or** known alias table.
2. If multiple taxonomy rows match, **do not auto-pick** — flag for vendor confirmation.
3. **Never** map legacy `Rentals` enum to `RENTAL_PROVIDER` without evidence from `rental_catalog_items` or explicit vendor selection.
4. Typos (`PHOTPGRAPHY`) require fuzzy match with audit log, not silent correction.

---

## 8. Data preservation strategy

**Status: PASS** (current behavior; future work must maintain)

| Rule | Current code | Required going forward |
|------|--------------|------------------------|
| Do not wipe `vendor_profiles.category` | ✅ Phase 2 does not UPDATE it | Keep |
| Do not wipe `services_offered` | ✅ | Keep |
| Do not delete `vendor_services` on taxonomy PUT | ✅ | Keep |
| Do not reset onboarding | ✅ | Keep |
| Do not silently overwrite legacy on capability save | ✅ Separate APIs | Keep; unify UI only with explicit save + merge strategy |
| Dual-read period | Marketplace reads legacy | Add read fallback: taxonomy selections → display labels |

**Overwrite risk (existing):** Re-running onboarding or profile save **can** replace `category` / `services_offered` if the vendor submits new values — same as today, not introduced by Phase 2.

---

## 9. Existing vendor compatibility

**Status: PARTIAL PASS**

| Concern | Status |
|---------|--------|
| Legacy data preserved in DB | **PASS** |
| Marketplace still discoverable | **PASS** — driven by `vendor_services` + legacy labels |
| CRM / requests still work | **PASS** — `serviceKey` on `vendor_event_requests` |
| **My Services & Rentals** | **FAIL** — requires `capabilityKeys`; all existing vendors have **none** |
| Taxonomy-gated service creation (`categoryId` required) | **FAIL** until capabilities + categories assigned |
| Rental packages | N/A in dev (no rental items) |
| Onboarding re-run | **PARTIAL** — can assign capabilities but legacy CSV not auto-mapped to UUID chips |

### Capability derivation recommendation

**Do not auto-assign `SERVICE_PROVIDER` / `RENTAL_PROVIDER` from legacy labels alone.**

Safest approach:

1. **Preserve legacy data read-only** in UI until vendor confirms mapping.
2. **Pre-fill suggestions** in Edit Profile from deterministic label matches (DJ → service/dj).
3. Require explicit **Save** on capabilities + category selections (same pattern as current explicit-save work).
4. Optional **admin-assisted assignment** for support/QA (additive API — not implemented).
5. Derive **suggested** capabilities: if any mapped category has `offering_kind = service` → suggest `SERVICE_PROVIDER`; if any rental slug matched **or** `rental_catalog_items` exist → suggest `RENTAL_PROVIDER` — vendor confirms.

Auto-assignment without confirmation risks misclassifying “Equipment rental” chip vendors and legacy `Rentals` enum users.

---

## 10. New vendor compatibility

**Status: PARTIAL PASS**

| Flow | Behavior |
|------|----------|
| Intended | Choose capabilities → taxonomy categories → complete onboarding |
| Actual | Single onboarding wizard; writes **both** legacy CSV/labels **and** new PUTs |
| Gap | Capability PUT in try/catch — profile can succeed with **empty** assignments |
| Gap | `_hydrate` does not map legacy → UUID chips for returning vendors |
| Second onboarding system | **None** — same route `#/vendor/onboarding` |

**Recommendation:** Keep one onboarding path; on submit, fail loudly or retry if capability PUT fails; write legacy `category` CSV from taxonomy labels only (already done via `_syncCategoryLabels`).

---

## 11. Marketplace compatibility

**Status: PASS** (legacy remains authoritative for discovery)

| Surface | Legacy dependency | New model used? |
|---------|-------------------|-----------------|
| Organizer marketplace list/filter | `category`, `servicesOffered`, `vendor_services` | **No** |
| Vendor search (`listCatalog` query) | Same + ILIKE on JSON | **No** |
| Vendor cards / detail | `categoryLabel` (first CSV segment), `servicesOffered` | **No** |
| Service filter chips | Dynamic from catalog labels | **No** |
| CRM pipeline | `serviceKey`, `serviceLabel` on requests | **No** |
| Rental marketplace | `rental_catalog_items.category_slug` | Separate from `vendor_profiles.category` |
| Admin capability metadata on public services | `tenant_vendor_categories` matched by slug/heuristic in `VendorsService.publicCapabilities` | **Partial** — enriches display, does not gate listing |

**Breakage if `offering_kind` becomes authoritative overnight:** Vendors with legacy data but empty `vendor_offering_category_selections` could disappear from taxonomy-aware filters unless dual-read/fallback is implemented.

---

## 12. Recommended Edit Profile behavior

**Status: PARTIAL PASS** (design recommendation — not implemented)

Target UX:

```
Edit Business Profile
  → Business Type & Offerings
      → [ ] Service Provider   [ ] Rental Provider   (explicit save)
      → Service categories (chips from Super Admin taxonomy)
      → Rental categories (chips from Super Admin taxonomy)
  → Legacy summary (read-only or “pending confirmation”)
      → Shows current category CSV + services_offered labels
  → Bookable services (existing VendorServiceCapabilityEditor + vendor_services)
  → Additional service labels (optional legacy chips — deprecate gradually)
```

| Element | Recommendation |
|---------|----------------|
| Show legacy selections | **Yes** — section “Your current services (from earlier setup)” until reconciled |
| Pre-select taxonomy chips | From deterministic mapping where confidence ≥ high |
| Ambiguous values | Show unmatched legacy labels with “Choose category” CTA |
| Single `VendorCatalogType` dropdown | **Replace** with capability + taxonomy section; keep CSV read-only during transition |
| Explicit save | Separate save for offerings config (already implemented for capability editor) |
| Limit | **No max-3** |

---

## 13. Migration requirement

**Status: PARTIAL PASS**

| Need | Required? | Notes |
|------|-----------|-------|
| Schema migration | **No** — tables exist (071–072) |
| Data backfill script | **Optional but recommended** | One-time **suggestive** backfill: populate `vendor_offering_category_selections` + assignments where mapping confidence is high; **never** delete legacy columns |
| Reconciliation job | **Optional** | Link existing `vendor_services` to `category_id` where `service_key` matches taxonomy slug |
| Cutover flag | **Future** | Feature flag for marketplace to prefer taxonomy selections when present |

**Not required for coexistence.** Required for unified UX and unblocking My Offerings without manual re-onboarding.

---

## 14. Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| Dual truth (legacy labels vs taxonomy UUIDs) | **High** | Dual-read UI; explicit reconciliation save |
| Existing vendors blocked from My Offerings | **High** | Capability assignment flow (vendor edit or admin) |
| Silent capability PUT failure on onboarding | **Medium** | Surface errors; don’t swallow exceptions |
| Auto-map `Rentals` → RENTAL_PROVIDER | **High** | Vendor confirmation only |
| Typo keys (`photpgraphy`) break filters | **Low** | Fuzzy reconcile + optional key alias |
| Profile edit overwrites CSV category with single dropdown | **Medium** | Multi-select taxonomy replaces dropdown |
| Marketplace filter label mismatch (`Photography` vs `Photographer`) | **Low** | `matchesService` aliases already partial |
| Re-onboarding overwrites user data | **Medium** | Hydrate taxonomy UUIDs from legacy before edit |

---

## 15. Recommended implementation approach

**Status: PARTIAL PASS** (plan only)

Phased, additive — **no legacy deletion**:

| Phase | Work | Touches legacy? |
|-------|------|-----------------|
| **A — Display & suggest** | Edit Profile: Business Type & Offerings section; show legacy + suggested taxonomy chips | Read-only legacy |
| **B — Explicit reconcile** | Vendor saves capabilities + categories; optional link `vendor_services.category_id` | Writes new tables only |
| **C — Admin assist** | Super Admin assign capabilities to existing vendor (QA/support) | Assignments only |
| **D — Optional backfill** | Script: high-confidence mappings only; audit log | Additive rows |
| **E — Marketplace dual-read** | Prefer taxonomy labels when selections exist; fallback to legacy | Read path only |
| **F — Deprecate** | Hide legacy dropdown/chips after reconciliation metrics | Long-term |

Do **not** wipe `vendor_profiles.category` or force re-onboarding.

---

## Section scorecard

| # | Section | Result |
|---|---------|--------|
| 1 | Legacy onboarding model | **PARTIAL PASS** |
| 2 | Existing storage | **PASS** |
| 3 | Existing APIs | **PASS** |
| 4 | Existing Flutter usage | **PARTIAL PASS** |
| 5 | Three-service limit | **PASS** (no limit in code) |
| 6 | New capability model | **PASS** |
| 7 | Legacy → new taxonomy mapping | **PARTIAL PASS** |
| 8 | Data preservation strategy | **PASS** |
| 9 | Existing vendor compatibility | **PARTIAL PASS** |
| 10 | New vendor compatibility | **PARTIAL PASS** |
| 11 | Marketplace compatibility | **PASS** |
| 12 | Recommended Edit Profile behavior | **PARTIAL PASS** (design) |
| 13 | Migration requirement | **PARTIAL PASS** |
| 14 | Risks | Documented |
| 15 | Recommended implementation approach | **PARTIAL PASS** (plan) |

---

## Critical compatibility answer

**Can legacy selections safely coexist with the new capability/category system?**

**In storage: yes — today they already coexist without deletion.**

**In product behavior: not yet —** legacy drives marketplace and bookings; new model gates offerings management. Coexistence requires an **explicit reconciliation layer** (UI + optional backfill + dual-read marketplace), not assumption that CSV labels equal taxonomy slugs.

**Example vendor `invify-services` (DJ, Catering, Photography):**

| Legacy | Safe taxonomy mapping | Capability |
|--------|----------------------|------------|
| DJ | `service / dj` | Contributes to **SERVICE_PROVIDER** suggestion |
| Catering | `service / catering` | Same |
| Photography | `service / photographer` | Same (label alias) |
| Rentals | *Not present* | **Do not** infer RENTAL_PROVIDER |

---

⚠ Legacy Compatibility Requires Architectural Decision

**STOP — review only. No implementation performed.**
