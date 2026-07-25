# Technical Debt Register — Owanbe 2.0 RC

**Last updated:** July 11, 2026 (RC Phase 5)  
**Owner:** Platform Engineering

---

## Priority Legend

| Priority | Meaning |
|----------|---------|
| P0 | Blocks production or security |
| P1 | Should fix in v2.1 (first post-RC sprint) |
| P2 | Improve when capacity allows |
| P3 | Nice-to-have / future |

---

## Active Debt

| ID | Priority | Item | Introduced | Notes |
|----|----------|------|------------|-------|
| TD-001 | P1 | Real messages/notifications API | Phase 4 | Living Home uses derived previews |
| TD-002 | P1 | Living Home widget/provider tests | Phase 4 | Only lifecycle tests exist |
| TD-003 | P1 | Physical device E2E certification | Phase 2–5 | Requires `adb reverse` per session |
| TD-004 | P2 | Rename `PortalAccessGuard` → `WorkspaceAccessGuard` | Phase 5 | Functional; naming legacy |
| TD-005 | P2 | Collapse `PortalRoutes` into `ExperienceRoutes` | Phase 5 | Path helpers still needed for compat |
| TD-006 | P2 | Remove `AuthSignupService.completeSignup` internal code | Phase 5 | HTTP retired; dead code remains |
| TD-007 | P2 | Stop Supabase JWT `signup_portal` sync | Phase 5 | Audit field; no consumers in v2 |
| TD-008 | P2 | Drop `signup_portal_deprecated` column | Phase 5 | After 90-day zero 410 traffic |
| TD-009 | P2 | Remove `signupPortal` from `/auth/me` (API v3) | Phase 5 | Breaking change — version bump |
| TD-010 | P2 | Saved events backend model | Phase 4 | Recommendations use public listings |
| TD-011 | P2 | AI recommendations endpoint | Phase 4 | Static card links to event OS |
| TD-012 | P3 | `enterprise_auth_shell.dart` unused topology painter | Pre-RC | Dead element warning |
| TD-013 | P3 | Project-wide `flutter analyze` info/warnings (~429) | Pre-RC | Not introduced by RC phases |
| TD-014 | P3 | Lazy tab initialization in Living Home | Phase 4 | IndexedStack retains 4 tabs |
| TD-015 | P3 | Email/KYC verification granular status | Phase 4 | Uses `onboardingComplete` proxy |

---

## Resolved Debt (RC Phases 1–5)

| ID | Item | Resolved In |
|----|------|-------------|
| RD-001 | Portal-first sign-up blocking multi-role | Phase 2 |
| RD-002 | CircularDependencyError in auth refresh | Phase 2 |
| RD-003 | Workspace restore on login bypassing Home | Phase 4 (intentional hub-first) |
| RD-004 | Portal auth screens reachable at runtime | Phase 5 |
| RD-005 | `assignSingleRole` on happy path | Phase 5 |
| RD-006 | `signup_portal` active writes | Phase 5 |
| RD-007 | 8 dead portal-first UI files | Phase 5 |
| RD-008 | `_strictPortalRedirect` unreachable code | Phase 5 |

---

## Debt Acceptance Rationale

Items TD-001 through TD-003 are **accepted for RC launch** because:

1. They do not affect core auth/identity/workspace integrity
2. Workarounds exist (derived UI, manual device testing)
3. Fixing them requires new backend services outside RC scope

---

## Review Schedule

| Milestone | Action |
|-----------|--------|
| Production launch + 30 days | Review P1 items; monitor 410 endpoint traffic |
| v2.1 planning | Prioritize TD-001, TD-002, TD-003 |
| v2.2 planning | Database column drop assessment (TD-008) |
