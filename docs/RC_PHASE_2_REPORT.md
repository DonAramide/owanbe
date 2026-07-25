# RC Phase 2 — Universal Identity Architecture

**Status:** COMPLETE  
**Date:** July 10, 2026  
**Feature flag:** `OwanbeIdentityConfig.identityV2 = true`

## Objective

Fully implement Universal Identity on mobile and wire it to existing NestJS workspace APIs: multi-role users, workspace-based authorization, progressive activation/onboarding, universal session management, workspace-aware routing, and instant workspace switching — while preserving legacy portal behavior when `identityV2 = false`.

---

## Implementation Summary

### Universal Identity Model

| Layer | Responsibility |
|-------|----------------|
| Supabase Auth | Single credential — email/password or Google OAuth |
| `POST /auth/ensure-user` | Creates PG `users` row without portal lock |
| `GET /auth/me` | Returns `roles[]`, `workspaces[]`, `lastActiveWorkspace` |
| `POST /me/roles/activate` | Adds role + sets workspace `in_progress` (no re-auth) |
| `POST /me/active-workspace` | Persists last-opened workspace server-side |
| Flutter `userIdentityProvider` | Caches full identity; drives guards and hub UI |
| Flutter `activeWorkspaceProvider` | Local + server workspace context for session role resolution |

### Multi-Role Session

- `AuthSession.roles` populated from API on every `refreshSessionFromApi()`.
- `resolveUniversalSessionRole()` picks role from active workspace first, then API roles — legacy `signupPortal` only when `identityV2 = false`.
- Workspace providers (`isOrganizerWorkspaceProvider`, etc.) use `canEnter()` (active **or** in-progress) in v2.

### Workspace Activation & Onboarding

1. User signs in once via `/auth` (Universal Auth).
2. Owanbe Home (`/hub`) shows three workspace cards with status.
3. **Not activated** → `/activate/{workspace}` — calls `activateWorkspace` API, no sign-in prompt.
4. **In progress** → workspace onboarding route.
5. **Active** → workspace home; `activeWorkspaceProvider.switchTo()` persists locally + API.

### Workspace Switching

- `WorkspaceSwitcher` bottom sheet lists all **active** workspaces.
- Switch calls `activeWorkspaceProvider.switchTo()` then navigates via `ExperienceNavigation.workspaceHome()`.
- No sign-out, no re-authentication.

### Workspace-Aware Routing

- `_unifiedIdentityRedirect()` (v2) replaces strict portal path guard.
- `experienceWorkspaceRouteGuard()` redirects unactivated workspaces to activation, in-progress to onboarding.
- Legacy portal auth paths (`/auth/attendee`, `/portal-gate`) redirect to `/auth` or `/hub`.
- `ExperienceNavigation` centralizes v2 vs legacy route targets.

### Access Control

- `PortalAccessGuard` — v2 uses `userIdentityProvider` + `canEnterWorkspaceExperience()`; legacy uses `canonicalRole`.
- `WorkspaceExperienceShell` wraps workspace homes: sets active workspace on mount + delegates to guard.

### Runtime Portal-First Removal (v2)

When `identityV2 = true`, runtime navigation no longer depends on portal selection:

| Former portal entry | v2 behavior |
|---------------------|-------------|
| `/portal-gate` | Redirect → `/hub` |
| `/auth/attendee\|organizer\|vendor` | Redirect → `/auth` or `/hub` |
| Splash / walkthrough sign-out | `ExperienceNavigation.entryWhenSignedOut()` → `/auth` |
| Public shell sign-in / my tickets | `ExperienceNavigation` |
| Checkout pay-without-session | Universal auth |
| Onboarding completion | Workspace home via `ExperienceNavigation` |
| Deep links | `portal_deep_links.dart` maps to v2 paths when flag on |

Legacy portal screens (`portal_auth_screen.dart`, `portal_gate_screen.dart`) remain in the tree for `identityV2 = false` and Phase 5 retirement.

---

## Validation Results

