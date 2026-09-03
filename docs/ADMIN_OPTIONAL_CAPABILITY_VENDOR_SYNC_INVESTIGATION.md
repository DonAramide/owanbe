# Admin Optional Capability → Vendor Sync — Investigation

**Date:** 2026-08-21  
**Scope:** Read-only investigation. No code, database, or Vendor UI changes.  
**Verdict:** ⚠ OPTIONAL CAPABILITY DATA FLOW BROKEN

---

## Executive summary

The database and current API **source/`dist` on disk** already store and intend to emit Admin `capability.tier` (`core` | `optional`). The **live API process on `:8080` does not emit `tier`** on vendor-category reads. Flutter defaults missing `tier` to `core`, so:

- Admin **Optional / Additional Capabilities** shows “No optional capabilities yet.”
- Every catalogue item (including Stage, Generator, LED Screen, …) appears under **Core**.
- Vendor **Additional Services** is empty for the same reason.

Optional is **not** lost in Postgres. It is **dropped on the live read path** (stale Node runtime), then mis-grouped in both Admin and Vendor UIs.

---

## 1. Admin save path

| Layer | Location | Behavior |
|-------|----------|----------|
| Screen | `mobile/lib/features/admin/screens/admin_vendor_capability_detail_screen.dart` | Draft list `_draft`; Core vs Optional sections via `_capabilityTiles(tier: 'core'\|'optional')` |
| Add | `_AddCapabilityField` | SegmentedButton `core` / `optional`; `onAdd(label, tier)` appends `VendorCategoryCapability(..., tier: tier)` |
| Move | IconButton on tile | `copyWith(tier: 'optional'\|'core')` |
| Save | `_save()` | `EventConfigApi.adminSaveVendorCategoryCapabilities(id, capabilities: _draft, isActive: …)` |
| Client payload | `event_config_api.dart` | `POST admin/settings/vendor-categories` body: `{ id, capabilities: [{ key, label, enabled, tier }], isActive? }` |
| Endpoint | `AdminEventConfigController` `@Controller('admin/settings')` `@Post('vendor-categories')` | → `adminPatchVendorCategoryCapabilities` |
| Service write | `event-config.service.ts` | Replaces `metadata.capabilities` with parsed array; `tier: parseCapabilityTier(e.tier ?? e.kind)` |
| DB write | `tenant_vendor_categories.metadata` (jsonb) | Full capabilities array overwrite (not merge-per-key) |

**Canonical write values:** lowercase `"core"` | `"optional"`.  
Aliases accepted on write: `additional`, `extra` → `optional`. Missing tier → **`core`**.

**Important side effect:** Save sends the **entire** draft. If the Admin UI hydrated every item as `core` because the read omitted `tier`, a subsequent **SAVE CHANGES** would rewrite DB optionals to `core`. Local DJ data still has optionals, so a full wipe save has **not** landed since migration 070 (or drafts somehow retained tiers).

---

## 2. Database representation (DJ)

**Tenant:** `11111111-1111-4111-8111-111111111111`  
**Table:** `tenant_vendor_categories` (`slug = 'dj'`)  
**Source of truth field:** `metadata.capabilities[]`

| key | name (label) | tier | enabled |
|-----|--------------|------|---------|
| sound_system | Sound System | core | true |
| microphones | Microphones | core | true |
| speakers | Speakers | core | true |
| lighting | Lighting | **optional** | true |
| dj_controller | DJ Controller | core | true |
| generator | Generator | **optional** | true |
| smoke_machine | Smoke Machine | **optional** | false |
| led_screen | LED Screen | **optional** | true |
| stage | Stage | **optional** | true |
| ac | AC | **optional** | false |
| microphone | MICROPHONE | core | true |

**Counts:** 5 core, **6 optional**.  
**Conclusion:** Optional **is** persisted. Admin UI showing “No optional capabilities yet” does **not** match DB.

---

## 3. Admin read path

