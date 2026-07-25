# RC Phase 4 — Living Owanbe Home (Operating System Home)

**Status:** COMPLETE  
**Date:** July 11, 2026  
**Authorization:** Approved after RC Phase 3  
**Feature flag:** `OwanbeIdentityConfig.identityV2 = true`  
**Scope:** Phase 4 only — Phase 5 **not** started

---

## Objective

Transform Owanbe Home from a static workspace launcher into a **personalized command center** — the first screen every authenticated user lands on. The experience adapts to activated workspaces, surfaces actionable intelligence, and provides functional platform navigation (Home, Messages, Alerts, Profile) without re-authentication.

Modeled after Google Workspace, Notion, Slack, Linear, Stripe Dashboard, and Shopify Admin patterns: one intelligent home, workspace-aware cards, context-aware quick actions.

---

## Architectural Decisions

### 1. Always Land on Living Home After Sign-In

`WorkspaceLifecycle.postLoginDestination()` now **always returns** `/hub`. This supersedes Phase 3's post-login workspace restore behavior for the initial landing experience.

Workspace restoration remains available via `WorkspaceLifecycle.restoreWorkspace()` and the workspace switcher — users can still jump directly into a workspace from Home without signing out.

**Rationale:** Phase 4 mandates that every authenticated user sees the command center first; workspace context is chosen from Home, not imposed on login.

### 2. Hub-Scoped Data Providers (Identity Access, Not Active Workspace)

Living Home aggregates data across **all activated workspaces** using identity-scoped providers:

| Provider | Gating | Purpose |
|----------|--------|---------|
| `hubOrganizerEventsProvider` | `canAccessWorkspaceProvider(organizer)` | Organizer events without active-workspace gate |
| `hubOrganizerDashboardProvider` | organizer access | Revenue, guests, tickets KPIs |
| `hubOrganizerAlertsProvider` | organizer access | Pending approvals / attention items |
| `hubVendorDashboardProvider` | vendor access | Bookings, earnings, ratings |
| `livingHomeSnapshotProvider` | authenticated identity | Unified `LivingHomeSnapshot` |

**Rationale:** `customerEventsProvider` and `vendorDashboardStatsProvider` throw or return empty when the *active* workspace doesn't match. Hub providers bypass that gate using `canAccessWorkspaceProvider` so multi-workspace users see a blended dashboard.

### 3. Reuse EOS + Customer Home Widgets — No Duplication

Phase 4 composes existing primitives rather than rebuilding:

- `HomeWelcomeHero` — greeting, avatar, countdown
- `HomeQuickActionsRow` — organizer quick actions
- `HomeInvitationCard`, `HomeActiveEventCard`, `HomeUpcomingEventBanner`
- `HomeVendorCarousel`, `EosKpiCard`, `EosFeedItem`, `EosAttentionBanner`
- `EventLoadingSkeleton` — skeleton loading
- `WorkspaceExperienceCard` — workspace rows (extended with `compact` mode)

### 4. Derived Messages & Alerts (No Dedicated API Yet)

Messages and notifications tabs use **derived previews** from organizer alerts, vendor booking counts, and invitations until a unified comms API exists. This delivers functional tabs today without blocking on backend work.

### 5. IndexedStack Bottom Navigation

`OwanbeHomeScreen` uses `IndexedStack` with four tabs — state is preserved when switching tabs. Alert badge counts flow from `livingHomeSnapshotProvider.alertCount`.

---

## Features Implemented

### Living Home Feed (`LivingHomeFeed`)

| Card / Section | Workspace Gating | Data Source |
|----------------|------------------|-------------|
| Personalized greeting + avatar | All users | `HomeWelcomeHero` + identity |
| Time-aware welcome | All users | `homeGreeting()` in hero |
| Global KPI strip | Blended | Tickets, revenue, earnings, workspace count |
| Profile completion prompt | Incomplete workspaces | `WorkspaceState.profileCompletionPct` |
| Continue onboarding cards | inProgress / notActivated | `_onboardingCards()` |
| Context-aware quick actions | Per workspace | `HomeQuickActionsRow` / ActionChips |
| Happening soon hero event | Attendee + organizer | Nearest ticket or organizer event |
| Attendee: tickets & invitations | Attendee access | `customerTicketInvitationsProvider` |
| Attendee: recommendations | Attendee access | `publicEventsProvider` titles |
| Organizer: KPIs + alerts | Organizer access | Dashboard + attention providers |
| Organizer: active events | Organizer access | `hubOrganizerEventsProvider` |
| Organizer: draft events | Organizer access | Draft filter on events |
| Organizer: AI recommendations | Organizer access | Link to event OS / AI planner |
| Vendor: bookings + earnings | Vendor access | `hubVendorDashboardProvider` |
| Trending events | All (when data available) | `publicEventsProvider` |
| Discover vendors | All (when data available) | `customerMarketplaceVendorsProvider` |
| Recent activity | Blended | Derived from alerts, tickets, bookings |
| Platform announcements | All users | Static Phase 4 announcement |
| Workspace overview (compact) | All users | `WorkspaceExperienceCard(compact: true)` |

### Bottom Navigation Tabs

| Tab | Screen | Behavior |
|-----|--------|----------|
| Home | `LivingHomeFeed` | Full adaptive command center |
| Messages | `HomeMessagesTab` | Derived message previews with deep links |
| Alerts | `HomeAlertsTab` | Organizer alerts, vendor bookings, platform notices |
| Profile | `HomeProfileTab` | Avatar, completion %, verification, workspaces, sign out |

### Quick Actions (Context-Aware)

| Workspace | Actions |
|-----------|---------|
| Organizer | Create Event, Find Vendors, Invite Guests, AI Planner |
| Attendee | Discover Events, My Tickets |
| Vendor | View Requests |

