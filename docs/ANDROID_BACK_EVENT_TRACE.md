# Android Back Event Trace

**Status:** Diagnosis only — no implementation  
**Date:** 2026-07-15  
**Evidence:** Runtime user facts + `go_router` 14.8.1 source + Owambe codebase audit

---

## Executive Summary

Android Back from Organizer Workspace (`/home`) **exits the application** instead of navigating to `/hub`.

**← Owanbe Home** (top bar button) **works** — proves `ExperienceNavigation.returnToHub()` and `router.go('/hub')` are correct.

Therefore the `/hub` policy is **not broken**. It is **bypassed** because the Android Back event **never reaches** `EnterpriseBackHandler` or `EnterpriseNavigationService.handleSystemBack()`.

---

## 1. Proven Runtime Facts

| Observation | Source | Implication |
|-------------|--------|-------------|
| **← Owanbe Home** navigates to `/hub` | User device test | `returnToHub()` ✓, `router.go('/hub')` ✓, redirects ✓ |
| Android Back exits app | User device test + terminal log | System back path does **not** call `go('/hub')` |
| Terminal: `ViewPostIme key` → `surfaceDestroyed` → `dispatchDetachedFromWindow` | `terminals/2.txt:990–1019` | Android **Activity is finishing** — not an in-app route change |

---

## 2. Specific YES / NO Answers

| Question | Answer | Evidence |
|----------|--------|----------|
| Does `onPopInvoked` execute? | **NO** | If YES → `handleSystemBack()` → `go('/hub')` → user would land on hub, not exit. Button path proves `go('/hub')` works. |
| Does `EnterpriseNavigationService.handleSystemBack()` execute? | **NO** | Same as above — only invoked from `onPopInvoked` in `EnterpriseBackHandler`. |
| Does GoRouter consume Back before PopScope? | **YES** | `go_router` 14.8.1 wires `RootBackButtonDispatcher` → `GoRouterDelegate.popRoute()` → `Navigator.maybePop()`. Owambe `PopScope` is in `MaterialApp.builder`, **outside** route builders. |
| Does the Activity receive `finish()` before navigation? | **YES** | Terminal shows surface destroyed and window detached — consistent with `popRoute()` returning `false` and the platform closing the Activity. |

> **Note:** `onPopInvoked` / `handleSystemBack` answers are **logically proven** from behavior (exit vs hub). Instrumentation logs (below) would make this formally observable in a follow-up step.

---

## 3. Complete Back-Event Flow

### 3.1 What happens today (Organizer `/home`)

```
[1] User presses Android Back key
         │
         ▼
[2] Android MainActivity
    ViewPostIme key 0 / key 1
         │
         ▼
[3] Flutter engine: WidgetsBinding.handlePopRoute()
         │
         ▼
[4] BackButtonDispatcher (priority chain)
    Owner: GoRouter.backButtonDispatcher
    Class: RootBackButtonDispatcher
    File:  go_router-14.8.1/lib/src/router.dart:186
         │
         ▼
[5] RouterDelegate.popRoute()
    Owner: GoRouterDelegate
    File:  go_router-14.8.1/lib/src/delegate.dart:57
         │
         ├── _findCurrentNavigator()
         │     For StatefulShellRoute (/home):
         │     → shell branch NavigatorState (indexedStack)
         │
         ├── state.maybePop()
         │     Branch has single route (/home), no stack
         │     No PopScope on OrganizerHomeHubScreen
         │     → didPop = false
         │
         ├── onExit fallback (delegate.dart:66–74)
         │     /home GoRoute has NO onExit defined
         │     (customer_shell_route.dart)
         │
         └── return false
         │
         ▼
[6] handlePopRoute() returns false
         │
         ▼
[7] Platform closes Activity
    surfaceDestroyed, dispatchDetachedFromWindow
         │
         ✗ NEVER REACHED:
[8] EnterpriseBackHandler.onPopInvokedWithResult
[9] EnterpriseNavigationService.handleSystemBack()
[10] router.go('/hub')
```

### 3.2 What happens for ← Owanbe Home (working path)

```
User taps TextButton
    │
    ▼
WorkspaceContextActions.onPressed
    File: workspace_experience_shell.dart:66
    │
    ▼
ExperienceNavigation.returnToHub(context)
    File: experience_navigation.dart:52–54
    │
    ▼
EnterpriseNavigationService.returnToHub()
    File: enterprise_navigation_service.dart:60–63
    │
    ▼
router.go('/hub')   ✓ WORKS
```

**Android Back and UI Home use completely different pipelines.**

---

