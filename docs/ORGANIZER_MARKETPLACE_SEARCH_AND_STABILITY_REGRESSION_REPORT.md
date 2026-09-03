# Organizer Marketplace Search + Stability Regression Report

**Date:** 2026-08-17  
**Scope:** Regression against the prior marketplace search/stability pass — personal-identity search leak + ~10s UI reset

---

## Investigation (before coding)

**SEARCH ROOT CAUSE:**  
`GET /vendors?q=` searched leftover **seed identity** on `vendors.business_name` and `vendors.slug`, not the public marketplace name `COALESCE(vendor_profiles.business_name, vendors.business_name)`. It also referenced **`vp.description`**, a column that does not exist (`vendor_profiles.bio` is the public description). That SQL error caused the mobile catch path to load the **full unfiltered catalog**, then client-filter it.

**PERSONAL-IDENTITY SEARCH LEAK:**  
Vendor rows are created from the account holder (`users` display name / email local-part → `vendors.business_name` + slug, e.g. `Prosper` / `prosper`). Public business name lives on `vendor_profiles.business_name` (e.g. `ABC Mortuary Services`). Catalog **displays** the profile name but **searched** the seed name and slug. Client `matchesSearchQuery()` also matched `slug`. Searching `Prosper` therefore returned the vendor even though that name is not a public marketplace field.

**10-SECOND RESET ROOT CAUSE:**  
Not `attendeeLiveSyncProvider` (already scoped). Marketplace is opened with `context.push`, so **`OwanbeHomeScreen` stays mounted underneath**. That screen watches `homeAlertCountProvider` → `hubOrganizerAlertsProvider` → `organizerVendorCrmAlertsProvider` → **`vendorCrmLiveTickProvider` (5s)**. Each tick sequentially `GET`s vendor-CRM for **every organizer event**. With several events the hitch lands around **~10s**, blanking/rebuilding the stack and looking like a navigation reset.

**EXACT PERIODIC TRIGGER:**  
`vendorCrmLiveTickProvider` in `vendor_crm_providers.dart` — `while (true) { delay 5s; yield }`, kept alive by hub alert badge while Marketplace is pushed on top.

**ROUTER/SHELL IMPACT:**  
GoRouter redirect was not the primary 10s trigger (token refresh already ignored). The hub **IndexedStack** remaining in the navigator stack kept global CRM polling attached to UI that is not the live CRM surface. Marketplace search/filter providers were then rebuilt/hitched as the parent navigator janked.

**MINIMUM FIX:**  
1. Search only public vendor fields (displayed business name, services, codes, geo, bio/category).  
2. Stop hub CRM alerts from watching the 5s live tick. Keep the tick on event CRM / inbox / timeline.

---

## 1. Search root cause

| Layer | Previous (incorrect) | After fix |
|-------|----------------------|-----------|
| SQL `q` | `v.business_name`, `v.slug`, invalid `vp.description` | Public `COALESCE(vp.business_name, v.business_name)`, `vp.bio`, city/state/country, category/subcategory, services, service areas, vendor id, `vendor_services` name/key/code |
| Mobile catch | Failed `q=` → load **full catalog** | Failed search **rethrows** (no unfiltered substitute) |
| Client filter | Matched `slug` (seeded from personal name) | Public fields only — no slug |

Search path (unchanged architecture):

```
MarketplaceFilterBar → marketplaceFiltersProvider → marketplaceVendorsProvider
  → VendorsApi.listCatalog(q, city, service) → GET /vendors
  → applyMarketplaceFilters / matchesSearchQuery → UI
```

---

## 2. Personal identity search leakage root cause

Canonical identity remains: **User → vendor_profiles → vendors.id**.

Leak was **not** a `users` join. It was searching **seed columns** written at `ensureVendorBusinessRow`:

- `vendors.business_name` ← display name / email local-part (`Prosper`)
- `vendors.slug` ← slugified seed name (`prosper`)

Public profile `vendor_profiles.business_name` (`ABC Mortuary Services`) is what the catalog **shows**. Search now uses that same public representation.

**Not searched:** user first/last/display name, email, auth user id, seed slug, private account fields.

---

## 3. 10-second reset root cause

| Mechanism | Interval | Role in reset |
|-----------|----------|----------------|
| `vendorCrmLiveTickProvider` via **hub alerts** | 5s | **Primary** — global poll while hub is under Marketplace |
| `organizerVendorCrmAlertsProvider` | per tick | Sequential CRM fetch for all events → ~10s hitch |
| `attendeeLiveSyncProvider` | 10s | Not involved unless Live Hub is watching (unchanged, still scoped) |
| `RouterNotifier` | on userId / boot phase / workspace | Not the 10s clock |

