# RC Phase 3 — Universal Workspace Platform

**Status:** COMPLETE  
**Date:** July 11, 2026  
**Authorization:** Approved after Runtime Validation Sprint  
**Feature flag:** `OwanbeIdentityConfig.identityV2 = true`

---

## Objective

Transform Owanbe from separate portal experiences into a **unified Workspace Platform** — one account, multiple workspaces, instant switching, shared identity and navigation. Modeled after Google Workspace / Notion / Shopify patterns: no logout between workspaces, no repeated authentication, no duplicated session.

---

## Architectural Decisions

### 1. Extend Phase 2 — Do Not Rebuild

Phase 2 already delivered hub-first auth, workspace APIs, switcher, and guards. Phase 3 **consolidates** these into a cohesive platform layer rather than introducing parallel widgets or providers.

| Primitive | Role in Phase 3 |
|-----------|-----------------|
| `OwanbeHomeScreen` | **Workspace Launcher** — universal entry after sign-in when no restorable workspace |
| `WorkspaceExperienceShell` | **Workspace Shell** — access guard + active context sync on enter |
| `WorkspaceSwitcher` | **Workspace Switcher** — instant move between activated workspaces |
| `WorkspaceContextActions` | **Platform chrome** — Home + Switcher + active workspace chip |
| `activeWorkspaceProvider` | **Workspace Context** — local + server persistence |
| `WorkspaceLifecycle` | **Lifecycle** — post-login restore, launcher routing |
| `ExperienceNavigation` | **Navigation facade** — single import surface for v2 routing |

### 2. Workspace Restoration on Re-Login

After sign-in, the app resolves destination via `WorkspaceLifecycle.postLoginDestination()`:

1. If `lastActiveWorkspace` from API is **active** → navigate directly to that workspace home
2. Otherwise → **Universal Home** (`/hub`)

Server `POST /me/active-workspace` persists context; local SharedPreferences mirrors for offline UX. Sign-out clears **local** context only — server `lastActiveWorkspace` is preserved for restoration.

### 3. Customer Event OS Unified Under Organizer Shell

`CustomerShell` (organizer workspace at `/home`) is now wrapped in `WorkspaceExperienceShell` at the route builder level — same pattern as attendee/vendor homes. `PortalAccessGuard` is not duplicated; the shell provides it.

### 4. Router Refresh on Identity + Workspace

`RouterNotifier` now listens to `userIdentityProvider` and `activeWorkspaceProvider` in addition to auth — activation/onboarding redirects fire when identity loads without requiring manual navigation.

### 5. Shared Platform Chrome

All workspace top bars use `WorkspaceContextActions`:

- **Home** → return to launcher without sign-out
- **Switcher** → instant workspace change
- **Context chip** → shows current workspace name

---

## Implementation Summary

### Workspace Platform Module

| Component | Path |
|-----------|------|
| Platform barrel export | `mobile/lib/features/workspace/workspace_platform.dart` |
| Lifecycle (restore, launcher) | `mobile/lib/identity/workspace_lifecycle.dart` |
| Shell + context chrome | `mobile/lib/features/workspace/widgets/workspace_experience_shell.dart` |
| Switcher (enhanced active indicator) | `mobile/lib/features/workspace/widgets/workspace_switcher.dart` |
| Launcher | `mobile/lib/features/home/screens/owanbe_home_screen.dart` |

### User Journey (Implemented)

```
Login
  ↓ (restore if lastActiveWorkspace active)
Universal Home OR Workspace Home
  ↓
Organizer / Vendor / Attendee Workspace  (no re-auth)
  ↓ (Home button)
Universal Home
  ↓ (switcher)
Another Workspace
  ↓
Logout → Login → Restore last workspace
```

---

## Files Modified

### New Files

| File | Purpose |
|------|---------|
| `mobile/lib/identity/workspace_lifecycle.dart` | Post-login restore, launcher routing |
| `mobile/lib/features/workspace/workspace_platform.dart` | Platform module exports |
| `mobile/test/workspace_platform_test.dart` | Unit tests (4 cases) |
| `scripts/validate-rc-phase3-workspace.js` | API validation script |
| `docs/RC_PHASE_3_REPORT.md` | This report |

### Modified Files

