# Enterprise Navigation Startup Stabilization

**Status:** Implemented  
**Scope:** Startup lifecycle and event-driven back handling only.

---

## 1. Root Cause

After GoRouter injection fixed `No GoRouter found in context`, cold start still crashed:

```
Bad state: No element
```

### Lifecycle violation

`EnterpriseBackHandler` read router state **during every build**:

```dart
// REMOVED — caused cold-start crash
ListenableBuilder(
  listenable: router.routerDelegate,
  builder: (_, __) => PopScope(
    canPop: navigation.canSystemPop,  // → router.state.matchedLocation
  ),
)
```

On cold `flutter run`, frame 0 runs **before** GoRouter has matched any route.  
`router.state` internally calls `RouteMatchList.last` on an **empty** list → crash.

Hot restart/reload often worked because the delegate already had matches from a prior session — timing luck, not stability.

---

## 2. Startup Lifecycle Timeline

```
Cold flutter run
─────────────────────────────────────────────────────────────
T0  main() → ProviderScope → OwambeApp.build()
T1  goRouterProvider creates GoRouter(initialLocation: '/')
T2  MaterialApp.router builder runs
T3  EnterpriseBackHandler.build()          ← MUST NOT read router.state
T4  GoRouter resolves redirects (auth, hub, splash…)
T5  RouteMatchList populated (matches.isNotEmpty)
T6  First screen visible
T7  User presses Android Back              ← SAFE to read route + apply policy
```

**Rule:** Navigation policy is **idle at T2–T4**, **active at T7+**.

---

## 3. Router Initialization Sequence

| Phase | `matches.isEmpty` | Policy state | Safe APIs |
|-------|-------------------|--------------|-----------|
| Pre-mount | yes | Idle | `isRouterReady == false` |
| Redirect resolution | yes → no | Idle → Active | `currentConfiguration.matches` |
| Post-mount | no | Active | `currentPath`, `handleSystemBack()` |

**Never use:** `router.state`, `router.state.matchedLocation` — always call `.last` internally.

**Use instead:** `router.routerDelegate.currentConfiguration.matches.isNotEmpty` and `configuration.uri.path`.

---

## 4. Architecture Before

```
EnterpriseBackHandler.build()
    │
    ├── ListenableBuilder (rebuild every route change)
    │       └── canPop: navigation.canSystemPop
    │               └── router.state.matchedLocation  ✗ CRASH at T2
    │
    └── onPopInvokedWithResult → handleSystemBack()
```

**Problems:**
- State-driven (evaluates policy every build)
- Assumes router always initialized
- Rebuilds on every navigation

---

## 5. Architecture After

```
EnterpriseBackHandler.build()
    │
    └── PopScope(canPop: false)     ← NO router reads during build
            │
            └── onPopInvokedWithResult (EVENT)
                    └── handleSystemBack()
                            ├── if !isRouterReady → return (idle)
                            ├── read currentPath (safe)
                            ├── hub → SystemNavigator.pop()
                            ├── canPop → router.pop()
                            └── else → router.go(fallback)
```

### New layer: `EnterpriseRouterReadiness`

**File:** `mobile/lib/navigation/enterprise_router_readiness.dart`

- `isReady(router)` — `matches.isNotEmpty`
- `currentPath(router)` — `configuration.uri.path`, or null

### Updated: `EnterpriseNavigationService`

| API | Startup behavior |
|-----|------------------|
| `isRouterReady` | false until matches exist |
| `currentLocation` | null while idle |
| `canNavigateBack` | false while idle |
| `handleSystemBack()` | no-op while idle |
| `returnToHub()` | no-op while idle |
| `navigateBack()` | delegates to `handleSystemBack()` |

No try/catch. No hidden errors. Explicit idle state.

---

## 6. Startup-Safe Design Principles

1. **Event-driven, not state-driven** — policy runs on back press only  
2. **No build-time router reads** — `EnterpriseBackHandler.build()` is pure  
3. **Readiness gate** — all route access goes through `EnterpriseRouterReadiness`  
4. **Injection preserved** — router still owned by `OwambeApp`, not `BuildContext`  
5. **Hub exit explicit** — `SystemNavigator.pop()` when policy allows app exit  

---

## 7. Validation Matrix

| Scenario | Mechanism | Expected |
|----------|-----------|----------|
| Cold `flutter run` | No build-time state read | No red screen |
| Hot restart | Event-driven handler | No red screen |
| Hot reload | Same | No red screen |
| Organizer → Android Back | `handleSystemBack()` → `/hub` | ✅ |
| Attendee → Android Back | fallback → `/hub` | ✅ |
| Vendor → Android Back | fallback → `/hub` | ✅ |
| Event Desktop → Android Back | pop or → `/home` | ✅ |
| Organizer top-bar Owanbe Home | `returnToHub()` | ✅ |
| Hub → Android Back | `SystemNavigator.pop()` | Exit app |

---

## 8. Stress Test Results

**Automated:** `enterprise_navigation_service_test.dart`

```
stress: 20 cold-start cycles without Bad state — PASSED
```

Each cycle:
1. Create fresh GoRouter (unmounted)
2. Call `handleSystemBack()` while idle — no throw
3. Pump `MaterialApp.router` + `EnterpriseBackHandler` — no throw on frame 0
4. Navigate Hub → Organizer → Attendee → Vendor → back — no throw

**Total navigation tests:** 22/22 passed  
(policy 13 + service/startup 9)

**Manual device stress:** Run on device:
```
flutter run → quit → flutter run (×20)
Hot restart between sessions
Navigate Hub / Organizer / Attendee / Vendor / Event Desktop
```

---

## 9. Regression Analysis

### Files added
- `mobile/lib/navigation/enterprise_router_readiness.dart`
- `docs/ENTERPRISE_NAVIGATION_STARTUP_STABILIZATION.md`

### Files modified
- `mobile/lib/navigation/enterprise_navigation_service.dart` — readiness gate, event-driven API
- `mobile/lib/navigation/enterprise_back_handler.dart` — removed `ListenableBuilder`, event-only
- `mobile/test/enterprise_navigation_service_test.dart` — startup + 20-cycle stress

### Unchanged
- `EnterpriseNavigationPolicy` — pure path logic
- Route definitions, workspaces, Event OS, business logic
- `ExperienceNavigation` UI contract (delegates to service)

### Audit: unsafe API usage in navigation layer

| File | `router.state` | Status |
|------|----------------|--------|
| `enterprise_navigation_service.dart` | Removed | Uses `EnterpriseRouterReadiness` |
| `enterprise_back_handler.dart` | None | Event-driven only |
| `enterprise_router_readiness.dart` | None | Uses `currentConfiguration` |
| `experience_navigation.dart` | None | Delegates to service |

---

## Summary

Three-layer enterprise navigation stack:

```
EnterpriseNavigationPolicy     — pure path rules (no router)
EnterpriseRouterReadiness      — startup-safe route introspection
EnterpriseNavigationService    — event-driven actions (injected router)
EnterpriseBackHandler          — PopScope wrapper (no build-time reads)
```

Navigation is now **injection-safe** (Fix #1) and **startup-safe** (Fix #2).

**Production-grade requirement:** Cold start must never crash before the user can test back navigation.
