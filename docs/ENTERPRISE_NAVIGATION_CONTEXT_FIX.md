# Enterprise Navigation Context Fix

**Status:** Implemented  
**Scope:** Remove `BuildContext` → `GoRouter` dependency from the enterprise back handler only.

---

## 1. Root Cause Analysis

### Error
```
'package:go_router/src/router.dart':
Failed assertion: 'inherited != null': No GoRouter found in context
```

### Cause
`EnterpriseBackHandler` called `GoRouter.of(context)` during `build()`. It was mounted from `MaterialApp.router`'s `builder`:

```dart
MaterialApp.router(
  builder: (context, child) => EnterpriseBackHandler(...),
)
```

That `builder` context sits **above** GoRouter's `InheritedWidget`. The handler's own `BuildContext` can never resolve `GoRouter` — this is an **architectural dependency inversion failure**, not a hot-restart bug.

Hot restart exposed it reliably because the widget tree rebuilds from scratch on the first frame.

---

## 2. Dependency Graph — Before

```
OwambeApp
  └── ref.watch(goRouterProvider) ──► GoRouter (owned)
  └── MaterialApp.router(routerConfig: router)
        └── builder: EnterpriseBackHandler
              └── GoRouter.of(context)  ✗ FAILS — context above inherited scope
                    └── child (Navigator) — GoRouter available here only
```

**Problem:** Router ownership and router lookup were split. The owner (`OwambeApp`) had the instance; the consumer (`EnterpriseBackHandler`) tried to find it via context.

---

## 3. Dependency Graph — After

```
OwambeApp
  └── GoRouter router = ref.watch(goRouterProvider)
  └── EnterpriseNavigationService(router)  ← created at injection site
  └── MaterialApp.router(routerConfig: router)
        └── builder: EnterpriseBackHandler(navigation: service)
              └── navigation.canSystemPop        ✓ direct router access
              └── navigation.handleSystemBack()  ✓ direct router access
                    └── child (Navigator)
```

**Principle:** The back handler depends on an **injected service**, not widget placement.

---

## 4. Injection Architecture

### New type: `EnterpriseNavigationService`

**File:** `mobile/lib/navigation/enterprise_navigation_service.dart`

| Method | Purpose |
|--------|---------|
| `canSystemPop` | Policy check using `router.state` + `router.canPop()` |
| `handleSystemBack()` | Pop or `go(fallback)` — Android back |
| `navigateBack()` | Same policy — AppBar back |
| `returnToHub()` | `go('/hub')` |

No `BuildContext`. No `GoRouter.of()`.

### Updated: `EnterpriseBackHandler`

**File:** `mobile/lib/navigation/enterprise_back_handler.dart`

```dart
EnterpriseBackHandler({
  required EnterpriseNavigationService navigation,
  required Widget child,
})
```

Factory for app wiring:

```dart
enterpriseBackHandler(router: router, child: child)
```

Uses `ListenableBuilder(listenable: router.routerDelegate)` so `canPop` stays in sync when the stack changes.

### App wiring: `OwambeApp`

```dart
final router = ref.watch(goRouterProvider);
// ...
builder: (context, child) => enterpriseBackHandler(
  router: router,
  child: child ?? const SizedBox.shrink(),
),
```

### UI layer: `ExperienceNavigation` (unchanged contract)

Screens inside the router tree still call:

- `ExperienceNavigation.returnToHub(context)`
- `ExperienceNavigation.navigateBack(context)`

These delegate to `EnterpriseNavigationService(GoRouter.of(context))` — **valid** because screen `BuildContext` is always below the inherited GoRouter. Only the **app-root back handler** required injection.

---

## 5. Navigation Policy Validation

| Scenario | Mechanism | Expected |
|----------|-----------|----------|
| Hot restart | Injected router, no inherited lookup | No assertion |
| Cold start | Same | No assertion |
| Hot reload | Same | No assertion |
| Organizer → Android Back | `handleSystemBack()` → `/hub` | ✅ |
| Attendee → Android Back | Policy fallback → `/hub` | ✅ |
| Vendor → Android Back | Policy fallback → `/hub` | ✅ |
| Event Desktop → Android Back | Pop or fallback → `/home` | ✅ |
| Hub → Android Back | `canSystemPop: true` | Exit app |

Policy rules unchanged — only **how the router is accessed** at app root changed.

---

## 6. Regression Analysis

### Files added
- `mobile/lib/navigation/enterprise_navigation_service.dart`
- `mobile/test/enterprise_navigation_service_test.dart`
- `docs/ENTERPRISE_NAVIGATION_CONTEXT_FIX.md`

### Files modified
- `mobile/lib/navigation/enterprise_back_handler.dart` — injection + `ListenableBuilder`
- `mobile/lib/app.dart` — passes router into factory
- `mobile/lib/identity/experience_navigation.dart` — delegates to service (UI context lookup retained)

### Audit: `GoRouter.of(context)` in navigation layer

| File | Before | After |
|------|--------|-------|
| `enterprise_back_handler.dart` | 2 calls | **0** — uses injected service |
| `experience_navigation.dart` | 2 calls | 2 — UI callbacks only (inside router tree) |
| All other lib files | N/A | Unchanged (screen-level navigation) |

### Not changed (per STOP instruction)
- Route definitions
- Navigation flows / fallbacks
- Business logic
- Workspace shells

---

## 7. Test Evidence

### `enterprise_navigation_policy_test.dart`
13/13 passed — zone classification and fallback matrix unchanged.

### `enterprise_navigation_service_test.dart`
- Hub `canSystemPop` allows exit
- `handleSystemBack` at `/home` → `/hub` without context lookup
- `returnToHub` / `navigateBack` use injected router only

Run:
```bash
cd mobile
flutter test test/enterprise_navigation_policy_test.dart test/enterprise_navigation_service_test.dart
```

---

## Summary

The enterprise back handler is now **placement-independent**. Whether mounted in `MaterialApp.builder`, a future shell, or a nested navigator, it only needs `EnterpriseNavigationService(router)` — the same instance `OwambeApp` already owns via Riverpod.

**Navigation architecture is permanently stabilized for context dependency.**
