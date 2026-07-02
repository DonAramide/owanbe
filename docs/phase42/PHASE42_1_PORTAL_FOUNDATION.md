# Phase 42.1 — Event OS Unification & Portal Foundation

**Status:** Complete (routing foundation)  
**Branch target:** `feature/owanbe-event-v2`  
**Scope:** Architecture consolidation only — no new customer-facing features, no DB migrations, no API changes.

---

## Objective

Establish the **Customer Portal** as the canonical Event Operating System (Event OS). Legacy Organizer Portal paths remain in the codebase but operate in **compatibility mode** via redirects.

### Portal ownership (mandatory)

| Portal | Role(s) | Canonical prefix | Purpose |
|--------|---------|------------------|---------|
| Customer (Event OS) | `client`, `organizer` | `/home`, `/events/:id/*` | Organizer + celebration planning |
| Business (Vendor) | `vendor` | `/vendor/*` | Vendor operations only |
| Admin | `admin` | `/admin` | Platform operations only |
| Super Admin | `superAdmin` | `/super-admin/*` | Platform configuration |
| Public | unauthenticated / guest | `/`, `/events`, `/vendors` | Discovery, tickets, checkout |
| Legacy Organizer | `organizer` (compat) | `/organizer/*` | **Deprecated** — redirects only |

---

## Current architecture

Before Phase 42.1, organizers could land in two parallel experiences:

- **Customer Event OS** — `/events/:eventId` command center and module routes under `/events/:eventId/*`
- **Legacy Organizer Portal** — `/organizer` home and `/organizer/events/:eventId?tab=N` workspace tabs

Post-login routing sent `organizer` role users to `/organizer`, reinforcing the split.

Shared data layers (`features/organizer/*` stores, finance APIs, models) were already consumed by Customer Portal screens, but navigation was inconsistent.

---

## Target architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Customer Portal (Event OS)                │
│  Shell: /home · /events/mine · /events/create · /guests     │
│  Event hub: /events/:eventId → Command Center               │
│  Modules: guests, invitations, program, seating, budget,    │
│           rentals, vendor-pipeline, day, wall, website,     │
│           attire (aso-ebi), ai-planner, tickets (public)    │
└─────────────────────────────────────────────────────────────┘
         ▲
         │ LegacyOrganizerRouter (redirect-only)
         │