| Layer | Path | Expected |
|-------|------|----------|
| Client | `GET admin/settings/vendor-categories` → `adminListVendorCategories()` | Full caps including `enabled` + `tier` |
| API (source) | `adminListVendorCategories` | `capabilities: parseAdminCapabilities(r.metadata)` → `{ key, label, enabled, tier }` |
| Flutter parse | `VendorCategoryCapability.fromJson` | `tier` / `kind`; missing → **`core`** |
| UI hydrate | `_hydrate(cat)` → `_draft` | Sections filter `_draft[i].tier == 'core'\|'optional'` |

**Observed UI:** matches “all core” after defaulting missing `tier`.  
**Write vs DB vs read:** DB has `optional`; live public read (below) omits `tier`. Admin GET uses the same `parseAdminCapabilities` in the same Node process → same omission for `tier` on objects that never get the property in the stale module graph.

---

## 4. Vendor API path

| Layer | Location | Behavior |
|-------|----------|----------|
| Endpoint | `GET /v1/event-config/vendor-categories` (Public) | `EventConfigService.listVendorCategories` |
| Source map | `.filter(c => c.enabled).map(c => ({ key, label, tier }))` | Should emit `tier` |
| Provider / load | `vendor_service_capability_editor.dart` → `EventConfigApi.listVendorCategories()` | Builds catalogue per matched category |
| Model | `VendorCategoryCapability` | `tier` default `core` if absent |
| Filtering | Public list drops `enabled: false` | e.g. smoke_machine, ac omitted when disabled — **correct**; stage/generator/led_screen/lighting remain |

**Live probe (2026-08-21, `X-Tenant-Id` = default tenant):**

```json
{"key":"stage","label":"Stage"}
```

- **No `tier` field anywhere** in the vendor-categories payload (`NO_TIER_FIELD`).
- Enabled optional keys appear as bare `{key,label}` only → Flutter treats them as **core**.

Vendor API is **not** intentionally filtering out Optional items; it fails to **transmit** `tier`, so all items land in Core / Additional stays empty.

---

## 5. Vendor grouping logic

```dart
// vendor_service_capability_editor.dart
vendorCapabilitiesForTier(catalogue, 'core');      // tier != 'optional'
vendorCapabilitiesForTier(catalogue, 'optional');  // tier == 'optional'
```

Grouping is **strictly by `capability.tier`**, not by name/category.  
With missing `tier` → all catalogue rows are `core` → **Additional Services** empty. Logic itself is correct; input is wrong.

---

## 6. Exact capability tested: Stage

| Step | Result |
|------|--------|
| Admin intent | Optional (product expectation; seed/migration 070 also marks `stage` optional) |
| Admin UI display | Core (subtitle “Core”; Optional section empty) |
| Saved / stored tier | DB: `"tier": "optional"`, `enabled: true` |
| Admin read (effective) | Treated as core (no `tier` on live responses → Flutter default) |
| Vendor read | Live JSON: `{"key":"stage","label":"Stage"}` — no `tier` |
| Vendor section | **Core Services** (not Additional) |

**Where Optional is lost:** between **Postgres** and the **HTTP JSON** served by the **running** Node process on port 8080 — not in Vendor grouping and not in current on-disk source/`dist` mapping.

---

## 7. Case / enum mismatch

| Layer | Representation |
|-------|----------------|
| Canonical | `"core"` \| `"optional"` (lowercase strings) |
| Flutter | Same; also accepts `additional` / `extra` → `optional` |
| API util | `parseCapabilityTier` — same aliases; else `core` |
| UI labels | “Core” / “Optional” (display only) |

No second tier source found. No case mismatch on stored DJ rows (`"optional"` / `"core"` as written).  
**Defaulting missing → `core`** is the dangerous alias that explains the screenshots.

---

## 8. Old data / migration 070

File: `infra/db/070_admin_capability_tier.sql`

- Annotates known keys (including `stage`, `led_screen`, `generator`, `smoke_machine`, `ac`, `lighting`, …) with `tier: optional`.
- Other keys get `tier: core` (or preserve existing non-empty tier).
- Does **not** invent a parallel metadata property.
- Local DJ row matches that annotation (6 optional keys present).

