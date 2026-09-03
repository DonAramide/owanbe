# Organizer Marketplace Search + App Stability Fix Report

**Date:** 2026-08-15  
**Scope:** Targeted bug investigation and minimum safe fix — marketplace search + ~10s app reset

---

## 1. Search root cause

Organizer marketplace search (`/vendors`, `MarketplaceScreen`) failed to return expected results due to **three stacked issues**:

| Layer | Problem |
|-------|---------|
| **Backend** `GET /vendors?q=` | `q` only matched `business_name` and `slug` — not city, services, vendor id, or `service_code` |
| **Mobile fetch** `marketplaceVendorsProvider` | When API returned **zero rows**, app silently reloaded the **full unfiltered catalog** — masking failures and producing confusing results |
| **Mobile filter** `applyMarketplaceFilters` | Client query only checked name/category/city/description/slug — **not** `servicesOffered`, `services[]`, vendor `id`, or service codes |

Additional UX gaps:
- No debounce → API call on every keystroke
- `TextField` uncontrolled → search text could desync from provider state
- `marketplaceFiltersProvider` was `autoDispose` → filters could reset when provider tree churned

Search path (unchanged architecture):

```
MarketplaceFilterBar → marketplaceFiltersProvider → marketplaceVendorsProvider
  → VendorsApi.listCatalog(q, city, service) → GET /vendors
  → applyMarketplaceFilters → marketplaceDiscoverVendorsProvider → UI
```

---

## 2. Reload / reset root cause

The ~10s “app reset” was **not a single timer restarting the app**. It was a **cascade of overly broad refresh + router re-evaluation**:

### Primary ~10s trigger

`attendeeLiveSyncProvider` (`attendee_live_providers.dart`) — **`Timer.periodic(Duration(seconds: 10))`**

Previously invalidated:
- `publicEventProgramProvider(eventId)` ✓ scoped
- `attendeeLiveUpdatesProvider(eventId)` ✓ scoped
- **`attendeeTicketsSyncProvider`** ✗ **shared across attendee portal**

Invalidating `attendeeTicketsSyncProvider` every 10s forced broad attendee provider cascades → loading skeletons, tab loss, scroll reset.

### Router / navigation reset trigger

`RouterNotifier` listened to **every** `authSessionProvider` change (including Supabase `tokenRefreshed` object replacement), **every** `appBootstrapProvider` copyWith, and **every** `activeWorkspaceProvider` notification.

Combined with `GoRouter(refreshListenable: refresh)` this re-ran redirects and could snap users back toward hub/root.

`WorkspaceExperienceShell` called `switchTo(workspace)` on **every mount**, re-firing workspace notifications even when unchanged.

### Marketplace-specific reset trigger

`MarketplaceScreen` used `vendors.when(loading: () => fullPageSkeleton)` — any catalog refetch **destroyed the entire screen** including the search field, even when prior data existed.

`marketplaceFilteredVendorsProvider` returned `[]` during reload → results briefly cleared.

### Search + polling interaction

CRM live tick (`vendorCrmLiveTickProvider`, **5s**) refetches event vendor CRM on marketplace pages with `eventId`. This did **not** directly break search, but combined with full-page loading UX made the screen feel like it “reset” during background refresh.

---

## 3. Ten-second trigger (exact)

| File | Interval | Previous behavior | Fix |
|------|----------|-------------------|-----|
| `mobile/lib/portals/attendee/providers/attendee_live_providers.dart` | **10s** | `invalidate(attendeeTicketsSyncProvider)` + program/updates | Scoped `ref.refresh` on event providers only |
| `mobile/lib/portals/customer/providers/vendor_crm_providers.dart` | **5s** | CRM/message/request polling (preserved) | Unchanged — real-time preserved |
| `mobile/lib/features/operations/providers/operations_providers.dart` | 12s | Ops feed only | Unchanged |

---

## 4. Files changed

| File | Change |
|------|--------|
| `services/api/src/modules/vendors/vendors.service.ts` | Expanded `q` search; expose `serviceCode` in catalog services JSON |
| `mobile/lib/core/api/vendors_api.dart` | `serviceCode` on `MarketplaceVendorService`; `matchesSearchQuery()` |
| `mobile/lib/portals/customer/models/marketplace_filters.dart` | Persistent filters; use `matchesSearchQuery` |
| `mobile/lib/portals/customer/providers/marketplace_providers.dart` | Remove empty-result fallback; keep prior data during reload |
| `mobile/lib/portals/customer/widgets/marketplace/marketplace_filter_bar.dart` | Debounced search + controlled `TextEditingController` |
| `mobile/lib/portals/customer/screens/marketplace_screen.dart` | Preserve UI during reload; thin progress bar instead of full skeleton |
| `mobile/lib/router/router_notifier.dart` | Narrow router refresh to meaningful auth/workspace/boot transitions |
| `mobile/lib/features/workspace/widgets/workspace_experience_shell.dart` | Guard `switchTo` when workspace unchanged |
| `mobile/lib/portals/attendee/providers/attendee_live_providers.dart` | Stop shared ticket invalidation on 10s tick |
| `mobile/lib/portals/customer/router/event_route_registry.dart` | Treat `/vendors` as organizer workspace path (redirect safety) |
| `mobile/test/portals/customer/marketplace_search_test.dart` | Regression tests for search matching |