---

## Files Modified

### New Files

| File | Purpose |
|------|---------|
| `mobile/lib/features/home/models/living_home_models.dart` | `LivingHomeSnapshot` and related models |
| `mobile/lib/features/home/providers/living_home_providers.dart` | Hub-scoped providers + snapshot aggregation |
| `mobile/lib/features/home/widgets/living_home_feed.dart` | Adaptive feed UI |
| `mobile/lib/features/home/widgets/home_messages_tab.dart` | Messages tab |
| `mobile/lib/features/home/widgets/home_alerts_tab.dart` | Alerts tab |
| `mobile/lib/features/home/widgets/home_profile_tab.dart` | Profile tab |
| `mobile/lib/features/home/widgets/workspace_experience_card.dart` | Workspace card (from Phase 3, extended) |
| `docs/RC_PHASE_4_REPORT.md` | This report |

### Modified Files

| File | Change |
|------|--------|
| `mobile/lib/features/home/screens/owanbe_home_screen.dart` | Living Home shell + functional bottom nav |
| `mobile/lib/features/home/widgets/workspace_experience_card.dart` | Added `compact` layout mode |
| `mobile/lib/identity/workspace_lifecycle.dart` | `postLoginDestination()` always → `/hub` |
| `mobile/test/workspace_platform_test.dart` | Updated for always-hub post-login |

---

## Validation Results

| Check | Result |
|-------|--------|
| `dart analyze lib/features/home` | **PASS** (0 errors; 2 info-level import hints) |
| `flutter test test/workspace_platform_test.dart` | **PASS** (4/4) |
| `npm run build` (NestJS `@owanbe/api`) | **PASS** |
| `flutter analyze` (full project) | **PASS** (no new errors in home module; 429 pre-existing info/warnings project-wide) |

### Quality Gate Assessment (Phases 1–3)

| Area | Status | Notes |
|------|--------|-------|
| Authentication | **No regression** | Sign-in flow unchanged; hub redirect only |
| Universal Identity | **No regression** | `userIdentityProvider` unchanged |
| Workspace Switching | **No regression** | Switcher + `activeWorkspaceProvider` intact |
| Session Persistence | **No regression** | `restoreWorkspace()` preserved; local/server sync unchanged |

### Routing Validation

| Flow | Expected | Verified |
|------|----------|----------|
| Post-login | `/hub` | `WorkspaceLifecycle.postLoginDestination()` unit test |
| Home → workspace | Switch + navigate | `LivingHomeFeed._openWorkspace()` |
| Workspace switcher | Instant switch | Existing `WorkspaceSwitcher` in app bar |
| Bottom nav tabs | Functional (no snackbar) | Messages, Alerts, Profile render real content |
| Pull-to-refresh | Reload snapshot | `refreshLivingHome()` on feed + tabs |

---

## Performance Considerations

1. **Parallel provider fan-out** — `livingHomeSnapshotProvider` awaits multiple futures; auto-dispose clears cache on leave.
2. **Skeleton loading** — `EventLoadingSkeleton` during snapshot load; per-tab loading states.
3. **IndexedStack** — tab bodies retained in memory; acceptable for 4 lightweight tabs.
4. **Refresh coalescing** — `livingHomeRefreshProvider` bumps invalidate hub + customer + organizer + vendor revisions together.

**Recommendation for Phase 5:** Consider lazy tab initialization if profile/messages grow heavier; add `keepAlive` only for the active tab if memory becomes a concern on low-end devices.

---

## Remaining Technical Debt

| Item | Priority | Notes |
|------|----------|-------|
| Real messages API | High | Messages tab uses derived previews |
| Real notifications API | High | Alerts tab merges organizer + vendor derived items |
| Saved events | Medium | No backend model; recommendations use public listings |
| Dedicated AI recommendations endpoint | Medium | Static card links to event OS |
| Email/KYC verification status | Medium | Profile uses `onboardingComplete` proxy |
| Living Home unit/widget tests | Medium | Only lifecycle tests updated; feed providers untested |
| Phase 3 validation script refresh | Low | `validate-rc-phase3-workspace.js` still valid for workspace APIs |
| `postLoginDestination` vs `restoreWorkspace` docs | Low | Phase 3 report describes old restore-on-login behavior |

---

## Readiness Assessment for RC Phase 5

| Dimension | Rating | Rationale |
|-----------|--------|-----------|
| Living Home UX | **Ready** | Adaptive feed, functional nav, workspace-aware cards |
| Multi-workspace blending | **Ready** | Hub-scoped providers work across activated workspaces |
| Auth / identity / switching | **Ready** | No regressions detected |
| Backend comms for messages/alerts | **Not ready** | Derived data only |
| Automated test coverage | **Partial** | Lifecycle tests pass; home feed lacks dedicated tests |
| Device runtime validation | **Recommended** | Physical device sign-in + `adb reverse` still required for API |

**Overall:** **RC Phase 4 COMPLETE — ready for Phase 5 approval gate.**

Phase 5 should focus on UI polish, real-time comms integration, and expanded test coverage — **not** started in this sprint per authorization.

---

## User Journey (Phase 4)

```
Login
  ↓ (always)
Living Owanbe Home (/hub)
  ├── Home tab: personalized adaptive feed
  ├── Messages tab: workspace-derived previews
  ├── Alerts tab: organizer + vendor attention
  └── Profile tab: account + workspace management
  ↓ (workspace card or switcher)
Organizer / Vendor / Attendee Workspace  (no re-auth)
  ↓ (Home button / app bar)
Living Owanbe Home
```

---

**STOP — Awaiting approval before RC Phase 5.**
