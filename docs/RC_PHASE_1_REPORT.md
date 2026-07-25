# RC Phase 1 — Enterprise Authentication Stabilization

**Status:** COMPLETE  
**Date:** July 10, 2026

## Objective

Stabilize authentication before architectural migration: fix compile blocker, sync `display_name`, harden `ensure-user`, improve error UX.

## Implementation Summary

### Backend

| Change | Detail |
|--------|--------|
| `parseSignupPortal()` | Validates DB/JWT strings as `SignupPortal` union — no unsafe casts |
| `resolveSignupPortalForMetadata()` | Centralizes metadata sync portal resolution |
| `EnsureUserDto` | Optional `displayName` on `POST /auth/ensure-user` |
| `WorkspaceService.ensureUser()` | Transactional insert, post-insert verification, `USER_PERSIST_FAILED` on orphan auth |
| `syncDisplayNameIfNeeded()` | Backfills PG `display_name` when Supabase metadata is ahead |
| Controllers | `auth-signup.controller` + `workspace.controller` pass `displayName` |

### Flutter

| Change | Detail |
|--------|--------|
| `IdentityApi.ensureUser(displayName:)` | Sends name to API |
| `completeUniversalAuth(displayNameHint:)` | Passes sign-up name or Supabase metadata |
| `refreshSessionFromApi()` | Prefers API `displayName` over metadata |
| `formatAuthError()` | Contextual titles: sign-up vs sign-in, API vs Supabase, email confirm, duplicate email |
| `UniversalAuthScreen` | Passes name on sign-up; contextual error mapping |

### Tests

- `services/api/test/portal.util.spec.ts` — 4 tests passing

## Files Modified

- `services/api/src/modules/users/portal.util.ts`
- `services/api/src/modules/users/workspace.service.ts`
- `services/api/src/modules/users/dto/workspace.dto.ts`
- `services/api/src/modules/users/auth-signup.controller.ts`
- `services/api/src/modules/users/workspace.controller.ts`
- `services/api/test/portal.util.spec.ts` (new)
- `mobile/lib/core/api/identity_api.dart`
- `mobile/lib/auth/auth_notifier.dart`
- `mobile/lib/features/auth/auth_error_messages.dart`
- `mobile/lib/features/auth/screens/universal_auth_screen.dart`
- `mobile/lib/identity/identity_provider.dart`

## Architectural Decisions

1. **`parseSignupPortal` over cast** — Preserves type safety and supports future column deprecation without silent corruption.
2. **`ensure-user` verification** — Re-read after INSERT; explicit `USER_PERSIST_FAILED` eliminates silent partial registration.
3. **Display name authority** — PostgreSQL `users.display_name` is canonical for app; Supabase metadata is input hint on ensure-user.
4. **Legacy endpoints preserved** — `complete-signup`, `validate-portal` unchanged for backward compatibility.

## Compile Status

| Target | Result |
|--------|--------|
| `npx tsc --noEmit` (API) | PASS |
| `dart analyze` (changed files) | PASS (info lints only) |
| `jest portal.util.spec` | PASS (4/4) |

## Validation Results

- [x] SignupPortal TS2322 resolved architecturally
- [x] NestJS compiles
- [x] `ensure-user` accepts `displayName`
- [x] Partial registration detection (`USER_PERSIST_FAILED`)
- [x] Error UX differentiated (sign-up / sign-in / API / email confirm)
- [ ] End-to-end device test (requires running API + `adb reverse` or Wi‑Fi IP)

## Known Risks

- API must be running for universal auth to complete; errors now surface clearly.
- Migration `046` must be applied for full workspace listing on `/auth/me`.
- Legacy portal flows still active (Phase 5 retirement).

## Remaining Tasks (Phase 2+)

- Workspace-based access guards (replace `canonicalRole` in v2 paths)
- Multi-role session model in Flutter
- Owanbe Home expansion (Phase 4)
- Legacy `signup_portal` retirement (Phase 5)

## Migration Progress

```
RC Phase 1 ████████████████████ 100%
RC Phase 2 ░░░░░░░░░░░░░░░░░░░░   0%
RC Phase 3 ░░░░░░░░░░░░░░░░░░░░   0%
RC Phase 4 ░░░░░░░░░░░░░░░░░░░░   0%
RC Phase 5 ░░░░░░░░░░░░░░░░░░░░   0%
```