`ensureCoreVendorCategories` uses `ON CONFLICT DO NOTHING` — does **not** overwrite existing DJ metadata with seed catalogues.

---

## 9. Admin UI behavior

When Admin selects Optional and saves (with **current** Flutter):

- Draft tier becomes `optional`; section move works locally.
- Payload includes `"tier":"optional"`.
- After save, `_persisted`/`_draft` keep local draft; `_awaitingRefresh` may delay re-hydrate if provider data ≠ local.

**Reopen / cold hydrate from live API:** Optional selection **does not stick in the UI** because reads omit `tier` → everything reappears under Core (“returns to Core”). That matches screenshots even while DB still has optional.

---

## Root cause

**Primary:** Live Nest process (`node …/services/api/dist/main`, PID observed on `:8080`, started **09:42**) is still serving an **in-memory** build that maps public capabilities to `{ key, label }` **without** `tier`.

Meanwhile:

- On-disk `dist/.../event-config.service.js` (written ~**11:11**) already contains `.map((c) => ({ key: c.key, label: c.label, tier: c.tier }))`.
- On-disk `vendor-capability.util.js` includes `parseCapabilityTier` / `tier` on `parseAdminCapabilities`.
- DB already has correct `tier` values from migration 070 (+ Admin edits that preserved them).

So: **watch/rebuild updated `dist` files, but the long-lived Node process did not reload them.** Clients talk to stale runtime → no `tier` → Flutter defaults → Admin Optional empty + Vendor Additional empty.

**Secondary risk (not yet observed as a full wipe on DJ):** Admin **Save** while UI shows all-core would persist `tier: "core"` for every capability and destroy optional in DB.

---

## Minimum safe fix (do not implement in this sprint)

1. **Restart** the API process that binds `:8080` so it loads current `dist` (confirm `GET /v1/event-config/vendor-categories` returns `"tier":"optional"` for `stage`).
2. Hard-refresh Admin + Vendor apps; confirm Admin Optional lists Stage/Generator/… and Vendor **Additional Services** lists the same enabled optionals.
3. Optionally harden (only if still needed after restart):
   - Fail CI / smoke test asserting `tier` present on vendor-categories.
   - On Admin save, **merge** server-side: if client omits `tier`, preserve existing DB tier (prevents silent downgrade).
   - Avoid treating “missing tier” as display-only core without a warning when Admin catalogue is dirty.

**Do not:** hardcode Optional lists on Vendor; invent a second tier source; rewrite historical request snapshots.

---

## Files that would need changing

| Priority | File | Change |
|----------|------|--------|
| Ops first | Running `services/api` process | Restart / ensure `nest start --watch` actually reloads after compile |
| Verify | Live `GET event-config/vendor-categories` + Admin `GET admin/settings/vendor-categories` | Assert `tier` on capabilities |
| If harden | `event-config.service.ts` `adminPatchVendorCategoryCapabilities` | Preserve existing tier when client omits it |
| If harden | API smoke / QA script | Assert Stage (or known optional) has `tier: optional` |
| Only if UI still wrong after API fix | Admin/Vendor Flutter (unlikely) | Re-check hydrate; no new catalogue |

Related already-correct (no change required for grouping model):

- `vendor-capability.util.ts` — `parseCapabilityTier` / `parseAdminCapabilities`
- `admin_vendor_capability_detail_screen.dart` — Optional section + save payload
- `vendor_service_capability_editor.dart` — `vendorCapabilitiesForTier`
- `event_config_api.dart` — client `tier` parse/serialize
- `infra/db/070_admin_capability_tier.sql` — already applied on local DJ row

---

## Final result

⚠ **OPTIONAL CAPABILITY DATA FLOW BROKEN**

Break point: **live Admin/Vendor category read responses omit `capability.tier` (stale API runtime), while DB and current compiled sources retain/emit Optional correctly.** Vendor and Admin UIs then default every capability to Core.
