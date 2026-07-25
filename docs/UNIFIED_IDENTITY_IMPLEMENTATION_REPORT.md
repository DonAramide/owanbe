# Unified Identity — Phase 1 Implementation Report

**Sprint:** Production Identity Implementation (Phase 1 only)  
**Status:** Complete — STOP (no Phase 2 work started)  
**North star:** [`UNIFIED_IDENTITY_PRODUCT_ARCHITECTURE.md`](UNIFIED_IDENTITY_PRODUCT_ARCHITECTURE.md)

---

## Summary

Phase 1 wires the **already-built Identity v2 path** for production: one auth user, Hub-first entry, lazy workspace activation, and business profile rows owned by that user. Dev seed accounts (`attendee@`, `organizer@`, `vendor@`) remain for regression but are **no longer required** for production vendor identity resolution.

No authentication, OS UI, routing, or database schema redesign was performed.

---

## 1. Files modified

| File | Why changed |
|------|-------------|
| `services/api/src/modules/users/workspace.service.ts` | On workspace activation, create/link `organizers` and `vendors` business rows to the authenticated user (not dev seeds) |
| `services/api/src/modules/users/auth-signup.service.ts` | On onboarding complete, ensure organizer/vendor business rows exist and link `organizer_id` / `vendor_id` on profiles |
| `mobile/lib/features/vendor/providers/vendor_providers.dart` | Production vendor ID from `resolveVendorId` only; dev UUID fallback gated behind `allowMockPersistenceFallback()` |
| `mobile/lib/features/vendor/vendor_identity.dart` | Document dev vendor UUID as regression-only alias target |
| `mobile/lib/identity/owanbe_identity_config.dart` | Explicit flag: production does not depend on dev seed accounts |
| `mobile/test/identity/unified_identity_phase1_test.dart` | Phase 1 validation tests (new) |

---

## 2. Existing components reused (not rewritten)

| Component | Role in Phase 1 |
|-----------|-----------------|
| `WorkspaceService.ensureUser()` | Creates one `users` row per auth subject |
| `WorkspaceService.activateWorkspace()` | Lazy workspace activation (extended, not replaced) |
| `WorkspaceActivationScreen` | First entry → activate without re-auth |
| `WorkspaceLifecycle.postLoginDestination()` | Always `/hub` after login |
| `ExperienceNavigation.returnToHub()` | Workspace switch without logout |
| `OwanbeUserIdentity` + `workspaces[]` | One envelope, many workspace states |
| `userIdentityProvider` + `IdentitySyncCoordinator` | `ensure-user` + `GET /auth/me` |
| `living_home_feed.dart` | Hub launcher → activate / onboard / enter |
| `experienceWorkspaceRouteGuard` | Redirects unactivated workspaces to activation |
| `isVendorWorkspaceProvider` / `canEnterWorkspaceProvider` | Workspace-scoped access (Identity v2) |
| `AuthSignupController` | Portal auth already retired (`PORTAL_AUTH_RETIRED`) |
| `UniversalAuthScreen` | Universal sign-up/sign-in → Hub |

---

## 3. Identity changes

### 3.1 Business profile ownership (API)

**Before:** Organizer/vendor activation created only `organizer_profiles` / `vendor_profiles` stubs. New users lacked `organizers` / `vendors` rows until separate legacy flows — blocking `resolveOrganizerId` / `resolveVendorId` for non-seed accounts.

**After:**

- **Organizer activation** → `ensureOrganizerBusinessRow()` → `organizers` row with `owner_user_id = auth user`
- **Vendor activation** → `ensureVendorBusinessRow()` → `vendors` row with `owner_user_id = auth user`
- Profiles link via `organizer_id` / `vendor_id` on first activation and on onboarding complete

One human can accumulate organizer + vendor business records under the same `user_id`.

### 3.2 Production vendor ID resolution (mobile)

**Before:** `canonicalVendorIdProvider` always fell back to dev seed UUID `55555555-...`.

**After:**

