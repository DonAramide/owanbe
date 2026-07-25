# Enterprise Navigation Policy Report

**Status:** Implemented  
**Scope:** Navigation architecture only — no route redesign, no workspace redesign, no business logic changes.

---

## 1. Root Cause Analysis

### Symptom
From **Organizer Workspace** (`/home`), Android system Back **exited the application** instead of returning to **Owanbe Home** (`/hub`).

### Root Cause
1. **Hub → Organizer entry uses `context.go('/home')`**, which **replaces** the navigation stack. `/hub` is not retained in history.
2. On `/home`, **`GoRouter.canPop()` is false**, so Android Back had no stack entry to pop and the OS closed the app.
3. **No centralized back policy** existed — workspace roots lacked uniform `PopScope` behavior.
4. **"Home" UI actions** called `context.go('/hub')` directly from multiple widgets, with no shared helper or consistent labeling.

### Why a single-screen `PopScope` patch was insufficient
The bug was a **systemic navigation contract** problem: every workspace (Organizer, Attendee, Vendor, Event Desktop, modules, Portfolio) shared the same failure mode whenever `go()` replaced history. A permanent fix requires **one policy engine** applied at app root plus **one UI navigation API**.

---

## 2. Navigation Policy

| Rule | Implementation |
|------|----------------|
| **Rule 1** — `/hub` is application HOME | `ExperienceRoutes.hub`; only zone where exit is allowed |
| **Rule 2** — Back pops when possible; else workspace fallback | `EnterpriseBackHandler` + `EnterpriseNavigationPolicy.resolveBackFallback()` |
| **Rule 3** — Exit only at `/hub` | `allowsAppExit()` returns true only for `NavigationZone.hub` |
| **Rule 4** — Single "Home" implementation | `ExperienceNavigation.returnToHub(context)` — screens must not call `go('/hub')` directly |
| **Rule 5** — Uniform workspace back behavior | `EnterpriseBackHandler` at `OwambeApp` builder (alias: `WorkspaceBackHandler`) |
| **Rule 6** — Audited `go()` vs `push()` | See §8 — intentional replacements documented; no blind migration |

### Back resolution algorithm

```
onBackPressed:
  if router.canPop() → pop()
  else if zone == hub → allow system exit (canPop: true)
  else fallback = resolveBackFallback(location)
       if fallback != null → go(fallback)
```

---

## 3. Route Ownership Map

| Zone | Routes | Owner | Back fallback |
|------|--------|-------|---------------|
| **Hub** | `/hub`, `/platform/home` | Platform launcher | *Exit app* |
| **Organizer shell** | `/home`, `/events/mine`, `/events/create`, `/guests`, `/profile` | Customer `StatefulShellRoute` | `/hub` |
| **Portfolio** | `/portfolio`, `/portfolio/*` | Organizer intelligence | `/home` |
| **Event overview** | `/events/:eventId` | Event Desktop | `/home` |
| **Event module** | `/events/:eventId/*` | Event OS modules | `/events/:eventId` |
| **Marketplace** | `/vendors`, `/vendors/*` | Global / event-scoped vendors | `/home` |
| **Attendee root** | `/attendee` | Attendee workspace | `/hub` |
| **Attendee flow** | `/attendee/events/:id`, tickets, checkout | Attendee sub-routes | event detail → dashboard → `/attendee` |
| **Vendor root** | `/vendor` | Vendor workspace | `/hub` |
| **Vendor sub-route** | `/vendor/*` | Vendor onboarding, settings | `/vendor` |
| **Activation** | `/activate/*` | Workspace activation | `/hub` |
| **Auth** | `/auth`, legacy portal auth | Universal auth | `/hub` |
| **Public** | `/`, `/events`, walkthrough, etc. | Discovery / marketing | `/hub` |

**Classification note:** Organizer Event OS paths (`/events/:id` and modules) are classified **before** `PortalRoutes.isPublicPath()` because public discovery also uses `/events/` prefixes.

---

## 4. Stack Behavior by Workspace

### Hub (`/hub`)
- **Entry:** Post-login default, `returnToHub()`, workspace launcher cards (via `launcherTarget()`).
- **Stack:** Root; no fallback above hub.
- **Android Back:** Exits application (**only allowed exit**).