---

## 5. Providers / services affected

| Provider / service | Impact |
|--------------------|--------|
| `marketplaceFiltersProvider` | Now persistent (non-autoDispose) |
| `marketplaceVendorsProvider` | No empty-catalog fallback; stable during reload |
| `marketplaceFilteredVendorsProvider` | Uses `valueOrNull` — keeps results during refresh |
| `RouterNotifier` | Fewer spurious GoRouter refreshes |
| `attendeeLiveSyncProvider` | Scoped 10s refresh only |
| `vendorCrmLiveTickProvider` | **Unchanged** — messaging/requests still poll every 5s |
| `VendorsService.listCatalog` | Richer server-side search |

---

## 6. Routing / state impact

- `/vendors` explicitly recognized as organizer workspace path
- Token refresh no longer triggers router redirect re-evaluation
- Workspace shell no longer re-asserts workspace on every remount
- Marketplace search text, filters, and navigation persist through background catalog reloads

---

## 7. Search behaviour after fix

Organizer marketplace search now supports:

| Field | Server (`q`) | Client (fallback) |
|-------|--------------|-------------------|
| Business name | ✅ | ✅ |
| Slug | ✅ | ✅ |
| City | ✅ | ✅ |
| Category / description | ✅ | ✅ |
| Service names | ✅ | ✅ |
| Service code (`VS-…`) | ✅ | ✅ |
| Vendor UUID / id | ✅ | ✅ |
| Keywords in services offered | ✅ | ✅ |

- **350ms debounce** on search input
- **Empty API result = “No vendors found”** (not silent full-catalog reload)
- Search + category/city filters compose correctly

---

## 8. Real-time regression results

Preserved (not disabled):

| Feature | Mechanism | Status |
|---------|-----------|--------|
| Vendor CRM / messaging | `vendorCrmLiveTickProvider` 5s | ✅ Preserved |
| Request status updates | `eventVendorCrmProvider` watches live tick | ✅ Preserved |
| Attendee live program/updates | 10s scoped `ref.refresh` | ✅ Preserved |
| Attendee ticket sync | Manual / screen-scoped providers | ✅ No longer globally invalidated every 10s |
| Ops live feed | 12s SSE + poll | ✅ Unchanged |

---

## 9. Tests performed

| Test | Result |
|------|--------|
| `flutter test test/portals/customer/marketplace_search_test.dart` | ✅ 3/3 passed |
| `flutter analyze` on changed mobile files | ✅ No errors |
| Code trace: search path end-to-end | ✅ Verified |
| Code trace: 10s timer chain | ✅ Verified + fixed |

**Recommended manual QA:**
1. Open Organizer marketplace → search vendor name, `VS-` code, “Lagos”, “Catering”
2. Wait 30s — search text and results should remain; screen should not blank
3. Open vendor request conversation — messages should still update within ~5s
4. Attendee live hub — program/updates should still refresh ~10s without portal-wide reset

---

## 10. Remaining technical debt

| Item | Notes |
|------|-------|
| `organizerVendorCrmAlertsProvider` on home hub | Still watches 5s CRM tick; hub tabs may soft-reload (not fixed in this pass) |
| `MarketplaceTabV3` (command center) | No text search field — organizers must use `/vendors` for search |
| Backend search limit | Catalog capped at 100 rows — large tenant may need pagination |
| `vendor_intelligence_engine` demo copy | Unrelated stale negotiation strings (prior cleanup scope) |

---

## Root-cause summary (pre-fix)

**SEARCH ROOT CAUSE:** Backend `q` too narrow + mobile empty-result fallback + client filter missing services/codes.

**RELOAD ROOT CAUSE:** Broad provider invalidation (10s attendee ticket sync) + router listening to all auth/boot/workspace mutations + marketplace full-page loading skeleton on any refetch.

**10-SECOND TRIGGER:** `attendeeLiveSyncProvider` in `attendee_live_providers.dart:55`.

**MINIMUM FIX:** Expand catalog search, fix mobile filter/fetch, preserve marketplace UI during reload, narrow router refresh, scope 10s polling.

---

## Conclusion

✅ **ORGANIZER MARKETPLACE SEARCH + APP STABILITY FIXED**