| Check | Result | Notes |
|-------|--------|-------|
| Single account → Organizer + Vendor + Attendee | **Architecturally supported** | `POST /me/roles/activate` per workspace; hub UI exposes all three |
| No re-auth on activation | **PASS** | `WorkspaceActivationScreen` only calls `activateWorkspace` + identity refresh |
| Workspace switching | **PASS** | `WorkspaceSwitcher` + `activeWorkspaceProvider` |
| Activation persistence | **PASS** | SharedPreferences + `POST /me/active-workspace` |
| Legacy users (`identityV2 = false`) | **PASS** | `_strictPortalRedirect()` unchanged; portal guards intact |
| Legacy APIs | **PASS** | `complete-signup`, `validate-portal` preserved in API |
| Authentication flows | **PASS** | Universal auth uses `completeUniversalAuth`; legacy portal auth path preserved behind flag |
| Flutter compiles | **PASS** | `dart analyze lib` — 0 errors; `flutter build apk --debug` succeeded |
| NestJS compiles | **PASS** | `npx tsc --noEmit` |
| Unit tests | **PASS** | `jest portal.util.spec` — 4/4 |
| E2E device test | **Not run** | Requires API + migration `046` + device/emulator |

---

## Compile & Test Commands

```bash
# API
cd services/api && npx tsc --noEmit
cd services/api && npx jest test/portal.util.spec.ts

# Flutter
cd mobile && dart analyze lib
cd mobile && flutter build apk --debug
```

---

## Files Modified / Created (Phase 2)

### New — Identity & Routing Core

- `mobile/lib/identity/owanbe_identity_config.dart`
- `mobile/lib/identity/user_identity.dart`
- `mobile/lib/identity/workspace_models.dart`
- `mobile/lib/identity/workspace_access.dart`
- `mobile/lib/identity/workspace_providers.dart`
- `mobile/lib/identity/experience_navigation.dart`
- `mobile/lib/identity/identity_provider.dart`
- `mobile/lib/router/experience_routes.dart`
- `mobile/lib/router/experience_onboarding.dart`
- `mobile/lib/router/portal_deep_links.dart`
- `mobile/lib/router/portal_routes.dart` (legacy helper, used when v2 off)
- `mobile/lib/router/portal_onboarding.dart` (legacy)

### New — Workspace UI

- `mobile/lib/features/home/screens/owanbe_home_screen.dart`
- `mobile/lib/features/home/widgets/workspace_experience_card.dart`
- `mobile/lib/features/activation/screens/workspace_activation_screen.dart`
- `mobile/lib/features/workspace/widgets/workspace_switcher.dart`
- `mobile/lib/features/workspace/widgets/workspace_experience_shell.dart`
- `mobile/lib/features/auth/screens/universal_auth_screen.dart`
- `mobile/lib/features/auth/widgets/portal_access_guard.dart`

### New — Backend Workspace (consumed by Phase 2; built across RC)

- `services/api/src/modules/users/workspace.service.ts`
- `services/api/src/modules/users/workspace.controller.ts`
- `services/api/src/modules/users/workspace.util.ts`
- `services/api/src/modules/users/dto/workspace.dto.ts`
- `infra/db/046_unified_identity.sql`

### Modified — Session & Auth

- `mobile/lib/auth/auth_session.dart` — `roles[]`, `hasRoleCode()`
- `mobile/lib/auth/auth_notifier.dart` — `completeUniversalAuth`, `resolveUniversalSessionRole`, universal Google OAuth
- `mobile/lib/core/api/identity_api.dart` — `activateWorkspace`, `setActiveWorkspace`, `fetchMe` workspaces

### Modified — Router

- `mobile/lib/router/app_router.dart` — v2 redirect path, activation routes, hub route
- `mobile/lib/router/router_notifier.dart`

### Modified — Workspace Homes & Shells

- `mobile/lib/features/organizer/screens/organizer_home_screen.dart`
- `mobile/lib/features/vendor/vendor_home_screen.dart`
- `mobile/lib/features/public/screens/attendee_dashboard_screen.dart`
- `mobile/lib/portals/customer/shell/customer_shell.dart`

### Modified — Providers (workspace-aware guards)

- `mobile/lib/portals/customer/providers/customer_event_providers.dart`
- `mobile/lib/features/vendor/providers/vendor_providers.dart`

### Modified — Onboarding & Public Flows