┌────────┴────────┐     ┌──────────────┐     ┌─────────────┐
│ /organizer/*    │     │ /vendor/*    │     │ /admin      │
│ (deprecated)    │     │ Vendor only  │     │ Platform    │
└─────────────────┘     └──────────────┘     └─────────────┘
```

**New foundation types (Phase 42.1):**

| Type | Path | Responsibility |
|------|------|----------------|
| `EventRouteRegistry` | `mobile/lib/portals/customer/router/event_route_registry.dart` | Single source of truth for Event OS paths |
| `LegacyOrganizerRouter` | `mobile/lib/portals/customer/router/legacy_organizer_router.dart` | Maps `/organizer/*` → Event OS while preserving `eventId`, `tab`, `tabKey` |
| `EventNavigator` | `mobile/lib/portals/customer/navigation/event_navigator.dart` | Imperative navigation API for event modules |
| `CustomerRoutes` | `mobile/lib/portals/customer/router/customer_routes.dart` | **Deprecated** thin delegate to `EventRouteRegistry` |

Router integration: `app_router.dart` invokes `LegacyOrganizerRouter.tryRedirect()` at the top of the global `redirect` callback and registers `/organizer` routes as **redirect-only** (no screen builders).

Organizer role home path: `_homePath(organizer)` → `EventRouteRegistry.home` (`/home`).

---

## Route inventory

Columns: **Destination** (screen or redirect target), **Owner** portal, **Replacement** (if deprecated), **Deprecated**.

### `/home/*` — Customer shell

| Route | Destination | Owner | Replacement | Deprecated |
|-------|-------------|-------|-------------|------------|
| `/home` | `CustomerHomeScreen` | Customer | — | No |
| `/events/mine` | `CustomerMyEventsScreen` | Customer | — | No |
| `/events/create` | `CustomerCreateEventScreen` (wraps wizard v2) | Customer | — | No |
| `/guests` | `CustomerGuestsScreen` | Customer | — | No |
| `/profile` | `CustomerProfileScreen` | Customer | — | No |
| `/client` | Redirect → `/home` | Customer | `/home` | Yes |

### `/events/*` — Public discovery + Event OS modules

| Route | Destination | Owner | Replacement | Deprecated |
|-------|-------------|-------|-------------|------------|
| `/events` | `DiscoverScreen` | Public | — | No |
| `/events/:id` | `CustomerEventRouteScreen` → Command Center (owned) or `EventDetailScreen` (public) | Customer / Public | — | No |
| `/events/:id/budget` | `CustomerEventBudgetScreen` | Customer | — | No |
| `/events/:id/guests` | `CustomerEventGuestsScreen` | Customer | — | No |
| `/events/:id/invitations` | `CustomerEventInvitationsScreen` | Customer | — | No |
| `/events/:id/ai-planner` | `CustomerEventAiPlannerScreen` | Customer | — | No |
| `/events/:id/day` | `CustomerEventDayScreen` | Customer | — | No |
| `/events/:id/website` | `CustomerEventWebsiteScreen` | Customer | — | No |
| `/events/:id/wall` | `CustomerEventWallScreen` | Customer | — | No |
| `/events/:id/wall/display` | `CustomerEventWallDisplayScreen` | Customer / Public display | — | No |
| `/events/:id/attire` | `CustomerEventAttireScreen` | Customer | — | No |
| `/events/:id/aso-ebi` | Redirect → `/events/:id/attire` | Customer | `attire` | Yes (alias) |
| `/events/:id/rentals` | `CustomerEventRentalsScreen` | Customer | — | No |
| `/events/:id/seating` | `CustomerEventSeatingScreen` | Customer | — | No |
| `/events/:id/program` | `CustomerEventProgramScreen` | Customer | — | No |
| `/events/:id/vendor-pipeline` | `CustomerEventVendorPipelineScreen` | Customer | — | No |
| `/events/:id/vendors` | Redirect → `vendor-pipeline` | Customer | `vendor-pipeline` | Yes (alias) |
| `/events/:id/tickets` | `TicketSelectScreen` | Public (guest purchase) | — | No |

Global marketplace (not event-scoped):

| Route | Destination | Owner | Deprecated |
|-------|-------------|-------|------------|
| `/vendors` | `MarketplaceScreen` | Public / Customer | No |
| `/vendors/rentals` | `MarketplaceRentalsScreen` | Public / Customer | No |
| `/vendors/:vendorId` | `MarketplaceVendorDetailScreen` | Public / Customer | No |

### `/organizer/*` — Legacy compatibility (redirect-only)

| Route | Redirect target | Owner | Replacement | Deprecated |
|-------|-----------------|-------|-------------|------------|
| `/organizer` | `/home` | Legacy → Customer | `EventRouteRegistry.home` | **Yes** |
| `/organizer/events/new` | `/events/create` | Legacy → Customer | `EventRouteRegistry.createEvent` | **Yes** |
| `/organizer/events/:eventId` | `/events/:eventId` or module via `tab` / `tabKey` | Legacy → Customer | See tab mapping below | **Yes** |
| `/organizer/*` (unknown) | `/home` | Legacy → Customer | `EventRouteRegistry.home` | **Yes** |

**Legacy tab mapping** (`LegacyOrganizerRouter.redirectEvent`):

| Query | Event OS destination |
|-------|----------------------|
| `tab=1` | `/events/:id/guests` |
| `tab=2` | `/events/:id/tickets` |
| `tab=3` | `/events/:id/vendors` → `vendor-pipeline` |
| `tab=4` | `/vendors` |
| `tab=5` | `/events/:id/budget` |
| `tab=6` | `/events/:id/day` |
| `tabKey=overview` | `/events/:id` |
| `tabKey=tickets` | `/events/:id/tickets` |
| `tabKey=attendees` | `/events/:id/guests` |
| `tabKey=vendors` | `/events/:id/vendors` |
| `tabKey=marketplace` | `/vendors` |
| `tabKey=finance` | `/events/:id/budget` |
| `tabKey=operations` | `/events/:id/day` |
| `tabKey=analytics`, `settings` | `/events/:id` |

Legacy screen implementations under `mobile/lib/features/organizer/**` are **retained** but no longer mounted by GoRouter.

### `/vendor/*` — Business portal

| Route | Destination | Owner | Deprecated |
|-------|-------------|-------|------------|
| `/vendor` | `VendorHomeScreen` | Vendor | No |
| `/vendor/fashion-attire` | `VendorFashionAttireScreen` | Vendor | No |
| `/vendor/rentals` | `VendorRentalsScreen` | Vendor | No |
| `/vendor/crm` | `VendorCrmScreen` | Vendor | No |
| `/vendor/calendar` | `VendorCalendarScreen` | Vendor | No |
| `/vendor/onboarding` | `VendorOnboardingScreen` | Vendor | No |

### `/admin/*` — Platform portal

| Route | Destination | Owner | Deprecated |
|-------|-------------|-------|------------|
| `/admin` | `AdminHomeScreen` (internal tab shell) | Admin | No |
| `/super-admin` | `SuperAdminHomeScreen` | Super Admin | No |
| `/super-admin/platform-config` | `PlatformConfigurationScreen` | Super Admin | No |

Admin sub-views (Launch Ops, Organizer Oversight, Event Oversight, etc.) are **in-shell tabs**, not separate GoRouter paths.

### Other auth / public routes (reference)

| Route | Destination | Owner |
|-------|-------------|-------|
| `/` | `LandingScreen` | Public |
| `/auth` | `PublicAuthScreen` | Public |
| `/staff/login`, `/login` | `LoginScreen` | Staff |
| `/attendee` | `AttendeeDashboardScreen` | Client |
| `/checkout` | `CheckoutScreen` | Public |
| `/payment/success` | `PaymentSuccessScreen` | Public |

---

## Navigation audit — `/organizer/` in Customer Portal

**Requirement:** List Customer Portal navigations that still pointed at `/organizer/`. Do not fix all in this phase beyond foundation.

### Customer Portal (`mobile/lib/portals/customer/**`)

| Module | File | Issue | Status |
|--------|------|-------|--------|
| Command Center | `customer_event_command_center_screen.dart` | `onTicketsTap` used `/organizer/events/$id?tab=2` | **Fixed** — `context.eventNav.openTickets()` |
| Marketplace | `marketplace_screen.dart` | Back nav: `role == organizer ? '/organizer' : home` | **Fixed** — `EventRouteRegistry.home` |
| Login (staff) | `features/auth/login_screen.dart` | Post-login `organizer => '/organizer'` | **Fixed** — `EventRouteRegistry.home` |

**No remaining `/organizer/` URL literals** in Customer Portal navigation code.

Customer Portal files still **import** `features/organizer/*` for shared models, stores, and finance APIs — data coupling only, not route leaks.

### Legacy organizer code (intentional — compat source, redirect at router)

These still contain `/organizer` navigation and will be migrated in a later phase:

| Area | Example files |
|------|----------------|
| Organizer home / dashboard | `organizer_home_screen.dart`, `organizer_dashboard_screen.dart` |
| Event workspace v3 tabs | `event_workspace_screen.dart`, `operations_tab_v3.dart`, `organizer_shared.dart` |
| Event CRUD wizards | `event_create_wizard_screen.dart`, `event_management_screen.dart` |
| Management screens | `ticket_management_screen.dart`, `vendor_management_screen.dart` |

All such URLs are intercepted by `LegacyOrganizerRouter` before screens mount.

### Hardcoded `/events/...` in Customer Portal (not `/organizer/`, future cleanup)

Several screens use `CustomerRoutes.*` or raw `/events` instead of `EventNavigator` — acceptable for Phase 42.1; migrate in UI consolidation phase:

- `customer_home_screen.dart` — `/events`, `/events/:id`
- `customer_shell.dart`, `customer_profile_screen.dart` — `/events` (public discover)
- Event module back-navigation — `CustomerRoutes.eventDetail()` pattern across budget, guests, wall, etc.

---

## Compatibility routing

Flow in `app_router.dart`:

1. **Early redirect:** `LegacyOrganizerRouter.tryRedirect(loc, queryParams)` — runs for all locations.
2. **Auth gate:** `/organizer/*` requires session; unauthenticated → `/staff/login`.
3. **Route definition:** `/organizer` tree has only `redirect` handlers — no `builder`.

Example:

```
/organizer/events/abc123?tab=2
  → LegacyOrganizerRouter.redirectEvent('abc123', {tab: '2'})
  → /events/abc123/tickets
```

---

## EventNavigator usage

`CustomerEventCommandCenterScreen` is the reference implementation — all module entry points use `context.eventNav.*`.

```dart
context.eventNav.openGuests(eventId);
context.eventNav.openTickets(eventId);
context.eventNav.openBudget(eventId);
// etc.
```

Extension: `BuildContext.eventNav` → `EventNavigator`.

---

## Risk assessment

| Risk | Severity | Mitigation |
|------|----------|------------|
| Bookmarked `/organizer/*` URLs | Medium | Redirect layer preserves `eventId` and tab params |
| Dual tickets route (`/events/:id/tickets` = public purchase vs organizer ticket admin) | Medium | Known pre-existing ambiguity; organizer tickets redirect lands on public `TicketSelectScreen` — address in later phase |
| Deep links in emails/docs referencing `/organizer` | Low | Redirects are transparent |
| `features/organizer` code still callable if imported directly | Low | No router builders; only redirects |
| Organizer role + client role path ACL | Low | `_isCustomerPortalRole` allows both on Customer shell and event modules |
| Incomplete EventNavigator adoption | Low | `CustomerRoutes` still works via registry delegation |
| Legacy tab mapping mismatch (analytics/settings → command center) | Low | Acceptable compat behavior |

---

## Out of scope (Phase 42.1)

- UI consolidation of legacy organizer screens
- Deleting `features/organizer/**`
- Replacing all `CustomerRoutes` / hardcoded paths with `EventNavigator`
- Database migrations or API contract changes
- New customer-facing features

---

## Verification

Run from repository root:

```bash
cd mobile && flutter analyze
cd mobile && dart analyze lib/portals/customer/router lib/portals/customer/navigation
cd services/api && npm run build
```

**Expected:** No new analyzer errors; all `/organizer/*` requests redirect; Customer Portal compiles with legacy code retained.

---

## Related documents

- [OWANBE_EVENT_OS_ARCHITECTURE.md](../product_architecture/OWANBE_EVENT_OS_ARCHITECTURE.md) — product architecture (Phase 41.6)
- [OWANBE_PRODUCT_AUDIT.md](../product_audit/OWANBE_PRODUCT_AUDIT.md) — dual command center finding (Phase 41.5)