## 4. Execution Trace by Stage

| Stage | Component | File / Class | Executes on Android Back? |
|-------|-----------|--------------|----------------------------|
| 1 | Hardware back | `MainActivity` | **YES** (terminal log) |
| 2 | Pop route dispatch | `WidgetsBinding.handlePopRoute` | **YES** (implicit) |
| 3 | Back dispatcher | `RootBackButtonDispatcher` | **YES** (GoRouter default) |
| 4 | Router delegate | `GoRouterDelegate.popRoute` | **YES** |
| 5 | Shell navigator | `StatefulShellBranch` Navigator | **YES** (`maybePop` called) |
| 6 | Route PopScope | None on `/home` page | **N/A** |
| 7 | App builder PopScope | `EnterpriseBackHandler` | **NO** (not in maybePop chain) |
| 8 | `onPopInvokedWithResult` | `enterprise_back_handler.dart:24` | **NO** |
| 9 | `handleSystemBack()` | `enterprise_navigation_service.dart:34` | **NO** |
| 10 | `router.go('/hub')` | policy fallback | **NO** |
| 11 | Activity finish | Android platform | **YES** (terminal log) |

---

## 5. First Component That Consumes Back

| Property | Value |
|----------|-------|
| **First consumer** | `GoRouterDelegate.popRoute()` |
| **File** | `go_router` package: `lib/src/delegate.dart` |
| **Class** | `GoRouterDelegate` |
| **Method** | `popRoute()` (line 57) |
| **Called from** | `RootBackButtonDispatcher` via Flutter `Router` / `WidgetsBinding.handlePopRoute` |

### Call stack (conceptual — from framework + go_router source)

```
MainActivity.onBackPressed / predictive back
  → FlutterJNI
  → WidgetsBinding.handlePopRoute()
  → RootBackButtonDispatcher.notifyListeners()
  → Router._handleBackButtonDispatcherNotification
  → GoRouterDelegate.popRoute()                    ← FIRST OWNED CONSUMER
       → _findCurrentNavigator()
       → NavigatorState.maybePop()                 ← shell branch, /home
       → (false — nothing to pop)
       → onExit check (null on /home)
       → return false
  → handlePopRoute returns false
  → Activity.finish() / window teardown
```

**`EnterpriseBackHandler` is not in this stack.**

---

## 6. Why `/hub` Policy Is Bypassed

### 6.1 Placement: `PopScope` is outside the route tree

Owambe mounts the handler here:

```dart
// app.dart
MaterialApp.router(
  builder: (context, child) => enterpriseBackHandler(
    router: router,
    child: child ?? const SizedBox.shrink(),
  ),
)
```

```dart
// enterprise_back_handler.dart
PopScope(
  canPop: false,
  onPopInvokedWithResult: (_, __) => navigation.handleSystemBack(),
  child: child,
)
```

This `PopScope` wraps the **Router output**, not an individual **GoRoute page**.

### 6.2 go_router only consults PopScope inside routes

`go_router` 14.8.1 includes an explicit test proving PopScope works when placed **inside** `GoRoute.builder`:

```dart
// go_router-14.8.1/test/delegate_test.dart:95–130
GoRoute(
  path: '/',
  builder: (_, __) => PopScope(   // ← INSIDE route builder
    onPopInvokedWithResult: ...
    child: const Text('Home'),
  ),
),
await tester.binding.handlePopRoute();
expect(didPop, isTrue);
```

Owambe's `PopScope` is in `MaterialApp.builder` — **not** equivalent to this test setup.

### 6.3 StatefulShellRoute adds a nested navigator

Organizer workspace uses:

```dart
// customer_shell_route.dart
StatefulShellRoute.indexedStack(
  builder: (context, state, navigationShell) => WorkspaceExperienceShell(...),
  branches: [ GoRoute(path: '/home', ...) ],
)
```

`GoRouterDelegate.popRoute()` calls `maybePop()` on the **shell branch Navigator**, not on widgets above the Router. No `PopScope` exists inside:

- `OrganizerHomeHubScreen`
- `CustomerShell`
- `WorkspaceExperienceShell`

### 6.4 Stack replaced by `go('/home')`

Hub → Organizer uses `context.go('/home')`. `/hub` is not on the stack. When `maybePop()` runs:

- `canPop` = false
- No custom handler registered in go_router pipeline
- `popRoute()` returns **false** → platform exits

Policy code in `EnterpriseNavigationService` handles exactly this case — but **only if invoked**.

---

## 7. Codebase Audit — Router State Access (Navigation Layer)

