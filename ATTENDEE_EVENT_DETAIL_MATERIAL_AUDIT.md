# Attendee Event Detail — Material Hierarchy Audit

**Date:** 2026-07-14  
**Scope:** Attendee commerce flow — event detail, ticket select, checkout, payment success  
**Issue:** `No Material widget found` when rendering `PublicEventHero` on attendee event detail

---

## Executive Summary

Routing to `/attendee/events/:eventId` was **correct**. The crash was caused by **missing `Scaffold` / Material context** in `AttendeeFlowScaffold`, not by missing screens or API failures.

The attendee dashboard uses `EosAppShell` → `Scaffold`, which provides Material for all body descendants. Commerce sub-routes used `AttendeeFlowScaffold` → bare `Column`, leaving Material widgets (`Chip`, `FilledButton`, `ListTile`, `IconButton`, bottom-sheet triggers) without a required ancestor.

**Fix:** Wrap the entire attendee commerce chrome in `Scaffold` at `AttendeeFlowScaffold` — one root correction for all commerce screens, not per-widget patches.

---

## Root Cause

| Layer | Before | Problem |
|-------|--------|---------|
| `AttendeeDashboardScreen` | `WorkspaceExperienceShell` → `EosAppShell` → **`Scaffold`** | Material context present |
| `AttendeeFlowScaffold` | `WorkspaceExperienceShell` → **`Column`** | No Material ancestor for body |
| `PublicEventHero` | `Container` → `Chip` | `Chip` requires Material ancestor |
| `AttendeeTopBar` | Own `Material` widget | Only covers top bar subtree, not scroll body |

The `Chip` in `PublicEventHero` (category badge) was the first Material widget to fail during build. Other widgets on the same screen (`FilledButton`, `ListTile` in checkout, `IconButton` in ticket cards) would have failed next.

---

## Widget Hierarchy

### Before (broken)

```
MaterialApp
└── AttendeeEventDetailScreen
    └── AttendeeFlowScaffold
        └── WorkspaceExperienceShell
            └── PortalAccessGuard
                └── Column                          ← no Scaffold
                    ├── AttendeeTopBar
                    │   └── Material (local only)
                    ├── TextButton (Back)
                    └── Expanded
                        └── SingleChildScrollView
                            └── PublicEventHero
                                └── Chip            ← CRASH: no Material ancestor
```

### After (fixed)

```
MaterialApp
└── AttendeeEventDetailScreen
    └── AttendeeFlowScaffold
        └── WorkspaceExperienceShell
            └── PortalAccessGuard
                └── Scaffold                        ← provides Material + ScaffoldMessenger
                    └── Column
                        ├── AttendeeTopBar
                        ├── TextButton (Back)
                        └── Expanded
                            └── SingleChildScrollView
                                └── PublicEventHero
                                    ├── EosEventStatusBadge (Container — OK)
                                    └── Chip          ← OK: Scaffold body Material ancestor
```

---

## Material Hierarchy Audit

Screens sharing `AttendeeFlowScaffold`:

| Screen | Material widgets used | Covered by fix |
|--------|----------------------|----------------|
| `AttendeeEventDetailScreen` | `Chip`, `FilledButton`, `RefreshIndicator`, QR bottom sheet | Yes |
| `AttendeeTicketSelectScreen` | `FilledButton`, `IconButton`, `TicketTierCard` / `EosSurfaceCard`, local `Material` footer bar | Yes |
| `AttendeeCheckoutScreen` | `FilledButton`, `ListTile`, `CircleAvatar`, `EosSurfaceCard` | Yes |
| `AttendeePaymentSuccessScreen` | `FilledButton`, `TextButton` | Yes |

### Widget notes

| Widget | Material requirement | Status after fix |
|--------|---------------------|------------------|
| `Scaffold` | Root for commerce flow | Added in `AttendeeFlowScaffold` |
| `Chip` (`PublicEventHero`) | Requires Material ancestor | Satisfied by Scaffold body |
| `FilledButton` / `TextButton` | Theme + Material ink | Satisfied |
| `EosSurfaceCard` with `onTap` | Wraps `Material` + `InkWell` internally | Satisfied when ancestor theme exists |
| `TicketTierCard` | `IconButton` | Satisfied |
| `ListTile` (checkout) | Material list semantics | Satisfied |
| `showAttendeeQrSheet` | `showModalBottomSheet` needs Scaffold ancestor | Satisfied |
| `AttendeeTopBar` | Own `Material` | Unchanged; redundant but harmless |

`WorkspaceExperienceShell` was **not** modified — it is workspace-agnostic access control. Material hosting belongs in flow-specific scaffolds (`EosAppShell` for dashboard, `AttendeeFlowScaffold` for commerce).

---

## Files Modified

| File | Change |
|------|--------|
| `mobile/lib/portals/attendee/widgets/attendee_flow_scaffold.dart` | Wrap layout in `Scaffold` with `backgroundColor: context.eosColors.surface` |
| `mobile/test/attendee_flow_scaffold_test.dart` | **New** — verifies `Chip` renders under `AttendeeFlowScaffold` without Material exceptions |

**Not modified (intentionally):**

- `PublicEventHero` — `Chip` retained; root fix makes it valid
- `WorkspaceExperienceShell` — no change; not the correct layer for Scaffold
- Routes / navigation / identity providers

---

## Validation

### Automated

| Check | Result |
|-------|--------|
| `flutter test` | **14/14 passed** |
| `attendee_flow_scaffold_test.dart` | `Chip` renders; `Scaffold` present; no Material exceptions |
| `attendee_commerce_routes_test.dart` | Routes unchanged |

### Manual (device)

After **full app restart** (not hot reload):

| Step | Expected |
|------|----------|
| Attendee → Discover → Lagos Owambe | Event detail renders completely |
| Hero section | Title, UPCOMING badge, category Chip, CTA |
| About / Event details | Description, venue, organizer |
| Tickets & pricing | Tier rows visible |
| Gallery | Horizontal gallery if data present |
| Select tickets | Navigates to `/attendee/events/:id/tickets` |
| Continue to checkout | Cart → `/attendee/checkout` → pay flow |
| No red screen | No `No Material widget found` exceptions |

---

## Design Alignment

`AttendeeFlowScaffold` now mirrors the dashboard pattern:

```dart
// AttendeeDashboardScreen
WorkspaceExperienceShell → EosAppShell → Scaffold → body

// Attendee commerce (event detail, tickets, checkout)
WorkspaceExperienceShell → AttendeeFlowScaffold → Scaffold → body
```

One `Scaffold` at the flow root ensures every Material descendant in the attendee commerce experience inherits the correct context.

---

*End of audit.*