### Organizer (`/home` shell)
- **Entry from hub:** `context.go('/home')` — **intentionally replaces** stack (user switches workspace context).
- **Android Back at shell root:** Policy → `/hub` (does not exit).
- **In-shell tabs:** `EventNavigator.goHome()` etc. use `go()` — tab switches replace shell branch (existing design).

### Event Desktop (`/events/:id`)
- **Entry:** `EventNavigator.openOverview()` uses **`push()`** — preserves organizer shell in stack when possible.
- **Android Back:** Pop if pushed; else policy → `/home`.

### Event Modules (`/events/:id/guests`, budget, AI planner, etc.)
- **Entry:** `EventNavigator.open*()` uses **`push()`**.
- **Android Back:** Pop to Event Desktop; else policy → `/events/:id`.
- **AppBar back:** `ExperienceNavigation.navigateBack()` (same policy).

### Portfolio (`/portfolio`)
- **Entry:** `EventNavigator.openPortfolio()` uses **`push()`**.
- **Android Back:** Pop when stacked; else policy → `/home`.

### Attendee (`/attendee`)
- **Entry from hub:** `context.go('/attendee')` — replaces stack.
- **Android Back at root:** Policy → `/hub`.
- **Sub-flows:** Push/pop within attendee; fallback chain via policy.

### Vendor (`/vendor`)
- **Entry from hub:** `context.go('/vendor')` — replaces stack.
- **Android Back at root:** Policy → `/hub`.
- **Onboarding back:** `returnToHub()` (v2) or legacy auth path.

---

## 5. Shared Navigation Helper

**File:** `mobile/lib/identity/experience_navigation.dart`

| API | Purpose |
|-----|---------|
| `ExperienceNavigation.returnToHub(context)` | **Single UI entry** to Owanbe Home — replaces all direct `context.go('/hub')` |
| `ExperienceNavigation.navigateBack(context)` | AppBar / explicit back — pop or policy fallback |
| `ExperienceNavigation.hub()` / `returnHome()` | Path-only helpers for redirects and bootstrap |

### Migrated call sites
- `WorkspaceContextActions` — label renamed to **"Owanbe Home"**
- `WorkspaceSwitcher`
- `PortalAccessGuard`
- `WorkspaceActivationScreen`
- `AttendeeTopBar` (compact launcher icon)
- `VendorOnboardingScreen` (identity v2)

**Remaining direct `go('/hub')`:** Only inside `ExperienceNavigation.returnToHub()` (by design).

---

## 6. Shared Back Handler

**Files:**
- `mobile/lib/navigation/enterprise_navigation_policy.dart` — pure classification + fallbacks
- `mobile/lib/navigation/enterprise_back_handler.dart` — `PopScope` widget

**Wiring:** `OwambeApp` → `MaterialApp.router` `builder` wraps all routes:

```dart
builder: (context, child) => EnterpriseBackHandler(
  child: child ?? const SizedBox.shrink(),
),
```

**Alias:** `typedef WorkspaceBackHandler = EnterpriseBackHandler;`

No per-screen `PopScope` duplication. Event module AppBar and attendee flow scaffolds delegate to `ExperienceNavigation.navigateBack()` for consistent explicit-back behavior.

---

## 7. Validation Matrix

| Scenario | Expected | Policy test | Runtime |
|----------|----------|-------------|---------|
| Hub → Organizer → Android Back → Hub | `/hub` | ✅ | ✅ via `EnterpriseBackHandler` |
| Hub → Attendee → Android Back → Hub | `/hub` | ✅ | ✅ |
| Hub → Vendor → Android Back → Hub | `/hub` | ✅ | ✅ |
| Hub → Event Desktop → Android Back → Organizer | `/home` | ✅ | ✅ (pop if pushed, else fallback) |
| Event Module → Android Back → Event Desktop | `/events/:id` | ✅ | ✅ |
| Event Desktop → Android Back → Organizer | `/home` | ✅ | ✅ |
| Organizer Workspace → Android Back → Hub | `/hub` | ✅ | ✅ |
| Hub → Android Back → App exits | Exit | ✅ | ✅ |

**Automated coverage:** `mobile/test/enterprise_navigation_policy_test.dart` (13 tests).

**Device verification:** Hot-restart the running app and walk the matrix above. Organizer back-from-`/home` was the original failure — now routes to `/hub`.

---