- Resolves live vendor ID via `GET /me/vendor-id` (user-owned `vendors` row)
- Dev UUID used **only** when `ALLOW_MOCK_PERSISTENCE_FALLBACK=true`
- Otherwise throws — production path does not impersonate `vendor@owanbe.dev`

### 3.3 Configuration clarity

`OwanbeIdentityConfig.productionUsesDevSeedAccounts = false` documents the production contract in code.

---

## 4. Workspace activation validation

Automated (6/6 passing — `mobile/test/identity/unified_identity_phase1_test.dart`):

| Check | Result |
|-------|--------|
| Identity v2 enabled | PASS |
| Post-login → Hub | PASS |
| One identity, three workspace states | PASS |
| Not-activated → activation route (no re-auth path) | PASS |
| `returnHome()` → Hub; sign-out ≠ Hub | PASS |
| Session role follows active workspace | PASS |

### Manual validation (brand-new account)

Use **any new email** (not dev seeds):

1. Sign up / sign in once → **Owanbe Home**
2. Tap **Attendee** → Activate → complete onboarding → enter Attendee OS
3. **← Owanbe Home** (stay signed in)
4. Tap **Organizer** → Activate → onboarding → enter Organizer OS
5. **← Owanbe Home**
6. Tap **Vendor** → Activate → onboarding → enter Vendor OS
7. **← Owanbe Home**
8. Profile tab → **Sign out** (only exit from Owanbe)

**Expected:** Same email, same auth account, same hub profile; three workspace cards with independent activation states.

---

## 5. Regression validation

| Area | Status | Notes |
|------|--------|-------|
| Dev seed accounts | **Preserved** | Not deleted, not migrated |
| `attendee@` / `organizer@` / `vendor@` CI fixtures | **Unchanged** | Still valid for isolated tests |
| Organizer OS UI | **Untouched** | No dashboard/module changes |
| Vendor OS UI | **Untouched** | No dashboard/module changes |
| Attendee OS UI | **Untouched** | No discovery/checkout changes |
| Event OS | **Untouched** | |
| Authentication / Supabase | **Untouched** | Universal auth screen unchanged |
| Routing / Android back | **Untouched** | Enterprise navigation unchanged |
| Database schema | **Untouched** | No migrations; uses existing tables |

---

## 6. Deferred items (NOT IMPLEMENTED — intentional)

Per Phase 1 scope boundaries, the following were identified but **not** changed:

| Item | Reason deferred |
|------|-----------------|
| Remove debug pre-fill / dev quick sign-in on `UniversalAuthScreen` | Auth/login UI out of scope |
| Remove dev shortcut text in `auth_error_messages.dart` | Auth UX out of scope |
| `OnboardingApi.devVendorId` in `vendor_onboarding_screen.dart` | Vendor OS onboarding out of scope |
| `identity_mfa_provider.dart` hardcoded organizer/vendor dev emails | MFA module out of scope |
| Replace all `UserRole` session guards with workspace-only guards | Phase B runtime consistency |
| Deprecate `PortalRoutes` / legacy portal deep links entirely | Phase E cleanup |
| Introduce `traveler@owanbe.dev` unified regression seed | Phase D dev seed strategy |
| Retire `signupPortal` metadata entirely | Phase B |
| Hub alert / notification identity unification | Notifications out of scope |
| Vendor CRM / marketplace identity alias cleanup beyond mock fallback | Vendor OS / marketplace out of scope |
| Organizer onboarding auto-creating `organizers` via `identity.service` only | Partially addressed in workspace activation; full organizer onboarding flow unchanged |
| End-to-end device test automation for new account | Manual QA checklist provided |
| API integration test for multi-workspace single user | Future identity test sprint |

---

## 7. STOP confirmation

Phase 1 deliverable met:

```
One login → One profile → Three activatable workspaces
```

**STOP.** No Phase 2. No bonus refactors. No unrelated fixes.

---

## Reference flow (post Phase 1)

```
Sign in (once)
    ↓
Owanbe Home (/hub)
    ↓
Activate Attendee / Organizer / Vendor (lazy, same user_id)
    ↓
API creates profile + business row per workspace
    ↓
← Owanbe Home (switch without logout)
    ↓
Logout from Hub only
```
