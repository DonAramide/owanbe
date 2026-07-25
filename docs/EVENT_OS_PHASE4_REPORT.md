# Event OS — Phase 4 Report

**Sprint:** Event Execution & Live Operations Center  
**Status:** Complete — STOP (await Phase 5 approval)

---

## Mission

Transform Event OS from **Planning** into **Execution**. When the event day approaches or goes live, Event Desktop becomes **Event Mission Control** — without new business modules, dashboards, or duplicate logic.

---

## 1. Event Operations Architecture

```
EventDesktop (lifecycle-adaptive)
├── EventDesktopHero
├── PRIMARY SURFACE (mode-driven)
│   ├── Planning mode     → EventPlanningCenter (Phase 3)
│   ├── Execution mode  → EventOperationsCenter (Phase 4) + collapsed Planning
│   └── Completed mode  → EventCompletedReports
├── Module launcher (unchanged)
└── Activity / KPIs (tertiary)
```

### Data orchestration

```
eventOperationsWorkspaceProvider(eventId)
  ├── eventPlanningWorkspaceProvider   → lifecycle stage, snapshot
  ├── customerEventGuestsProvider      → live guest ops
  ├── operationsGuestsProvider         → check-in state
  ├── operationsFeedProvider           → command feed
  ├── operationsIncidentsProvider      → open incidents
  ├── operationsHealthProvider         → operational health
  ├── operationsKpisProvider           → live KPIs
  ├── operationsVendorsProvider        → vendor ops monitor
  ├── eventVendorCrmProvider           → pipeline stages
  └── eventProgramProvider             → live timeline
        └── buildEventOperationsWorkspace()
```

**Key files:**

| Layer | Path |
|-------|------|
| Models + orchestration | `operations/event_operations_models.dart` |
| Provider | `operations/event_operations_workspace_provider.dart` |
| Command navigation | `operations/operations_command_navigation.dart` |
| Operations UI | `workspace/widgets/event_operations_center.dart` |
| Completed UI | `workspace/widgets/event_completed_reports.dart` |
| Desktop mode switch | `workspace/widgets/event_desktop.dart` |
| Ops route wrappers | `screens/customer_event_ops_module_screen.dart` |

---

## 2. Lifecycle Transition Model

### Desktop modes

| Mode | When | Primary surface |
|------|------|-----------------|
| `planning` | Before event day; draft/planning stages | Planning Center |
| `execution` | Event day, `live` status, or ready ≤1 day | Operations Center |
| `completedReports` | `completed` or `cancelled` | Event Reports |

### Resolver logic (`resolveEventDesktopMode`)

```
completed/cancelled → completedReports
live OR lifecycle liveEvent → execution
event day (daysUntil ≤ 0) AND not draft → execution
readyForEvent AND daysUntil ≤ 1 → execution
else → planning
```

Planning remains accessible in execution mode via collapsed **Planning details** expansion tile.

---

## 3. Live Operations State Machine

```
Planning ──(event day / live)──► Execution ──(completed)──► Reports
                                      │
                                      ├── Operational health monitoring
                                      ├── Program item: planned → in_progress → completed/skipped
                                      ├── Guest check-in flow (ops guests provider)
                                      ├── Vendor pipeline stages (CRM + ops vendors)
                                      └── Command feed (ops feed + command snapshot feed)
```

### Program controls (reuses `programApiProvider.setStatus`)

| Action | Maps to status |
|--------|----------------|
| Start | `in_progress` |
| Pause | `ready` |
| Resume | `in_progress` |
| Complete | `completed` |
| Skip | `skipped` |

No duplicate timeline — same API as `CustomerEventProgramScreen`.

---

## 4. Command Action Mapping

| Command | Opens (existing module) |
|---------|-------------------------|
| Open Check-In | `/events/:id/day/check-in` → `CheckInCenterScreen` |
| Broadcast Announcement | Event Wall (`openWall`) |
| Contact Vendor | Vendor pipeline |
| Contact Staff | Program / run sheet |
| Emergency Mode | Incidents center |
| Log Incident | Incidents center |

