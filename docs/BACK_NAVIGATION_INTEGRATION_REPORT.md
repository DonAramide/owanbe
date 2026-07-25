# Back Navigation Integration Report

**Status:** Implemented  
**Scope:** Android Back integration only — no router redesign, no business logic changes

---

## 1. Problem (Proven)

Per [`ANDROID_BACK_EVENT_TRACE.md`](ANDROID_BACK_EVENT_TRACE.md):

- **← Owanbe Home** worked (`returnToHub()` → `router.go('/hub')`)
- **Android Back** exited the app from `/home`
- `EnterpriseBackHandler` in `MaterialApp.builder` was **never in go_router's back dispatch chain**

---

## 2. Final Architecture

```
Android Back (hardware)
        │
        ▼
RootBackButtonDispatcher
        │
        ▼
GoRouterDelegate.popRoute()
        │
        ▼
Navigator.maybePop() on active route
        │
        ▼
PopScope on ACTIVE PAGE (inside route tree)    ← FIX
        │
        ▼
ExperienceNavigation.navigateBack(context)
        │
        ▼
EnterpriseNavigationService.handleSystemBack()
        │
        ├── hub → SystemNavigator.pop() (exit)
        ├── canPop → router.pop()
        └── fallback → router.go(policy target)
```

**← Owanbe Home** uses the same service:

```
TextButton.onPressed
  → ExperienceNavigation.returnToHub(context)
  → EnterpriseNavigationService.returnToHub()
  → router.go('/hub')
```

**Single policy. Two entry points. No duplicated switch logic.**

---

## 3. Integration Points

### Primary: `WorkspaceExperienceShell`

All workspace shells (Organizer, Attendee, Vendor) mount back handling here:

```dart
PortalAccessGuard(
  child: WorkspaceBackScope(
    child: widget.child,
  ),
)
```

**Used by:**
- `customer_shell_route.dart` — Organizer `StatefulShellRoute`
- `vendor_home_screen.dart` — Vendor
- `attendee_dashboard_screen.dart` — Attendee
- `attendee_flow_scaffold.dart` — Attendee sub-routes
- `attendee_find_ticket_screen.dart`

### Secondary surfaces (same `WorkspaceBackScope` widget)

Routes outside the shell but needing system back:

| Surface | File |
|---------|------|
| Hub (exit) | `owanbe_home_screen.dart` |
| Event Desktop | `customer_event_route_screen.dart` |
| Event modules | `event_module_scaffold.dart` |
| Portfolio | `organizer_portfolio_workspace_screen.dart` |

### Removed (ineffective)

| Removed from | Why |
|--------------|-----|
| `app.dart` `MaterialApp.builder` | Outside go_router back chain — proven by trace |

---

## 4. Core Widget

**File:** `mobile/lib/navigation/enterprise_back_handler.dart`

```dart
class WorkspaceBackScope extends StatelessWidget {
  // PopScope inside route tree only
  onPopInvoked → ExperienceNavigation.navigateBack(context)
}
```

Alias: `WorkspaceBackHandler`

---

## 5. Policy Updates

| Zone | Android Back fallback |
|------|----------------------|
| `/hub` | Exit app |
| Organizer shell (`/home`, tabs) | `/hub` |
| Attendee root | `/hub` |
| Vendor root | `/hub` |
| Portfolio | `/hub` (updated per validation matrix) |
| Event module | Pop → Event Desktop |
| Event Desktop | `/home` (Organizer) |
| Pushed screens | `router.pop()` when `canPop` |

---

## 6. Runtime Validation Matrix

| # | Scenario | Expected | Automated evidence |
|---|----------|----------|-------------------|
| 1 | Hub → Android Back | Exit app | Policy: `allowsAppExit('/hub')` ✓ |
| 2 | Organizer `/home` → Back | → Hub | `workspace_back_scope_test` ✓ |
| 3 | Attendee root → Back | → Hub | Policy test ✓ |
| 4 | Vendor root → Back | → Hub | Policy test ✓ |
| 5 | Portfolio → Back | → Hub | Policy test ✓ |
| 6 | Event Desktop → Back | → Organizer | Policy: overview → `/home` ✓ |
| 7 | Vendor Pipeline → Back | → Event Desktop | Policy: module → overview ✓ |
| 8 | Guests → Back | → Event Desktop | Policy test ✓ |
| 9 | Tickets Manage → Back | → Event Desktop | Policy test ✓ |
| 10 | Deep chain pop sequence | Pop chain then hub then exit | `workspace_back_scope_test` guests pop ✓ |

**Test suite:** 25/25 passed  
- `enterprise_navigation_policy_test.dart` (13)  
- `enterprise_navigation_service_test.dart` (10)  
- `workspace_back_scope_test.dart` (3)

**Device verification:** Hot restart, then:
1. Hub → Organizer → **Android Back** → should land on Hub (not exit)
2. Hub → **Android Back** → should exit

---

## 7. Regression Report

| Area | Impact |
|------|--------|
| Attendee navigation | Unchanged routes; back now via shell `WorkspaceBackScope` |
| Organizer routing | Unchanged; shell owns back |
| Vendor routing | Unchanged; shell owns back |
| Authentication | No changes |
| Workspace switching | No changes |
| Event OS | Modules + desktop wrapped with same scope |
| Boot sequence | `MaterialApp.builder` handler removed — no startup crash |
| Router redirects | No new redirects |
| Deep links | No changes |
| ← Owanbe Home button | Unchanged — same `EnterpriseNavigationService` |

---

## 8. Why This Is Permanent

1. **Matches go_router's proven pattern** — PopScope inside `GoRoute.builder` (see go_router `delegate_test.dart:95`)
2. **Aligns with runtime trace** — back consumed at route level, not `MaterialApp.builder`
3. **Single policy service** — `EnterpriseNavigationService` for both system back and UI home
4. **Workspace-owned** — `WorkspaceExperienceShell` is the canonical integration point for all workspaces
5. **No `onExit` hacks** — no per-route exit callbacks as primary mechanism
6. **No duplicated logic** — one `WorkspaceBackScope`, one service, one policy class

---

## 9. Files Changed

| File | Change |
|------|--------|
| `enterprise_back_handler.dart` | `WorkspaceBackScope` (in-route only) |
| `workspace_experience_shell.dart` | Mount `WorkspaceBackScope` |
| `app.dart` | Remove ineffective builder handler |
| `owanbe_home_screen.dart` | Hub back scope |
| `customer_event_route_screen.dart` | Event desktop scope |
| `event_module_scaffold.dart` | Module scope |
| `organizer_portfolio_workspace_screen.dart` | Portfolio scope |
| `enterprise_navigation_policy.dart` | Portfolio → `/hub` |
| Tests + this report | Added |

**Not changed:** `app_router.dart` structure, workspace screens business logic, `ExperienceNavigation` public API.

---

**STOP** — integration complete. Device-test Android Back from Organizer to confirm Hub navigation.