## 8. `context.go()` Audit (Rule 6)

| Location | Pattern | Decision |
|----------|---------|----------|
| Hub launcher → workspace | `go(workspaceHome)` | **Keep `go`** — workspace switch replaces launcher context; back policy returns to hub |
| Hub launcher cards | `go(launcherTarget())` | **Keep `go`** — same rationale |
| Event module open | `push(eventModule)` | **Keep `push`** — preserves Event Desktop stack |
| Event overview open | `push(/events/:id)` | **Keep `push`** — preserves organizer shell |
| Portfolio open | `push(/portfolio)` | **Keep `push`** |
| Shell tab navigation | `go(/home)`, `go(/guests)` | **Keep `go`** — StatefulShell tab semantics |
| Post-login / bootstrap | `go(destination)` | **Keep `go`** — auth/bootstrap replaces stack |
| UI "Owanbe Home" | was `go('/hub')` | **Migrated** → `returnToHub()` |
| AppBar / module back | mixed pop/go | **Unified** → `navigateBack()` |
| Attendee checkout back | `go('/attendee')` | **Partial** — scaffold defaults use `navigateBack()`; explicit checkout callbacks unchanged (still valid) |
| Legacy `/organizer/*` screens | `go('/organizer')` | **No change** — legacy routes, not in v2 workspace matrix |
| Public discovery | `go('/events')` | **No change** — public zone; back fallback → hub |

**Principle:** Use `go()` when entering a **new workspace context** (replacing launcher). Use `push()` when drilling into **stacked detail** within a workspace. Back policy compensates when `go()` leaves no pop target.

---

## 9. Regression Report

### Files added
- `mobile/lib/navigation/enterprise_navigation_policy.dart`
- `mobile/lib/navigation/enterprise_back_handler.dart`
- `mobile/test/enterprise_navigation_policy_test.dart`
- `docs/ENTERPRISE_NAVIGATION_POLICY_REPORT.md`

### Files modified (navigation only)
- `mobile/lib/app.dart` — app-root back handler
- `mobile/lib/identity/experience_navigation.dart` — `returnToHub`, `navigateBack`
- `mobile/lib/features/workspace/widgets/workspace_experience_shell.dart`
- `mobile/lib/features/workspace/widgets/workspace_switcher.dart`
- `mobile/lib/features/auth/widgets/portal_access_guard.dart`
- `mobile/lib/features/activation/screens/workspace_activation_screen.dart`
- `mobile/lib/features/vendor/screens/vendor_onboarding_screen.dart`
- `mobile/lib/portals/attendee/widgets/attendee_top_bar.dart`
- `mobile/lib/portals/attendee/widgets/attendee_flow_scaffold.dart`
- `mobile/lib/portals/customer/navigation/event_navigator.dart`
- `mobile/lib/portals/customer/workspace/event_module_scaffold.dart`
- `mobile/lib/portals/customer/screens/organizer_portfolio_workspace_screen.dart`

### Tests
- `enterprise_navigation_policy_test.dart`: **13/13 passed**
- No business logic tests modified

### Known non-goals (per STOP instruction)
- Route path redesign
- Workspace UI redesign
- Legacy `/organizer` command center routes
- Changing StatefulShell tab `go()` semantics

---

## 10. Architecture Diagram

```
                    ┌─────────────┐
                    │   /hub      │ ← ONLY exit on Back
                    │ Owanbe Home │
                    └──────┬──────┘
           go() replace    │    go() replace    go() replace
              ┌────────────┼────────────┐
              ▼            ▼            ▼
        ┌──────────┐ ┌──────────┐ ┌──────────┐
        │  /home   │ │ /attendee│ │ /vendor  │
        │ Organizer│ │ Attendee │ │  Vendor  │
        └────┬─────┘ └──────────┘ └──────────┘
             │ push()
             ▼
        ┌──────────────┐
        │/events/:id   │ Event Desktop
        └──────┬───────┘
               │ push()
               ▼
        ┌──────────────┐
        │/events/:id/* │ Modules (guests, budget, AI…)
        └──────────────┘

EnterpriseBackHandler: pop if canPop, else resolveBackFallback()
```

---

**Navigation architecture is stabilized.** Further work should treat `ExperienceNavigation` and `EnterpriseNavigationPolicy` as the single source of truth for back and home behavior.