### New event-scoped ops routes (glue only)

| Route | Reused screen |
|-------|---------------|
| `/events/:id/day/check-in` | `CheckInCenterScreen` |
| `/events/:id/day/scan` | `QrScanScreen` |
| `/events/:id/day/incidents` | `IncidentCenterScreen` |
| `/events/:id/day/feed` | `LiveEventFeedScreen` |

Wrapped in `CustomerEventOpsModuleScreen` → `EventModuleScaffold` for Event OS back navigation.

---

## 5. Real-Time Event Flow

```
Guest check-in (performManualCheckIn / QR scan)
  → operationsApi / OperationsStore
  → bumpOperationsRevision
  → operationsFeedProvider + operationsGuestsProvider invalidate
  → eventOperationsWorkspaceProvider rebuilds
  → EventOperationsCenter command feed + guest ops update

Program status change
  → programApi.setStatus
  → refreshProgram + invalidate ops workspace
  → Live timeline section updates

Incident logged
  → performLogIncident / operationsApi
  → operationsIncidentsProvider + operationsHealthProvider
  → Operational health score updates
```

Reuses existing `operationsRevisionProvider` — no new polling layer.

---

## 6. Regression Report

| Area | Status |
|------|--------|
| Planning Center (Phase 3) | Preserved — primary in planning mode; collapsed in execution |
| Module launcher (Phase 1) | Unchanged |
| Event context wiring (Phase 2) | Unchanged |
| Attendee workspace | Unaffected — no attendee route changes |
| Vendor workspace | Unaffected |
| Authentication / router guard | Unaffected — ops routes under existing `/events/:id/day/*` |
| Ticket purchase vs manage | Unaffected |

---

## 7. Validation Evidence

```
flutter test test/event_operations_orchestrator_test.dart  → 6/6 passed
flutter test test/event_planning_orchestrator_test.dart    → 8/8 passed
flutter test test/event_desktop_registry_test.dart         → 6/6 passed
Total Event OS tests                                       → 20/20 passed
```

| Requirement | Evidence |
|-------------|----------|
| Lifecycle changes desktop automatically | `resolveEventDesktopMode` tests; `eventDesktopModeProvider` drives `_primarySurface` |
| Timeline updates correctly | `programApi.setStatus` in `EventOperationsCenter`; reuses `ProgramDayWidget` |
| Guest check-in updates live | `operationsGuestsProvider` + `buildLiveGuestOpsSummary` |
| Vendor status updates live | `eventVendorCrmProvider` + `buildLiveVendorOpsSummary` |
| Operations feed updates | `mergeCommandFeed(opsFeed, snapshot.feed)` |
| Command actions work | `executeOperationsCommand` → `EventNavigator` ops routes |
| Back navigation in Event OS | `CustomerEventOpsModuleScreen` → `EventModuleScaffold` → `backToOverview` |
| Planning unaffected | Planning mode unchanged; execution shows collapsed planning |

### Manual smoke test

- [ ] Event with `live` status → Operations Center primary
- [ ] Event on today's date → Operations Center primary
- [ ] Future event → Planning Center primary
- [ ] Completed event → Reports primary
- [ ] Tap "Open Check-In" → check-in screen, back → Event Desktop
- [ ] Program Start/Complete → timeline reflects change on refresh
- [ ] Command feed shows check-in / incident entries

---

## Operational Health (replaces planning readiness in execution)

Seven dimensions averaged into operational health score:

- Guest flow
- Vendor readiness
- Timeline progress
- Incidents (inverse)
- Venue status
- Network status (connected)
- Staff status

When `operationsHealthProvider` returns data, score blends check-in rate, incident rate, and attendance rate.

---

## STOP

Phase 4 complete. Event Desktop now behaves as **Event Mission Control** during execution. No post-event analytics redesign, attendee engagement changes, vendor experience redesign, or AI automation work started.

Await approval before Phase 5.
