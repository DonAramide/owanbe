# Capability Live Sync + Vendor Request Regression — Report

**Date:** 2026-08-21  
**Scope:** Investigate live capability sync + Vendor Accept/Decline; minimum safe Flutter refresh wiring; API compile fix for `tier` on AdminCapabilityDef.  
**Verdict:** ⚠ ADDITIONAL LIVE SYNC / REQUEST WORK REQUIRED

---

## Investigation brief (pre-implementation)

### CAPABILITY LIVE UPDATE SOURCE

| Mechanism | Where | Role |
|-----------|--------|------|
| Soft poll tick | `vendorCrmLiveTickProvider` (5s) | Shared CRM live tick |
| Silent refresh | `refreshOnAsyncTick` → `invalidateSelf` | In-place data refresh (no loading flash) |
| UI stability | `whenStable` / `skipLoadingOnRefresh` | Keep screen mounted |
| CRM SSE | `CrmSseClient` + `crm_realtime_providers` | Hybrid with CRM REST (requests/messages) — **not** used for Admin catalogue |
| Riverpod invalidate | Scoped providers only | Avoid global shell/router refresh |

### CAPABILITY LIVE UPDATE CURRENT STATE (before fix)

| Surface | Behaviour |
|---------|-----------|
| Vendor catalogue | **One-shot** `initState` → `listVendorCategories()` — no poll |
| Vendor provided toggles | `vendorWorkspaceProfileProvider` — fetch once until invalidate |
| Marketplace profile / request services | FutureProviders — no soft tick |
| Public rule | Server `Admin enabled ∩ Vendor provided` via `publicCapabilities` / `allowedCapabilitySet` |

### CAPABILITY UPDATE GAP

Admin enable/disable and Vendor ON/OFF did **not** propagate to open Vendor/Organizer screens without leave/re-enter or hot restart.

### VENDOR REQUEST ACCEPT PATH

```
VendorRequestDetailSheet Accept
  → vendorAcceptRequest
  → POST /vendor-requests/:id/transition { stage: "accepted" }
  → VendorCrmService.transitionStage
  → vendor_id == resolveVendorId(user) (not user_id as vendor identity)
  → UPDATE vendor_event_requests.stage
  → stage history + feed + notifications
  → refreshVendorCrm + bumpVendorRevision
  → vendorInboxProvider / eventVendorCrmProvider soft-tick refresh
```

### VENDOR REQUEST DECLINE PATH

Same as Accept with `stage: "declined"`. Organizer cannot Accept/Decline (`ORGANIZER_CANNOT_DECIDE`).

### CURRENT CRM LIVE TICK

- Interval: **5 seconds**
- Pattern: `listen` tick → `invalidateSelf` (refresh, not reload)
- Consumers: inbox, event CRM, timeline, change requests, funds
- Preserved; not disabled

### UI STABILITY RISK

Avoided: global `ref.invalidate`, router refresh, shell rebuild.  
Applied: same soft-tick + `whenStable` pattern as Global UI Stability sprint.

### MINIMUM SAFE FIX (implemented)

Reuse `vendorCrmLiveTickProvider` + `refreshOnAsyncTick` for capability catalogue, vendor workspace profile, and marketplace vendor profile/services providers. Wire Vendor editor to the catalogue provider instead of one-shot load.

---

## 1. Capability data flow

```
Admin: tenant_vendor_categories.metadata.capabilities { key, label, enabled, tier }
        ↓ GET event-config/vendor-categories (enabled + tier)
Vendor UI: Core / Additional toggles → vendor_services.capabilities { key, label, provided }
        ↓ GET vendors/:id / listVendorServices
Marketplace / Request: Admin enabled ∩ Vendor provided
        ↓ selectedCapabilities snapshot on create
Historical requests: frozen metadata — Admin/Vendor later changes do not rewrite
```

---

## 2. Live update mechanism

**Reuse:** existing `vendorCrmLiveTickProvider` (5s) + `refreshOnAsyncTick` + `whenStable`.

| Provider | Soft tick |
|----------|-----------|
| `vendorCapabilityCatalogueProvider` (**new**) | Yes |
| `vendorWorkspaceProfileProvider` | Yes |
| `marketplaceVendorProfileProvider` | Yes |
| `marketplaceVendorServicesForEventProvider` | Yes |
| `marketplaceVendorServicesForRangeProvider` | Yes |

Expected latency for open screens: **under 5 seconds** (tick interval). Not sub-second / not websocket “real-time”.

---

## 3. Files changed

| File | Change |
|------|--------|
| `mobile/lib/features/vendor/providers/vendor_profile_providers.dart` | Catalogue provider + soft tick on workspace profile |
| `mobile/lib/features/vendor/widgets/vendor_service_capability_editor.dart` | Watch catalogue provider; `whenStable` on profile |
| `mobile/lib/portals/customer/providers/marketplace_providers.dart` | Soft tick on profile + event/range services |
| `services/api/.../vendor-services.service.ts` | `AdminCapabilityDef` return type includes `tier` |
| `services/api/.../vendor-crm.service.ts` | Compile: `tier: 'core'` on intersection helper objects |
| `services/api/.../vendor-change-request.service.ts` | Same compile fix |