- `mobile/lib/portals/attendee/screens/attendee_onboarding_screen.dart`
- `mobile/lib/features/vendor/screens/vendor_onboarding_screen.dart`
- `mobile/lib/features/identity/screens/organizer_onboarding_screen.dart`
- `mobile/lib/features/public/screens/splash_screen.dart`
- `mobile/lib/features/public/screens/walkthrough_screen.dart`
- `mobile/lib/features/public/screens/checkout_screen.dart`
- `mobile/lib/features/public/screens/landing_screen.dart`
- `mobile/lib/features/public/widgets/public_shell_mixin.dart`
- `mobile/lib/features/identity/screens/attendee_discovery_screen.dart`

### Modified — Incidental compile fix

- `mobile/lib/features/super_admin/vendor_360/vendor_360_workspace_screen.dart` — `Icons.gshield` → `Icons.shield_outlined`

---

## Architectural Decisions

1. **Feature flag over fork** — `OwanbeIdentityConfig.identityV2` gates redirect and guard behavior; one codebase serves migration and rollback.

2. **Two-layer identity** — Supabase proves authentication; PostgreSQL `users` + `user_roles` + workspace profile tables prove authorization. Flutter never infers workspace access from Supabase metadata alone.

3. **`canEnter` vs `canAccess`** — Routes and guards allow `in_progress` (onboarding); hub cards and switcher only list `active` workspaces. Prevents blocking mid-onboarding while keeping switcher honest.

4. **Active workspace drives session role** — `resolveUniversalSessionRole()` prefers `activeWorkspaceProvider` so legacy `AuthSession.role` field remains compatible with existing feature code without portal lock.

5. **`ExperienceNavigation` facade** — All v2/legacy navigation divergence goes through one module; screens stop importing `PortalRoutes` directly when updated.

6. **Activation without re-auth** — Workspace activation is an API mutation on an existing JWT, not a new sign-in. UX copy on activation screen reinforces this.

7. **Local-first workspace switch** — `switchTo()` updates UI immediately; API sync is best-effort so switching works offline.

8. **Legacy portal files retained** — Deletion deferred to Phase 5 after production validation; v2 redirects bypass them at runtime.

9. **Server + client persistence** — `lastActiveWorkspace` on `/auth/me` reconciles with SharedPreferences on identity load via `syncFromIdentity()`.

10. **Guard at UI shell, redirect at router** — Router handles coarse workspace status redirects; `PortalAccessGuard` handles fine-grained denial with actionable CTAs (activate, go home).

---

## Remaining Technical Debt (Phase 3+)

| Item | Phase | Notes |
|------|-------|-------|
| Delete `portal_auth_screen`, `portal_gate_screen`, `signup_portal` column | Phase 5 | Files exist but are bypassed when v2 on |
| `portal_onboarding.dart` still portal-centric | Phase 5 | Legacy path only |
| `onboarding_form_screen.dart` still uses `PortalRoutes` | Phase 3/5 | Customer app sub-flow |
| `signInWithEmail(expectedRole:)` still calls `finalizePortalAuth` | Phase 5 | Only used by legacy portal auth screen |
| Hub bottom nav (Messages, Alerts, Profile) | Phase 4 | Placeholder snackbars |
| `AuthSession.copyWith` omits `roles` | Low | Add when needed |
| Migration `046` application in all environments | Ops | Required for workspace APIs |
| E2E automated tests for multi-workspace flows | Phase 3 | Manual validation pending |
| Organizer onboarding post-complete identity refresh | Low | Uses `EventRouteRegistry.home`; may need explicit `userIdentityProvider.refresh()` |

---

## Phase 2 Exit Criteria

- [x] Multi-role user support
- [x] Workspace-based authorization
- [x] Workspace activation flow
- [x] Progressive onboarding routing
- [x] Universal session management
- [x] Workspace-aware routing
- [x] Workspace providers
- [x] Workspace access control
- [x] Runtime portal-first dependencies removed when `identityV2 = true`
- [x] Backward compatibility when `identityV2 = false`
- [x] Flutter compiles (0 analyzer errors)
- [x] NestJS compiles
- [ ] Full E2E device validation (manual — blocked on environment)

---

## STOP — Phase 3 Not Started

RC Phase 2 is complete. **Do not begin Phase 3 (Workspace Architecture expansion), Phase 4 (Owanbe Home features), or Phase 5 (legacy retirement) until explicitly approved.**