| File | Change |
|------|--------|
| `mobile/lib/identity/experience_navigation.dart` | `postLogin`, `returnHome`, `launcherTarget`, `hub()` |
| `mobile/lib/identity/identity_provider.dart` | `ActiveWorkspaceNotifier.clear()` on sign-out |
| `mobile/lib/router/router_notifier.dart` | Listen identity + active workspace |
| `mobile/lib/router/app_router.dart` | Post-login restore redirect |
| `mobile/lib/auth/auth_notifier.dart` | Clear workspace context on sign-out |
| `mobile/lib/features/workspace/widgets/workspace_experience_shell.dart` | Platform chrome, context chip |
| `mobile/lib/features/workspace/widgets/workspace_switcher.dart` | Highlight current workspace |
| `mobile/lib/features/home/screens/owanbe_home_screen.dart` | Switcher on launcher, lifecycle navigation |
| `mobile/lib/features/auth/screens/universal_auth_screen.dart` | Post-login restore navigation |
| `mobile/lib/portals/customer/router/customer_shell_route.dart` | Wrap `CustomerShell` in shell |
| `mobile/lib/portals/customer/shell/customer_shell.dart` | Use `WorkspaceContextActions` |
| `mobile/lib/features/public/screens/attendee_dashboard_screen.dart` | Platform chrome |
| `mobile/lib/features/organizer/screens/organizer_home_screen.dart` | Platform chrome |
| `mobile/lib/features/vendor/vendor_home_screen.dart` | Platform chrome |
| `mobile/lib/applications/owanbe_customer/screens/onboarding_form_screen.dart` | `ExperienceNavigation` instead of `PortalRoutes` |

---

## Validation Results

### Flutter

| Check | Result |
|-------|--------|
| `dart analyze` (Phase 3 files) | **0 errors** |
| `flutter test test/workspace_platform_test.dart` | **4/4 PASS** |

### NestJS

| Check | Result |
|-------|--------|
| `tsc --noEmit` | **PASS** |

### Workspace API (`validate-rc-phase3-workspace.js`)

| Step | Result |
|------|--------|
| API health | ✓ |
| Supabase sign-in | ✓ |
| ensure-user | ✓ |
| auth/me | ✓ |
| Activate organizer | ✓ |
| Switch to vendor | ✓ |
| Persist lastActiveWorkspace | ✓ |
| Restore client workspace | ✓ |
| Workspaces payload | ✓ |

**9/9 passed**

### Regression (Phase 1 & 2)

| Area | Status |
|------|--------|
| Universal auth (`/auth`) | Unchanged path — enhanced post-login destination |
| Hub-first routing | Preserved |
| Workspace activation APIs | Validated |
| Riverpod circular dependency fix (Phase 2) | Preserved — no `activeWorkspaceProvider` read in `refreshSessionFromApi` |
| Portal legacy screens | Retained for `identityV2 = false` — not modified |

### Authentication Stability

No authentication regressions introduced. Sign-in flow unchanged at Supabase layer; post-login navigation enhanced only after successful `userIdentityProvider` load.

---

## Physical Device Notes

Unchanged from Runtime Validation Sprint:

```powershell
adb reverse tcp:8080 tcp:8080   # required for 127.0.0.1 API on USB device
flutter run
```

After sign-in, user with `lastActiveWorkspace=client` (e.g. `attendee@owanbe.dev`) may land directly in Attendee workspace — use **Home** button to reach launcher.

---

## Remaining Risks

| Risk | Severity | Notes |
|------|----------|-------|
| Supabase sign-up rate limit | Low | Environmental — use seeded accounts |
| adb reverse forgotten | Low | Documented |
| `OrganizerHomeScreen` unused in router | Low | Organizer workspace uses `CustomerShell` at `/home` — legacy screen retained |
| Hub bottom nav placeholders | Info | Phase 4 scope (Messages, Alerts, Profile) |
| Cold-start splash ignores existing session | Low | Splash always routes unsigned-out path |

---

## Technical Debt

| Item | Phase |
|------|-------|
| Retire `WorkspaceSelectorScreen` / `IdentityWorkspaceManager` | Phase 5 |
| Delete `portal_auth_screen.dart`, `portal_gate_screen.dart` | Phase 5 |
| Hub living widgets (events, messages, AI) | Phase 4 |
| Full device E2E automation | Phase 3+ |
| Workspace-scoped feature-level permission guards | Phase 4+ |

---

## Recommendations for RC Phase 4

1. **Living Home** — Replace hub placeholder bottom nav with Messages, Alerts, Profile
2. **Cross-workspace widgets** — Upcoming events, revenue snapshots on launcher
3. **Splash session awareness** — Route signed-in users to `postLoginDestination` on cold start
4. **Deep link workspace context** — Open specific workspace from notification links
5. **E2E device test** — Automate full journey from Runtime Validation checklist

---

## STOP — Phase 4 Not Started

RC Phase 3 is complete. **Do not begin Phase 4 (Owanbe Home features) or Phase 5 (legacy retirement) until explicitly approved.**

---

## Status

# 🟢 RC PHASE 3 COMPLETE

Universal Workspace Platform is implemented and validated at API + unit test level. Ready for your device smoke test and Phase 4 approval.
