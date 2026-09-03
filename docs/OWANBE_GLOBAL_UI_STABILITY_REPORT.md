# Owanbe Global UI Stability Report

**Date:** 2026-08-18  
**Scope:** Application-wide isolation of background data sync from UI / navigation lifecycle.

---

## Investigation (before coding)

This is not an Organizer Marketplace-only bug. The same visual “page loads again” appears across workspaces because **background updates were wired as Riverpod reloads**, and **Supabase JWT rotation replaced API-enriched auth state**.

Riverpod 2.x:

| Mechanism | Classification | Default UI |
|-----------|----------------|------------|
| `ref.watch(tick)` / `ref.watch(authSessionProvider)` object change | **Reload** | `skipLoadingOnReload: false` → full-page loading |
| `ref.invalidateSelf()` / `ref.refresh` | **Refresh** | `skipLoadingOnRefresh: true` → previous data stays |

No polling, messaging, request, or notification feature was disabled.

---

## 1. Root cause

**GLOBAL ROOT CAUSE:** Background synchronization was coupled to global UI lifecycle.

Two independently sufficient chains produced the 5–15s visual reset:

### A. Auth / session object replacement (global, all workspaces)

`AuthNotifier` treated `AuthChangeEvent.tokenRefreshed` (and repeat `initialSession`) as a full `AuthSession` replacement via `_sessionFromSupabase`.

That JWT-only object:

- cleared `roles` (`[]`)
- set `onboardingComplete: false`
- replaced API `displayName` with JWT metadata

`AuthSession` had no `==`. Every replacement notified every `ref.watch(authSessionProvider)`.

FutureProviders that watched the **whole session** (events, tickets, vendor id, hub, command center) **reloaded**. Screens using `.when(loading: () => EventLoadingSkeleton / CircularProgressIndicator)` replaced the visible page.

Gotrue auto-refresh ticks on the order of seconds; if `expiresAt` is near or the client refreshes early, this lands in the observed **5–15s** window. Even a single rotation after login looks like “the page loaded again.”

### B. Tick `watch` → FutureProvider reload (workspace-local, looks global)

Polling used `ref.watch(vendorCrmLiveTickProvider)` (5s) and `ref.watch(adminPollTickProvider)` (15s). That is a **dependency change = reload**, not a refresh.

Admin Control Tower **always** watches `financeStateProvider` (15s tick) in `AdminHomeScreen`. Organizer event planning **watched** `eventVendorCrmProvider.future`, so a 5s CRM tick rebuilt the planning/event tree. Vendor inbox/CRM screens used `.when(loading:)`.

Router: `RouterNotifier` notified GoRouter when `userIdentityProvider.isLoading` flipped, which can re-evaluate redirects and rebuild route widgets.

---

## 2. All periodic refresh mechanisms

Classification: **A** UI-local, **B** workspace-local, **C** cross-screen, **D** global.

| Mechanism | Interval | Provider / owner | Class | Invalidates others | Router | Workspace | Full-page loading (before) |
|-----------|----------|------------------|-------|--------------------|--------|-----------|----------------------------|
| Supabase `tokenRefreshed` | JWT / gotrue tick (~seconds–minutes) | `AuthNotifier` | **D** | All `watch(authSessionProvider)` FutureProviders | userId-only (already) | PortalAccessGuard rebuild | **Yes** |
| `vendorCrmLiveTickProvider` | 5s | CRM inbox / event CRM / timeline / funds | **B** (was **C/D** via aggregators) | Family data owners only (after fix) | No | No | **Yes** if `.when(loading)` / `watch(.future)` |
| `adminPollTickProvider` | 15s | `financeStateProvider`, summary, alerts | **B** (was **D** at Admin shell) | Finance providers | No | Admin shell rebuild | **Yes** (Control Tower chrome) |
| `attendeeLiveSyncProvider` | 10s | Live Hub program/updates | **A** | Scoped `ref.refresh` only | No | No | No (already scoped) |
| `attendeePassLiveSyncProvider` | 8s | Pass detail | **A** | `attendeeTicketsSyncProvider` while watching | No | No | Only on pass screens |
| Operations feed poll | 12s | `operationsFeedProvider` | **A** | Stream update, not Future reload | No | No | No |
| Event wall | 6–8s | Wall screens | **A** | Local setState / invalidate | No | No | Wall only |
| Invitations poll | 8s | Invitations screen | **A** | Hub payload | No | No | Invitations only |
| Executive overview | 10s | Local `setState` | **A** | Demo KPI only | No | No | No |
| Vendor dashboard clock | 1s | Local `setState` | **A** | Countdown only | No | No | No |
| Auth slideshow / boot | 0.6–4s | Auth shell | **A** | Unauthenticated only | No | No | Login only |
| `organizerVendorCrmAlertsProvider` | none | Hub badge | **B** | Manual / home refresh | No | No | Previously 5s; still not on tick |
| Identity `/auth/me` | on sign-in | `userIdentityProvider` | **D** only on userId change | Workspace apply | userId only (after fix) | Shell guard | Loading used to swap `.when` branches |

