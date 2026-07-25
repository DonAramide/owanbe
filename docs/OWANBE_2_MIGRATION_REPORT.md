# Owanbe 2.0 Migration Report

**Date:** July 2026  
**Status:** Phase 1–4 foundation implemented (incremental rollout)

---

## Summary

Owanbe has begun migration from **portal-first, single-role identity** to **unified identity with multi-workspace activation**. This release implements the core architecture without breaking existing users.

---

## What Was Implemented

### Database (`infra/db/046_unified_identity.sql`)
- `attendee_profiles` — lightweight attendee workspace profile
- `vendor_profiles` — vendor workspace activation + drafts
- `organizer_profiles` — extended with `onboarding_draft`, `profile_completion_pct`, `activated_at`
- `users.last_active_workspace` — server-side workspace context

### API (NestJS)
| Endpoint | Purpose |
|----------|---------|
| `POST /auth/ensure-user` | Create universal user row (no portal lock) |
| `GET /auth/me` | Extended with `workspaces[]`, `lastActiveWorkspace`, `identityVersion: 2.0` |
| `GET /me/workspaces` | List workspace activation states |
| `POST /me/roles/activate` | Add role + start profile (multi-role safe) |
| `PATCH /me/roles/:workspace/onboarding` | Save onboarding draft |
| `POST /me/active-workspace` | Persist workspace switch |

**New services:** `WorkspaceService`, `workspace.util.ts`, `WorkspaceController`

**Backward compatible:** Legacy `complete-signup`, `validate-portal`, `portal-lookup` remain for old clients.

### Flutter Mobile
| Module | File |
|--------|------|
| Config | `lib/identity/owanbe_identity_config.dart` (`identityV2 = true`) |
| Models | `workspace_models.dart`, `user_identity.dart` |
| State | `identity_provider.dart` — `userIdentityProvider`, `activeWorkspaceProvider` |
| Auth | `UniversalAuthScreen` — single sign-in (Google/Apple placeholder/email) |
| Hub | `OwanbeHomeScreen` — workspace cards with 4 states |
| Activation | `WorkspaceActivationScreen` — no re-auth |
| Router | `experience_routes.dart`, `_unifiedIdentityRedirect()` |

### Entry Flow (New)
```
Splash → Walkthrough → /hub (if signed in) or /auth
/auth → Universal sign-in → /hub
/hub → Activate workspace → /activate/{role} → onboarding → workspace home
```

---

## Legacy Behavior Preserved

- Existing portal auth routes (`/auth/attendee`, etc.) redirect to `/hub` or `/auth`
- `/portal-gate` redirects to `/hub`
- Organizer `/home`, Attendee `/attendee`, Vendor `/vendor` unchanged
- Existing onboarding screens reused for activation completion
- `signup_portal` column retained for backward compatibility

---

## Migration Steps (Dev/Staging)

1. **Apply DB migration:**
   ```bash
   node scripts/apply-all-migrations.js
   ```

2. **Backfill existing users:**
   ```bash
   DATABASE_URL=postgres://postgres:postgres@localhost:5436/owanbe node scripts/backfill-owambe-2-workspaces.js
   ```

3. **Restart API:**
   ```bash
   cd services/api && npm run start:dev
   ```

4. **Hot restart Flutter app**

---

## Remaining Work (Next Sprints)

| Phase | Items |
|-------|-------|
| **5 — Living Home** | Upcoming events, messages, AI widget, revenue snapshots |
| **Profile** | Unified profile module (security, devices, audit) |
| **Shell** | Workspace switcher in organizer/vendor/attendee app bars |
| **API cleanup** | Deprecate `validate-portal`, remove `ROLE_MISMATCH` from mobile |
| **Apple Sign-In** | Wire native Apple auth |
| **Permissions** | Workspace-scoped authorization guards |
| **Tests** | E2E multi-role activation, workspace switch |

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| `/home` collision (organizer vs hub) | Hub uses `/hub`; organizer stays at `/home` |
| API 404 on new endpoints before migration | `ensureUser` best-effort; fallback to legacy session |
| Multi-role DB without migration | `addRole` uses `ON CONFLICT DO NOTHING` — no role deletion |
| Old APK with portal auth | Legacy routes redirect; no hard break |

---

## Feature Flag

Set `OwanbeIdentityConfig.identityV2 = false` in `owanbe_identity_config.dart` to revert to portal-first routing instantly.

---

## Validation Checklist

- [ ] New user: sign up → lands on Owanbe Home with 3 inactive workspaces
- [ ] Activate vendor → no email/password prompt → vendor onboarding
- [ ] Existing attendee user → Home shows Attendee Active + other workspaces available
- [ ] Switch workspace → no logout
- [ ] Google sign-in → `/hub` without portal selection
