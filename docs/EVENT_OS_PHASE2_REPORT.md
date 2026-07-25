# Event OS — Phase 2 Report

**Sprint:** Event Context Integration & Operational Wiring  
**Status:** Complete — STOP (await Phase 3 approval)

---

## 1. Event Context Wiring Report

Every module launched from Event Desktop receives context as follows:

| Field | Source | Notes |
|-------|--------|-------|
| `eventId` | Route path (`/events/:id/...`) or query (`?eventId=` on marketplace) | Passed by `EventModuleRegistry.onOpen` and `EventNavigator` |
| `tenantId` | `OwambeApiAuth.resolveTenantId()` | Global auth — all API calls already send `X-Tenant-Id` |
| `organizerId` | `authSessionProvider.userId` | Resolved via new `eventOperatingContextProvider` |
| `workspaceId` | Same as `eventId` | Event workspace entity id |

**New provider:** `mobile/lib/portals/customer/providers/event_operating_context.dart`

**Injection points audited:**

- Event module screens: `eventId` constructor param from `app_router.dart` path parameters
- Marketplace from Event Desktop: `?eventId=` query on `/vendors`, `/vendors/:vendorId`, `/vendors/rentals`
- `RequestVendorSheet`: `lockedEventId` — skips event picker, binds `inviteVendorToEvent(eventId, ...)`
- Vendor pipeline empty state + AI planner vendor gap: `openMarketplace(eventId: ...)`
- Quick actions: `EventWorkspaceQuickActions` calls `module.onOpen(context, eventId)` — registry already event-scoped

---

## 2. Route Validation Matrix

| Launcher | Route | Expected Module | Context Received |
|----------|-------|-----------------|------------------|
| Guests card | `/events/:eventId/guests` | `CustomerEventGuestsScreen` | `eventId` (path) |
| Invitations card | `/events/:eventId/invitations` | `CustomerEventInvitationsScreen` | `eventId` (path) |
| Vendors card | `/events/:eventId/vendor-pipeline` | `CustomerEventVendorPipelineScreen` | `eventId` (path) |
| Marketplace card | `/vendors?eventId=:eventId` | `MarketplaceScreen` | `eventId` (query) |
| Vendor profile | `/vendors/:vendorId?eventId=:eventId` | `MarketplaceVendorDetailScreen` | `eventId` (query) |
| Request vendor | Sheet (no route) | `RequestVendorSheet` | `lockedEventId` |
| Budget card | `/events/:eventId/budget` | `CustomerEventBudgetScreen` | `eventId` (path) |
| Finance card | `/events/:eventId/budget` | `CustomerEventBudgetScreen` | `eventId` (path) |
| Tickets card (organizer) | `/events/:eventId/tickets/manage` | `CustomerEventTicketsManageScreen` → `TicketsTabV3` | `eventId` (path) |
| Attendee purchase | `/events/:eventId/tickets` | `TicketSelectScreen` | `eventId` (path) — **unchanged** |
| AI Planner card | `/events/:eventId/ai-planner` | `CustomerEventAiPlannerScreen` | `eventId` (path) |
| Program card | `/events/:eventId/program` | `CustomerEventProgramScreen` | `eventId` (path) |
| Seating card | `/events/:eventId/seating` | `CustomerEventSeatingScreen` | `eventId` (path) |
| Rentals card | `/events/:eventId/rentals` | `CustomerEventRentalsScreen` | `eventId` (path) |
| Attire card | `/events/:eventId/attire` | `CustomerEventAttireScreen` | `eventId` (path) |
| Live Ops card | `/events/:eventId/day` | `CustomerEventDayScreen` | `eventId` (path) |
| Website card | `/events/:eventId/website` | `CustomerEventWebsiteScreen` | `eventId` (path) |
| Event Wall card | `/events/:eventId/wall` | `CustomerEventWallScreen` | `eventId` (path) |
| Quick actions | Same as parent module `onOpen` | Registry modules with `supportsQuickAction` | `eventId` via `onOpen(context, eventId)` |

**Back navigation:** `EventModuleScaffold` → `pop()` or `backToOverview(eventId)` → Event Desktop (`/events/:eventId`). Marketplace with `eventId` → `backToOverview(eventId)` when stack empty.

---

## 3. Module Status Report

### READY (reconnected in Phase 2)