Real-time features **preserved:** messaging, request polling, negotiation, notifications, CRM live tick, attendee live, ops SSE+poll.

---

## 3. Global refresh dependency chain

### Incorrect (observed)

```
Supabase tokenRefreshed
  → AuthSession JWT-only replacement (roles cleared)
    → FutureProviders watching authSession reload
      → .when(loading) full-page skeleton / spinner
        → user sees the current screen “load again”
          (route unchanged; browser does not reload)

5s CRM tick  (watch(tick))
  → eventVendorCrmProvider reload
    → eventPlanningWorkspaceProvider watch(.future) reload
      → EventWorkspace / pipeline / vendors tab skeleton

15s admin tick (watch(tick))
  → financeStateProvider reload
    → AdminHomeScreen + top bar loading
```

### Correct (after fix)

```
User stays on current route
  → background poll / JWT rotation
    → data owner refreshes in place (invalidateSelf / silent JWT)
      → current widget tree remains mounted
        → previous data stays visible
          → new data replaces old data
```

---

## 4. Providers / services affected

| Provider / service | Change |
|--------------------|--------|
| `AuthNotifier` + `shouldReplaceAuthSessionForSupabaseEvent` | Ignore `tokenRefreshed`; ignore duplicate `initialSession` for same user |
| `AuthSession` | `==` / `hashCode`; `copyWith` preserves `roles` |
| `RouterNotifier` | Notify on identity **userId** only, not `isLoading` |
| `PortalAccessGuard` | Keep `child` mounted; no `AsyncValue.when` branch swap |
| `vendorCrmLiveTickProvider` consumers | `refreshOnAsyncTick` → `invalidateSelf` |
| `adminPollTickProvider` consumers | Same; tick stream aligned to yield-0-then-delay |
| Event planning / ops / closing aggregators | `refreshWhenDataChanges` + `read(.future)` (not `watch(.future)`) |
| `customerEventsProvider`, `customerEventProvider`, tickets, vendor session, hub events | `watchSignedInUser()` (userId only) |
| Shells (event, organizer hub, vendors tab, pipeline, vendor CRM/orders/dashboard, admin chrome) | `whenStable` / do not spinner-replace if `hasValue` |

---

## 5. Router impact

- `GoRouter` is not recreated.
- `refreshListenable` no longer fires on identity loading frames.
- Token refresh does not change `userId` → no redirect re-evaluation.
- Current route is unchanged (`/organizer/vendors` stays `/organizer/vendors`).

---

## 6. Workspace shell impact

- `WorkspaceExperienceShell` still switches workspace only when `active != widget.workspace`.
- `PortalAccessGuard` no longer remounts workspace children on identity loading.
- Vendor home no longer replaces the whole shell with a spinner when profile is **refreshing** (`hasValue` kept).
- Admin Control Tower finance chip no longer swaps to a spinner every 15s.

Workspace switching still occurs only when the user (or identity apply) actually changes workspace.

---

## 7. Files changed

| File | Change |
|------|--------|
| `mobile/lib/auth/auth_session.dart` | Equality + JWT replace policy |
| `mobile/lib/auth/auth_notifier.dart` | Silent token / duplicate initial session |
| `mobile/lib/router/router_notifier.dart` | Identity userId only |
| `mobile/lib/core/providers/silent_refresh.dart` | Tick refresh helpers + `whenStable` + `watchSignedInUser` |
| `mobile/lib/features/auth/widgets/portal_access_guard.dart` | Stable child |
| `mobile/lib/portals/customer/providers/vendor_crm_providers.dart` | Tick → invalidateSelf |
| `mobile/lib/features/admin/finance/admin_finance_providers.dart` | Tick → invalidateSelf |
| `mobile/lib/portals/customer/planning/event_planning_workspace_provider.dart` | CRM listen, not watch.future |
| `mobile/lib/portals/customer/operations/event_operations_workspace_provider.dart` | Same |
| `mobile/lib/portals/customer/closing/event_closing_workspace_provider.dart` | Same |
| `mobile/lib/portals/customer/providers/customer_event_providers.dart` | userId watch |
| `mobile/lib/portals/customer/providers/customer_home_providers.dart` | userId watch |
| `mobile/lib/portals/customer/providers/customer_event_command_providers.dart` | userId watch |
| `mobile/lib/features/public/providers/attendee_events_provider.dart` | userId watch |
| `mobile/lib/features/vendor/providers/vendor_providers.dart` | userId watch |
| `mobile/lib/features/home/providers/living_home_providers.dart` | userId watch |
| `mobile/lib/portals/customer/workspace/event_workspace.dart` | `whenStable` |
| `mobile/lib/portals/organizer/screens/organizer_home_hub_screen.dart` | `whenStable` |
| `mobile/lib/portals/customer/workspace/widgets/event_planning_center.dart` | `whenStable` |
| `mobile/lib/features/organizer/command_center_v3/tabs/vendors_tab_v3.dart` | `whenStable` |
| `mobile/lib/portals/customer/screens/customer_event_vendor_pipeline_screen.dart` | `whenStable` |
| `mobile/lib/features/vendor/vendor_home_screen.dart` | Keep shell when profile hasValue |
| `mobile/lib/features/vendor/screens/vendor_*.dart` (CRM, orders, dashboard, calendar) | `whenStable` on inbox |
| `mobile/lib/features/admin/shell/admin_top_bar.dart` | `whenStable` |
| `mobile/lib/features/admin/screens/admin_settings_screen.dart` | `whenStable` |
| `mobile/test/auth/auth_session_stability_test.dart` | JWT isolation tests |
| `mobile/test/core/silent_refresh_test.dart` | Refresh vs reload |
| `docs/OWANBE_GLOBAL_UI_STABILITY_REPORT.md` | This report |

