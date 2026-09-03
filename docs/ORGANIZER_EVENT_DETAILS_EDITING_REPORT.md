# Organizer Event Details / Edit — Implementation Report

**Date:** 2026-08-19  
**Scope:** Organizer Event Details editing only. No second Event entity or update API.

---

## 1. Existing Event architecture

Canonical record: `events.id` (UUID). Organizer routes also accept `external_ref` / slug via `EventsAccessService.resolveEventRow`.

```
events.id
  → GET /events/:eventId/manage  (EventView → CustomerEvent)
  → Event Overview  /events/:eventId  (EventWorkspace)
  → Event Edit      /events/:eventId/edit  (CustomerEventEditScreen)
  → PATCH /events/:eventId
```

Create Event remains `/events/create` (Wizard V2). Edit does **not** use draft create/resume.

---

## 2. PATCH endpoint reuse / extension

**Reused:** `PATCH /events/:eventId` → `EventsController.patch` → `EventsService.patch`.

| Question | Finding |
|----------|---------|
| Accepted fields | `title`, `startsAt`, `endsAt`, plus metadata keys in `buildMetadata` (tagline, description, city, venue, category, venue fields, state, lga, expectedGuests, celebrantImageUrl, etc.) |
| Draft-only | **No.** Only **cancelled** events are blocked. Published/live events can be updated. |
| Authorization | `CommerceAuthGuard` + `assertOrganizerOwnsEvent` (owner or org member) |
| Ticket tiers | `ticketTiers` in the body still calls `syncDraftTiers`. **The editor never sends `ticketTiers`.** |
| Audit table | `EventsService.patch` does not insert `audit_log`. It sets `events.updated_at = now()`. |

**Small same-endpoint extensions:**

- Reject empty `title` (`INVALID_TITLE`)
- Reject `endsAt` before `startsAt` (`INVALID_SCHEDULE`)
- Return `updatedAt` from `GET …/manage` / patch response (existing `events.updated_at` column)

No `/events/:id/edit` API was added.

---

## 3. Fields exposed for editing

From the actual Event model / Create Wizard (not invented):

| Section | Fields |
|---------|--------|
| Basic | Event name (`title`), tagline, description, category / `categorySlug` |
| Date & time | Start date+time, end date+time (stored as `timestamptz`) |
| Venue | Venue type, venue name, address, city, state/region, LGA |
| Media | Celebrant / cover image (`celebrantImageUrl`) |
| Other | Expected guests |

Coordinates are shown read-only when already present (`venueLatitude` / `venueLongitude`). They are not re-picked here.

**Not in the Event model — not added:** timezone, country, subcategory.

Times use the device local timezone. There is no event timezone column.

---

## 4. Mutable / controlled / immutable

**Mutable:** title, tagline, description, category, schedule, venue fields, expected guests, celebrant image.

**Controlled:** date and venue after publish/live. The editor shows a warning: changing them does **not** rewrite tickets, RSVPs, vendor bookings, or payments. No new approval workflow.

**Immutable (read-only on the screen):** event ID, status, created timestamp, access mode, organizer ownership.

**Not sent by the editor:** `ticketTiers`, status, organizer id, slug, financial fields.

---

## 5. New route

`/events/:eventId/edit`  
Registry: `EventRouteRegistry.eventEdit`  
Screen: `CustomerEventEditScreen`  
Navigator: `EventNavigator.openEventEdit`  
Router `onExit`: existing `UnsavedChangesRegistry` (binder `eventDetails`)

---

## 6. Header click implementation

`WorkspaceEntityHeader` accepts optional `onIdentityTap`.

Only the identity block (name, subtitle, edit icon) is clickable — not Health Index, not tabs, not sidebar.

Organizer `EventWorkspace` sets `onHeaderTap` → `openEventEdit(eventId)`.

Super-admin 360 shells do not pass `onHeaderTap` (unchanged).

Affordances: `InkWell` (touch splash), click cursor, edit icon, tooltip “Edit event details”.

---

## 7. Header data-source corrections

Placeholder values removed from Organizer Event Command Center.

| Header field | Source |
|--------------|--------|
| Name | `CustomerEvent.title` |
| Region | `event.state`, else `event.city`, else “Unavailable” |
| Primary | Organizer profile `supportEmail`, else event `organizerContactEmail`, else session email, else “Not configured” |
| Created On | `event.createdAt` via `formatEventDate`, else “Unavailable” |
| Last Activity | `event.updatedAt` ?? `createdAt` via `formatTimeAgo`, else “Unavailable” |
| Environment chip | Real `event.status` (draft / published / live / …) |
| Plan chip | Hidden when empty (no fake “Enterprise”) |
| Breadcrumb root | **EVENTS** → `/events/mine` (no longer PLATFORM → `/super-admin`) |

