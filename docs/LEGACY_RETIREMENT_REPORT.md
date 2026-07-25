# Legacy Retirement Report — Portal-First Architecture

**Date:** July 11, 2026  
**Phase:** RC Phase 5B  
**Status:** RETIRED (runtime) — column preserved (audit)

---

## What Was Retired

### HTTP Endpoints (410 Gone)

| Endpoint | Previous Behavior | Retirement |
|----------|-------------------|------------|
| `POST /auth/complete-signup` | Single-role portal lock + `assignSingleRole` | `410 PORTAL_AUTH_RETIRED` |
| `POST /auth/validate-portal` | Portal mismatch enforcement | `410 PORTAL_AUTH_RETIRED` |
| `POST /auth/portal-lookup` | Pre-auth email→portal routing | `410 PORTAL_AUTH_RETIRED` |
| `POST /admin/users/migrate-portal` | Admin single-role migration | `410 PORTAL_AUTH_RETIRED` |

**Replacement:** `POST /auth/ensure-user` + `POST /me/roles/activate` + `GET /auth/me`

### Flutter UI (Deleted)

| File | Previous Role |
|------|---------------|
| `portal_gate_screen.dart` | Portal picker / email lookup |
| `portal_auth_screen.dart` | Per-portal login/signup |
| `portal_onboarding.dart` | Post-auth portal routing |
| `login_screen.dart` | Legacy login |
| `public_auth_screen.dart` | Public portal auth |
| `attendee_signup_screen.dart` | Portal attendee signup |
| `staff_signup_screen.dart` | Portal staff signup |
| `attendee_discovery_screen.dart` | Unrouted discovery |

**Replacement:** `UniversalAuthScreen` → `OwanbeHomeScreen`

### Flutter Runtime Paths (Disabled)

| Component | Retirement |
|-----------|------------|
| `_strictPortalRedirect` | Removed from `app_router.dart` |
| `finalizePortalAuth` portal lock | Replaced with `completeUniversalAuth` |
| `hasLegacyPortalRoleProvider` | Removed |
| `PortalAccessGuard` legacy branch | Removed — v2 workspace guard only |
| `/auth/attendee|organizer|vendor|admin` routes | Redirect → `/auth` |

### Database (Renamed, Not Dropped)

```sql
-- Migration 047_deprecate_signup_portal.sql
ALTER TABLE users RENAME COLUMN signup_portal TO signup_portal_deprecated;
```

| Action | Status |
|--------|--------|
| Column rename | **Applied** |
| Constraint/index rename | **Applied** |
| Stop new writes on activation | **Applied** (`workspace.service.ts`) |
| Column drop | **NOT performed** — deferred to future release |

---

## What Was Preserved (Backward Compatibility)

| Item | Reason |
|------|--------|
| `signupPortal` in `GET /auth/me` | Read from `signup_portal_deprecated` for audit/metadata |
| `PortalRoutes` path constants | Onboarding paths, deep-link compat redirects |
| `/portal-gate`, `/login` redirects | External links → `/hub` |
| `POST /auth/complete-onboarding` | Refactored to v2 `ensureUser` path — still active |
| `portal.util.ts` | Metadata resolution for deprecated column reads |
| `AuthSignupService.completeSignup` | Internal code retained (unreachable via HTTP) |

---

## Retirement Validation

| Check | Result |
|-------|--------|
| `validate-portal` returns 410 | ✓ |
| `complete-signup` returns 410 | ✓ |
| `ensure-user` works | ✓ |
| `complete-onboarding` works (v2) | ✓ |
| Phase 3 workspace regression | 9/9 ✓ |
| Migration 047 applied | ✓ |

---

## Dependency Graph at Retirement

```
[BEFORE]
Login → Portal Gate → Portal Auth → complete-signup → Single Role → Portal Home

[AFTER]
Login → Universal Auth → ensure-user → Living Home → Workspace Activation → Workspace Home
                                              ↓
                                    Workspace Switcher (no re-auth)
```

---

## Permanent Removal Recommendation

**Not yet recommended.** Prerequisites for column drop:

1. Zero traffic on 410 endpoints for 90 days (monitoring)
2. Mobile builds without `completeSignup`/`validatePortal` API calls shipped to all users
3. Supabase JWT `app_metadata.signup_portal` sync stopped
4. `signupPortal` removed from `/auth/me` API version bump

Until then, `signup_portal_deprecated` remains as audit-only storage.

---

## Evidence

- Controller: `services/api/src/modules/users/auth-signup.controller.ts`
- Migration: `infra/db/047_deprecate_signup_portal.sql`
- Validation: `scripts/validate-rc-phase5-certification.js` (10/10)