---

## 4. Providers involved

- `vendorCrmLiveTickProvider`
- `vendorCapabilityCatalogueProvider`
- `vendorWorkspaceProfileProvider`
- `marketplaceVendorProfileProvider`
- `marketplaceVendorServicesForEventProvider` / `ForRangeProvider`
- CRM: `vendorInboxProvider`, `eventVendorCrmProvider`, `vendorCrmRefreshProvider`

---

## 5. API endpoints

| Use | Endpoint |
|-----|----------|
| Admin catalogue (public subset) | `GET /v1/event-config/vendor-categories` |
| Admin save | `POST /v1/admin/settings/vendor-categories` |
| Vendor patch provided | Identity/vendor services PATCH (existing) |
| Marketplace services | `GET /v1/vendors/:id/services` (+ get vendor) |
| Accept / Decline | `POST /v1/vendor-requests/:id/transition` |
| Counter (API) | `POST /v1/vendor-requests/:id/counter` |
| Messages | `POST /v1/vendor-requests/:id/messages` |

---

## 6. Vendor request Accept flow

Verified in code: Vendor-only; `resolveVendorId` must equal `row.vendor_id`; stage → `accepted`; history/feed/notifications via existing CRM service; Organizer pipeline via `eventVendorCrmProvider` 5s tick.

---

## 7. Vendor request Decline flow

Same ownership rules; stage → `declined`.

---

## 8. Negotiation flow

| Layer | Status |
|-------|--------|
| `transitionStage('negotiating')` | **Disabled** (`NEGOTIATION_DISABLED`) |
| Counter API + `vendorCounterRequest` | Present |
| Vendor request detail UI | **Accept / Decline only** (`Vendor-side request detail with Accept / Decline (no negotiation)`) |
| Messages after accept | Preserved (`canMessage` stages) |
| Change requests (Phase 3D) | Preserved on accepted bookings |

Do not treat `vendor_intelligence_engine` demo negotiations as live CRM.

---

## 9. Real-time latency observed

| Path | Observed / designed |
|------|---------------------|
| Capability soft tick | **Under 5 seconds** (5s poll) |
| CRM request/message tick | **Under 5 seconds** (existing) |
| Dual-browser Admin↔Vendor↔Organizer stopwatch | **Not executed in this run** |

Do **not** claim immediate or sub-1s real-time for capabilities.

---

## 10. UI stability verification

- Soft tick uses `invalidateSelf` (refresh), not watched-tick reload.
- Vendor editor uses `whenStable` so catalogue/profile refresh does not flash full-page loading.
- No global shell/router invalidate added.
- Unit: `silent_refresh_test.dart`, `vendor_core_additional_grouping_test.dart` — passed.

---

## 11. Historical-data protection

- Request create stores `selectedCapabilities` snapshot.
- Admin disable removes capability from **future** catalogue/marketplace intersection only.
- Vendor service PATCH preserves already-stored declarations for Admin-disabled keys (orphan row), not shown on Marketplace.
- No rewrite of `vendor_event_requests` history, negotiations, contracts, or completed bookings from catalogue edits.

---

## 12. Test results

| Test | Result |
|------|--------|
| Flutter grouping + silent refresh unit tests | ✅ Pass |
| API `tsc --noEmit` (tier compile fixes) | ✅ Pass |
| Code trace Accept/Decline + vendor_id auth | ✅ Verified |
| Dual-session live: Admin disable → Vendor UI | ⏸ Not run this session |
| Dual-session: Vendor toggle → Organizer profile/modal | ⏸ Not run this session |
| Live Accept → Organizer pipeline | ⏸ Not run this session |
| Live Decline → Organizer pipeline | ⏸ Not run this session |
| Negotiate UI end-to-end | ⚠ UI not exposed; stage transition disabled |

---

## 13. Remaining technical debt

1. **Dual-session QA** still required to measure actual capability latency and confirm no filter/scroll reset.
2. **Negotiation product gap:** counter API exists; Vendor detail has no Negotiate UI; `negotiating` stage transition forbidden — confirm product intent before re-enabling.
3. **`npm run start:dev`** previously failed until `tier` was added to AdminCapabilityDef call sites — restart watch after this compile fix if needed.
4. Marketplace **catalog list** (`marketplaceVendorsProvider`) is not soft-ticked (only open profile/services) — list cards that omit per-service capabilities are unaffected; reopen detail for freshest list-level data if needed.
5. Mock / demo: `vendor_intelligence_engine` negotiation demos ≠ live `vendor_event_requests`.

---

## Final result

⚠ **ADDITIONAL LIVE SYNC / REQUEST WORK REQUIRED**

**Done:** Capability soft-sync wired to existing 5s CRM tick; Accept/Decline CRM path and `vendor_id` auth traced and intact; historical snapshots protected; API tier compile blockers fixed.

**Remaining:** Dual-browser live acceptance of sync latency + Accept/Decline UI; product decision on Negotiate UI vs disabled `negotiating` stage.