---

## 8. Real-time features preserved

| Feature | Mechanism | Status |
|---------|-----------|--------|
| Vendor CRM / messages / requests | 5s tick + `invalidateSelf` | Preserved |
| Vendor inbox | Same | Preserved |
| Request timeline / funds | Same | Preserved |
| Admin finance live state | 15s tick + `invalidateSelf` | Preserved |
| Attendee live program/updates | 10s `ref.refresh` | Unchanged |
| Attendee pass watch | 8s invalidate while open | Unchanged |
| Ops live feed | 12s poll + SSE | Unchanged |
| Event wall / invitations timers | Screen-local | Unchanged |

---

## 9. Stability tests

| Test | Result |
|------|--------|
| `flutter test test/auth/auth_session_stability_test.dart` | ✅ 5/5 |
| `flutter test test/core/silent_refresh_test.dart` | ✅ 2/2 |
| `flutter test test/portals/customer/marketplace_search_test.dart` | ✅ 3/3 |
| Code trace: tokenRefreshed → no AuthSession notify | Verified |
| Code trace: 5s CRM tick → invalidateSelf refresh | Verified |
| Code trace: 15s admin tick → Control Tower chrome stable | Verified |
| Code trace: RouterNotifier identity isLoading | No longer notifies |

**Live 60s protocol (required on device/web):**

1. Open page, do not navigate, wait ≥ 60s, interact (scroll, type, open a dialog).
2. Confirm route unchanged and no full-page skeleton/spinner.
3. Confirm search query / filters / composer remain.

---

## 10. Cross-workspace regression results

Code-path verification (live 60s still recommended):

| Workspace | Screens | Background sync | UI after fix |
|-----------|---------|-----------------|--------------|
| Organizer | Dashboard, Marketplace, Event details, Vendor pipeline, Conversations | CRM 5s, events userId-only | Screen stays mounted; marketplace search already kept prior data |
| Vendor | Dashboard, Requests, Conversations, Orders | Inbox 5s | Inbox `whenStable`; shell not spinner-replaced |
| Attendee | Dashboard, Tickets, Event details | Tickets userId-only; live 10s scoped | No global ticket invalidation |
| Admin | Control Tower, Vendor Pricing, Finance | 15s finance tick | Top bar keeps prior finance state |

Messaging / request timers continue; they no longer invalidate the root shell or router.

---

## 11. Remaining technical debt

| Item | Notes |
|------|-------|
| Other FutureProviders still `watch(authSessionProvider)` | Analytics, finance, networking, attendee hub, etc. Silent JWT + `==` already stop token-driven reloads. Prefer `watchSignedInUser()` when touched. |
| Screens still using `.when(loading:)` without `whenStable` | First-load skeletons are correct; leftover modules may flash if their **dependencies** reload for non-auth reasons. |
| Hub `IndexedStack` / `context.push` | Home stays mounted under pushed routes; alert providers are one-shot (not 5s). |
| Gotrue JWT lifetime | If `expiresAt` is mis-parsed, the client may refresh often; UI is now isolated, but token churn is still wasted work. |
| Live 60s QA | Must be executed on web + Android for each workspace listed above. |

---

## PRIMARY TRIGGER

`AuthChangeEvent.tokenRefreshed` replacing API-enriched `AuthSession`, causing app-wide FutureProvider **reloads** into loading UI.

## SECONDARY TRIGGERS

1. `ref.watch(vendorCrmLiveTickProvider)` (5s) reload, including planning aggregators watching `.future`.  
2. `ref.watch(adminPollTickProvider)` (15s) on Control Tower `financeStateProvider`.  
3. `RouterNotifier` listening to identity `isLoading`.  
4. `PortalAccessGuard` / vendor home swapping the tree on loading.

## MINIMUM SAFE FIX

Silent JWT (do not clobber identity) + convert ticks from **watch/reload** to **listen + invalidateSelf/refresh** + keep already-visible screens via `whenStable`.

Do not disable polling, messaging, requests, or notifications.

---

## Conclusion

✅ OWANBE GLOBAL UI STABILITY COMPLETE