| File | Reads `router.state`? | In Android Back chain? |
|------|----------------------|------------------------|
| `enterprise_back_handler.dart` | No | **Intended** handler — **not reached** |
| `enterprise_navigation_service.dart` | No (uses `currentConfiguration`) | **Not reached** on back |
| `enterprise_router_readiness.dart` | No | **Not reached** on back |
| `experience_navigation.dart` | Via `GoRouter.of(context)` | UI button only — **works** |

**No navigation-layer bug in policy logic.** Integration point is wrong for Android Back.

---

## 8. Recommended Instrumentation (Future — Not Implemented)

To convert inferred NO answers into logged proof, add **temporary** `debugPrint` at:

| Log tag | Location | Expected on `/home` back |
|---------|----------|------------------------|
| `[BACK-1]` | `EnterpriseBackHandler.onPopInvokedWithResult` | **Silent** (proves NO) |
| `[BACK-2]` | `EnterpriseNavigationService.handleSystemBack` entry | **Silent** (proves NO) |
| `[BACK-3]` | Custom wrapper around `GoRouterDelegate.popRoute` | **Would print** |
| `[BACK-4]` | After `maybePop` in delegate | `didPop: false` |

**Per STOP rule: instrumentation not added in this deliverable.**

---

## 9. Recommended Permanent Architecture (Diagnosis Only)

Do **not** move `PopScope` in `MaterialApp.builder` — proven ineffective for this case.

### Option A — **GoRoute `onExit`** (go_router-native)

`GoRouterDelegate.popRoute()` already falls back to `onExit` when `maybePop()` fails (`delegate.dart:66–74`).

Add `onExit` on organizer workspace routes (`/home`, shell routes) that calls `EnterpriseNavigationService.handleSystemBack()` or `router.go('/hub')`.

**Pros:** Inside documented go_router back pipeline  
**Cons:** Per-route wiring (or shared helper)

### Option B — **PopScope inside route tree**

Wrap `WorkspaceExperienceShell` or shell `builder` output with `PopScope` / delegate to `handleSystemBack()`.

**Pros:** Matches go_router test pattern  
**Cons:** Must be inside `StatefulShellRoute.builder`, not `MaterialApp.builder`

### Option C — **Custom `BackButtonDispatcher`**

Replace `RootBackButtonDispatcher` with a dispatcher that calls `EnterpriseNavigationService` first.

**Cons:** `GoRouter` 14.8.1 constructs `RootBackButtonDispatcher` internally (line 186) — not constructor-injectable without wrapper/fork.

### Recommended path

**Option A + B combined:**

1. Primary: hook **`GoRouterDelegate.popRoute` fallback** via `onExit` on workspace `GoRoute`s  
2. Secondary: `PopScope` inside `WorkspaceExperienceShell` for shells without `onExit` coverage  
3. Keep `EnterpriseNavigationService` as single policy implementation (already startup-safe)  
4. Remove or demote `MaterialApp.builder` `EnterpriseBackHandler` once real hook is proven — it does not participate in Android Back today

---

## 10. Validation Matrix (Post-Fix Targets)

| Scenario | Current | Target |
|----------|---------|--------|
| Cold `flutter run` | ✓ loads | ✓ |
| Android Back on `/home` | ✗ exits app | → `/hub` |
| ← Owanbe Home on `/home` | ✓ `/hub` | ✓ (unchanged) |
| Android Back on `/hub` | ? (likely exits) | Exit app |
| Hot restart / reload | ✓ | ✓ |

---

## 11. Regression / What NOT to Change (Per STOP Rule)

- Do not patch with try/catch around `RouteMatchList.last`
- Do not move `PopScope` in `MaterialApp.builder` expecting it to fix Android Back
- Do not change route paths or workspace structure
- Do not change `returnToHub()` — it already works

---

## 12. Conclusion

| Layer | Status |
|-------|--------|
| Policy (`/home` → `/hub`) | ✓ Correct |
| UI navigation (`returnToHub`) | ✓ Works |
| Startup / injection fixes | ✓ Valid |
| Android Back integration | ✗ **Broken** — handler not in go_router back chain |

**Root cause (proven):** Android Back is owned by **`GoRouterDelegate.popRoute()`**, which returns **`false`** on root shell routes with no `onExit` and no in-route `PopScope`. The platform then **finishes the Activity**. `EnterpriseBackHandler` in `MaterialApp.builder` is **architecturally invisible** to this pipeline.

**Next step (when approved):** Integrate `EnterpriseNavigationService` into the **go_router back pipeline** (`onExit` and/or in-route handler) — not another `MaterialApp.builder` patch.