---

## 8. Files changed

| File | Change |
|------|--------|
| `services/api/src/modules/events/events.service.ts` | `updatedAt`; title/schedule validation on patch |
| `mobile/lib/portals/customer/screens/customer_event_edit_screen.dart` | **New** editor |
| `mobile/lib/portals/customer/data/event_details_patch.dart` | **New** PATCH body helper |
| `mobile/lib/portals/customer/models/customer_event_models.dart` | `updatedAt`, `state`, `lga`, `organizerContactEmail` |
| `mobile/lib/portals/customer/models/customer_event_mapper.dart` | Map those fields |
| `mobile/lib/portals/customer/api/customer_events_api.dart` | `patchEvent` → existing PATCH |
| `mobile/lib/portals/customer/router/event_route_registry.dart` | `eventEdit` |
| `mobile/lib/router/app_router.dart` | `/edit` route + unsaved `onExit` |
| `mobile/lib/portals/customer/navigation/event_navigator.dart` | `openEventEdit` |
| `mobile/lib/eos/layout/workspace/workspace_widgets.dart` | Optional identity tap |
| `mobile/lib/eos/layout/workspace/workspace_shell.dart` | `onHeaderTap`, real `plan`, breadcrumb root |
| `mobile/lib/portals/customer/workspace/event_workspace.dart` | Clickable header, live meta, SettingsTabV3 |
| `mobile/lib/portals/customer/workspace/event_module_scaffold.dart` | Optional `onBack` |
| `mobile/lib/portals/customer/workspace/event_module_registry.dart` | Settings / legacy settings → edit |
| `mobile/lib/portals/customer/workspace/widgets/event_creation_readiness_panel.dart` | Checklist CTA may open editor |
| `mobile/lib/features/organizer/command_center_v3/tabs/settings_tab_v3.dart` | Event details tile → edit |
| `mobile/lib/shared/widgets/unsaved_changes.dart` | `eventDetails` binder |
| Tests | `event_details_patch_test.dart`, `event_edit_screen_test.dart` |

Untouched: Vendor Identity, pricing, messaging, CRM, auth, RBAC, workspace switching, ticket purchase, finance, analytics engines.

---

## 9. Validation

**Client:** title required; end ≥ start; expected guests ≥ 0.

**Server:** same title/schedule checks; cancelled events cannot be patched; DB check `ends_at >= starts_at`.

---

## 10. Audit behavior

No second audit system.

Traceability today:

- `events.updated_at` on every successful patch
- Header Last Activity reads `updatedAt`
- Command Center Audit tab remains the existing stub (no new audit writer)

`audit_log` is not written by `EventsService.patch` (it was not written there before).

---

## 11. Responsive behavior

Uses `EosResponsive.formColumnsFor`:

- Phone: one column, scrollable `ListView`, sticky save bar
- Tablet/desktop: two-column rows for dates and city/state

Same screen and PATCH logic on all sizes. `EventModuleScaffold` + `EventResponsiveCanvas`.

---

## 12. Tests / regression

**Passed**

- `test/portals/customer/event_details_patch_test.dart` (PATCH body, validation, mapper, route)
- `test/portals/customer/event_edit_screen_test.dart` (header tap, no fake email, hydrate)
- `test/organizer_workspace_routes_test.dart`

**Checklist:** still a checklist. “Complete event details” / venue next-action **links** to the editor; it is not replaced by the form.

**Overview / tabs:** Header click does not wrap the tab bar. Tickets, Attendees, Vendors, Finance, Operations, Analytics, Reports, Timeline, Audit stay on the same shell.

**Manual device/browser:** not exercised in this sprint against a live Organizer session (existing `flutter run` was not used as Organizer QA here). Hot restart is required to pick up the new route.

---

## 13. Remaining technical debt

- No event timezone or country fields in `events` metadata — correctly omitted.
- Category change does not rewrite `eventAccessMode` (avoid inventing publish/access workflows).
- `PATCH` can still sync `ticketTiers` if some other client sends them; keep the editor from doing that.
- Event-level rows are not copied into `audit_log`.
- Celebrant image is the existing media field, not a separate cover-image pipeline.
- Super-admin Event 360 header is still informational (by design).

---

✅ ORGANIZER EVENT DETAILS EDITING COMPLETE