| Module | Route | Screen / Component |
|--------|-------|-------------------|
| Guests | `/events/:id/guests` | `CustomerEventGuestsScreen` |
| Invitations | `/events/:id/invitations` | `CustomerEventInvitationsScreen` |
| Vendors (pipeline) | `/events/:id/vendor-pipeline` | `CustomerEventVendorPipelineScreen` |
| Marketplace | `/vendors?eventId=` | `MarketplaceScreen` + `RequestVendorSheet` |
| Budget / Finance | `/events/:id/budget` | `CustomerEventBudgetScreen` |
| Tickets (organizer) | `/events/:id/tickets/manage` | `CustomerEventTicketsManageScreen` + `TicketsTabV3` |
| AI Planner | `/events/:id/ai-planner` | `CustomerEventAiPlannerScreen` |
| Program | `/events/:id/program` | `CustomerEventProgramScreen` |
| Seating | `/events/:id/seating` | `CustomerEventSeatingScreen` |
| Rentals | `/events/:id/rentals` | `CustomerEventRentalsScreen` |
| Attire | `/events/:id/attire` | `CustomerEventAttireScreen` |
| Live Operations | `/events/:id/day` | `CustomerEventDayScreen` |
| Website | `/events/:id/website` | `CustomerEventWebsiteScreen` |
| Event Wall | `/events/:id/wall` | `CustomerEventWallScreen` |

### PARTIAL (usable; minor gaps outside Phase 2 scope)

| Module | Gap |
|--------|-----|
| Tickets manage | Discount codes / sales dashboard UI not in `TicketsTabV3` — tier CRUD only |
| Marketplace rentals | `eventId` passed but rentals booking may not fully bind to event API |

### LEGACY (not revived)

| Item | Reason |
|------|--------|
| `OrganizerHomeScreen` tab shell | Superseded by Organizer Home Hub + Event Desktop |
| CC v3 tab shell | Components reused (`TicketsTabV3` only); shell not mounted |
| `TicketManagementScreen` | Uses global `selectedOrganizerEventIdProvider` — not used |
| `EventWorkspace` secondary tabs | Read-only KPI bridges — left as monitoring, not primary ops |

### UNUSED

| Item | Notes |
|------|-------|
| Gallery / Memories | `visible: false` in registry |
| Analytics / Settings | `visible: false`, no-op `onOpen` |
| `/events/:id/vendors` alias | Registry points to `vendor-pipeline`; alias route not added (no duplicate) |

---

## 4. Regression Report

| Area | Status | Evidence |
|------|--------|----------|
| Attendee Workspace | Unaffected | `/attendee/*` routes untouched; `AttendeeTicketSelectScreen` separate from manage |
| Vendor Workspace | Unaffected | `/vendor/*` routes untouched |
| Authentication | Unaffected | No auth flow changes; `portal_routes.dart` only tightens public path for `tickets/manage` |
| Boot Manager | Unaffected | No bootstrap changes |
| Router stability | Verified | 6 unit tests pass; no duplicate routes; nested `tickets/manage` under existing `tickets` |
| Attendee ticket purchase | Preserved | `/events/:id/tickets` still public + `TicketSelectScreen` |
| Global marketplace | Preserved | `/vendors` without `eventId` still shows event picker in `RequestVendorSheet` |

---

## 5. Validation Evidence

```
flutter test test/event_desktop_registry_test.dart
00:00 +6: All tests passed!
```

**Manual verification checklist:**

- [ ] Event Desktop → Marketplace → vendor → Request → no event picker; request uses current event
- [ ] Event Desktop → Guests → add guest scoped to event
- [ ] Event Desktop → Tickets (public event) → manage route, not purchase screen
- [ ] Module back button → Event Desktop overview
- [ ] Organizer Home → global marketplace → event picker still shown (no `eventId` query)

---

## 6. Files Changed (Phase 2)

| File | Change |
|------|--------|
| `event_operating_context.dart` | New context provider |
| `event_route_registry.dart` | `vendorsForEvent`, `eventTicketsManage`, helpers |
| `event_navigator.dart` | `openMarketplace(eventId:)`, `openTicketsManage`, vendor detail query |
| `marketplace_screen.dart` | `eventId` param, scoped back nav |
| `marketplace_vendor_detail_screen.dart` | `eventId` param, locked request sheet |
| `request_vendor_sheet.dart` | `lockedEventId` — no picker |
| `customer_event_tickets_manage_screen.dart` | New organizer manage wrapper |
| `customer_event_vendor_pipeline_screen.dart` | Scoped marketplace browse |
| `planner_missing_requirements.dart` | Scoped marketplace navigation |
| `event_module_registry.dart` | Marketplace + tickets wiring; tickets on desktop |
| `app_router.dart` | `tickets/manage` route; marketplace query params |
| `portal_routes.dart` | `tickets/manage` not public |
| `event_desktop_registry_test.dart` | Phase 2 route tests |

---

## STOP

Phase 2 wiring sprint is complete. No AI Planner improvements, vendor/guest/ticket redesigns, or new event features were started. Await approval before Phase 3.