---

## 4. Exact runtime trigger

```
context.push(/vendors)
  → OwanbeHomeScreen remains in Navigator stack
  → watches homeAlertCountProvider
  → hubOrganizerAlertsProvider
  → organizerVendorCrmAlertsProvider   // WAS watching 5s tick
  → vendorCrmLiveTickProvider yield
  → listForEvent(event) for every organizer event
  → FutureProvider rebuilds / navigator hitch
  → Marketplace appears to blank / snap to root
```

---

## 5. Files changed

| File | Change |
|------|--------|
| `services/api/src/modules/vendors/vendors.service.ts` | `listCatalog` `q` = public vendor fields only; `vp.bio` not `vp.description` |
| `mobile/lib/core/api/vendors_api.dart` | `matchesSearchQuery` drops slug; keeps public business/service/geo/id/code |
| `mobile/lib/portals/customer/providers/marketplace_providers.dart` | Do not fall back to unfiltered catalog on search failure |
| `mobile/lib/portals/customer/providers/vendor_crm_providers.dart` | Hub alerts no longer watch 5s live tick |
| `mobile/test/portals/customer/marketplace_search_test.dart` | Business/service/code + negative personal-name tests |
| `docs/ORGANIZER_MARKETPLACE_SEARCH_AND_STABILITY_REGRESSION_REPORT.md` | This report |

---

## 6. Providers / services involved

| Provider / service | Impact |
|--------------------|--------|
| `VendorsService.listCatalog` | Public-field `q` |
| `MarketplaceVendor.matchesSearchQuery` | No slug / seed-name match |
| `marketplaceVendorsProvider` | Search errors no longer load full catalog |
| `organizerVendorCrmAlertsProvider` | One-shot / manual refresh only |
| `vendorCrmLiveTickProvider` | **Preserved** for event CRM, inbox, timeline, funds |
| `eventVendorCrmProvider` / `vendorInboxProvider` | Unchanged 5s live poll |

---

## 7. Router / shell effects

- `/vendors` remains an organizer workspace path (no hub redirect).  
- Marketplace still `push`es on top of hub.  
- Hub alert badge no longer keeps a 5s CRM storm alive under Marketplace.  
- No GoRouter / auth / workspace-switcher changes.

---

## 8. Search regression tests

| Query | Expected |
|-------|----------|
| `ABC Mortuary Services` | Vendor returned |
| `Mortuary` | Vendor returned (service / category) |
| `VS-000042` | Vendor returned (service code) |
| Vendor UUID prefix | Vendor returned |
| City `Lagos` | Vendor returned |

`flutter test test/portals/customer/marketplace_search_test.dart`

---

## 9. Negative personal-name search test

Given public business name `ABC Mortuary Services` and leftover slug `prosper`:

| Query | Expected |
|-------|----------|
| `Prosper` | **No result** |
| `prosper` | **No result** |

Unless `Prosper` appears in a legitimate public field (business name, bio, service, city, etc.).

---

## 10. Stability regression tests

Manual (required):

1. Open Organizer Marketplace (`/vendors`).  
2. Search business name / service / vendor code — results persist.  
3. Leave Marketplace **>30 seconds**, keep interacting.  
4. Confirm: no blank screen, no snap to hub/splash, search + filters remain, route stays `/vendors`.

---

## 11. Real-time regression tests

Preserved (tick still watched):

| Feature | Provider | Status |
|---------|----------|--------|
| Event vendor requests / messages | `eventVendorCrmProvider` + 5s tick | Preserved |
| Vendor inbox | `vendorInboxProvider` + 5s tick | Preserved |
| Request timeline | `vendorRequestTimelineProvider` + 5s tick | Preserved |
| Event vendor funds | `eventVendorFundsProvider` + 5s tick | Preserved |
| Attendee live program/updates | 10s scoped refresh | Unchanged |
| Hub vendor-alert badge | no longer 5s polled | Refresh via pull / `refreshVendorCrm` |

---

## 12. Remaining technical debt

| Item | Notes |
|------|-------|
| Seed `vendors.business_name` / `slug` | Still stored from account creation; not searched. Optional later backfill to public profile name. |
| Hub CRM alerts freshness | Badge updates on hub revisit / pull-to-refresh, not every 5s. |
| Catalog cap 100 rows | Unchanged. |
| `MarketplaceTabV3` | Still category-only (no text search); organizers use `/vendors`. |

---

## Conclusion

✅ ORGANIZER MARKETPLACE SEARCH + STABILITY REGRESSION FIXED
