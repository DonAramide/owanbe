# Organizer Event Details / Event Editing — Investigation

**Date:** 2026-08-19  
**Mode:** Investigation only. No code or UI was changed.

---

## Verdict

⚠ **Event Editing partially exists.**

A canonical Event record, Create Event wizard, and `PATCH /events/:eventId` API already exist. There is **no dedicated Organizer Event Details / Edit screen** that a clickable header can open today.

Do **not** treat `/events/:eventId/edit` as a real destination. That path is only recognized as a generic `/events/:id/<segment>` workspace prefix in a unit test. It is **not** registered in `EventRouteRegistry` or `app_router.dart`.

---

## 1. Existing Event Editing status

| Layer | Status | Evidence |
|-------|--------|----------|
| Backend update API | **Exists** | `PATCH /events/:eventId` → `EventsService.patch` |
| Flutter API client | **Exists** | `EventsApi.patchEvent` |
| Repository | **Exists** | `IEventsRepository.patchEvent` |
| Platform `OrganizerService` | **No update method** | Create / publish / go-live only |
| Create wizard using PATCH | **Exists (drafts)** | `EventCreateWizardV2Screen` autosave / resume |
| Dedicated Edit Event screen | **Does not exist** | No route, no widget, no navigator method |
| Settings “Event details” | **Dead / unused** | `SettingsTabV3` tile `onTap: () {}`; that tab is **not mounted** |
| Command Center Settings tab | **Stub** | `_SettingsTabBridge` shows “Search Visibility: PUBLIC” only |
| Attendee Event Details | **Different product** | `EventDetailScreen` — public/attendee, not organizer edit |
| Super-admin Event 360 | **Different product** | Control Tower inspection, not organizer editing |

Closest “edit identity” UI is **Create Event Wizard V2**, and it is wired for **create + in-progress draft resume**, not for opening an already-created event from Command Center.

---

## 2. Create Event architecture

Canonical create path (Customer / Organizer):

```
/events/create
  CustomerCreateEventScreen
    EventCreateWizardV2Screen
      createEventFromV2Draft / patchEventFromV2Draft
        EventsApi.createEvent / EventsApi.patchEvent
          POST /events  |  PATCH /events/:eventId
            EventsService.create / EventsService.patch
              INSERT/UPDATE public.events
```

| Layer | Location |
|-------|----------|
| Screen | `mobile/lib/features/organizer/wizard_v2/event_create_wizard_v2_screen.dart` |
| Shell wrapper | `mobile/lib/portals/customer/screens/customer_create_event_screen.dart` |
| Route | `EventRouteRegistry.createEvent` = `/events/create` |
| Legacy alias | `/organizer/events/new` → same V2 wizard |
| Local draft | `wizardAutosaveProvider` (`event_wizard_autosave.dart`) |
| Persistence helpers | `organizer_persistence.dart` — `createEventFromV2Draft`, `patchEventFromV2Draft`, `v2DraftToApiBody` |
| Flutter DTO | `EventWizardV2Draft` in `organizer_models.dart` |
| API | `POST /events` (`events.controller.ts` `create`) |
| Service | `EventsService.create` |
| Table | `events` (`infra/db/016_phase5_ticket_commerce_foundation.sql`) |
| Returned model | Nest `EventView` → Flutter `OrganizerEvent` / `CustomerEvent` |

Legacy V1 wizard (`EventCreateWizardScreen`) still exists in the repo and is **not routed**. Do not revive it.

### Fields Create Event currently stores

**Columns on `events`:**

- `id` (UUID, generated)
- `tenant_id`
- `organizer_id` (resolved from actor)
- `title`
- `slug` (generated from title; unique per tenant)
- `status` = `'draft'`
- `starts_at`
- `ends_at`
- `external_ref` (generated `evt_…`)
- `metadata` (JSONB)
- `created_at` / `updated_at` (DB defaults)

**Body / metadata keys written from V2 draft (`v2DraftToApiBody` + `EventsService.buildMetadata`):**

- `title`, `tagline`, `description`
- `city`, `venue`, `venueName`, `venueAddress`, `venueType`
- `venueLatitude`, `venueLongitude`, `googlePlaceId`, `venueDeferred`
- `state`, `lga`
- `category`, `categorySlug`
- `eventAccessMode`
- `budgetMinor`, `expectedGuests`, `budgetAllocation`
- `tags`, `requiredServices`, `preferredVendorIds`
- `startsAt`, `endsAt`
- `celebrantImageUrl`
- `language`, `ageRestrictionMin`, `listingVisibility`
- `registrationEnabled`, `checkInEnabled`
- `bannerLabel`, `themeColor`, `selectedTemplateSlug`
- `ticketTiers` (only when public-ticketed and tiers present; stored in `event_ticket_tiers`, not event columns)

Optional public-page metadata keys are accepted by `buildMetadata` (`galleryMedia`, `speakers`, `sponsors`, `faqs`, organizer contact fields, `isFeatured`, cover gradients) but **are not part of the V2 create form**.

---

## 3. Event Overview architecture (screenshot)

The screenshot is the **Event Command Center** executive header, not a separate Event Details page.

| Item | Value |
|------|--------|
| Route | `/events/:eventId` (`EventRouteRegistry.event`) |
| Router screen | `CustomerEventRouteScreen` |
| Ownership gate | `customerEventOwnershipProvider` → `GET /events/:eventId/manage` |
| If owned | `EventWorkspace` |
| If not owned | `EventDetailScreen` (attendee/public) |
| Event ID source | GoRouter path parameter `:id` / `:eventId` |
| Provider | `customerEventCommandProvider(eventId)` → `customerEventProvider(eventId)` |
| API | `CustomerEventsApi.getEvent` → `GET /events/:eventId/manage` |
| Model | `CustomerEvent` (`customer_event_models.dart`), same `events.id` |
| Shell | `WorkspaceShell` |
| Header widget | **`WorkspaceEntityHeader`** |
| Breadcrumb | `WorkspaceShell._buildBreadcrumbs` — `PLATFORM > {event.title}` |
| Overview body | Overview tab → `EventDesktop` |

Matching screenshot strings are **hardcoded** in `EventWorkspace.build`:

```dart
environment: 'Production',
region: 'NG-LAGOS',
primaryContact: 'organizer@owanbe.dev',
createdDate: '2026-06-01',
lastActivity: 'Updated 5 minutes ago',
```

`WorkspaceShell` also hardcodes `plan: 'Enterprise'`. Only **name / logo letter** come from the real event (`event.title`). Region, primary contact, created-on, and last-activity on this header are **not live event fields**.

A second, different “header” exists **inside** the Overview tab: `EventDesktopHero` (title, tagline, venue, date). That is not the `PLATFORM > TEST DATE` chrome.

Legacy `/organizer/events/:eventId` still loads the same `EventWorkspace` via `EventWorkspaceScreen` → `LegacyOrganizerWorkspaceAdapter`.

---

## 4. Existing edit screen, if any

**None for organizer event identity after create.**

Surfaces that look similar but are not it:

| Surface | Route | What it actually is |
|---------|-------|---------------------|
| Create Wizard V2 | `/events/create` | Create + resume **local/server draft**. No `eventId` constructor. Opening it from Command Center would start/resume a **different** draft, not edit the open event. |
| Settings tab (mounted) | same `/events/:eventId`, Settings tab | Stub list tile: “Search Visibility: PUBLIC” |
| `SettingsTabV3` | unused | “Event details” tile with empty `onTap` |
| Event website | `/events/:eventId/website` | Public page builder (`PATCH …/website`), not event identity |
| Tickets manage | `/events/:eventId/tickets/manage` | Ticket tiers only |
| Attendee Event Details | `/events/:eventId` when not owned | Read-only public detail + buy |
| Super-admin Event 360 | Control Tower | Cross-entity inspection |
| Setup checklist “Complete event details” | stays on overview | `event_creation_readiness_panel.dart` calls `openOverview` — same page |

`EventNavigator` has `openOverview`, module opens, and create — **no `openEdit` / `openEventDetails`**.

---

## 5. Existing update API

| Item | Detail |
|------|--------|
| HTTP | `PATCH /events/:eventId` |
| Controller | `EventsController.patch` — `services/api/src/modules/events/events.controller.ts` |
| Service | `EventsService.patch` — `events.service.ts` |
| Auth | `CommerceAuthGuard`; organizer must own the event (`assertOrganizerOwnsEvent`) |
| Flutter | `EventsApi.patchEvent` → repository `patchEvent` |
| Used by UI | **Only** wizard V2 (`patchEventFromV2Draft`) |
| Customer Events API | **Does not** wrap patch |
| `PUT /events` | **Does not exist** for the event row. PUT is used for other event sub-resources (website feedback, aso-ebi, seating positions, etc.) |

`patch` updates:

- `events.title`
- `events.starts_at` / `events.ends_at` (when body includes them)
- `events.metadata` (merge via `buildMetadata`)
- `events.updated_at`
- optionally `event_ticket_tiers` when `ticketTiers` is an array (`syncDraftTiers`)

Rejected: cancelled/discarded drafts (`INVALID_STATUS`).

Related lifecycle APIs (not general field edit):

- `POST /events/:eventId/publish`
- `POST /events/:eventId/go-live`
- `POST /events/:eventId/discard` (draft → cancelled)

---

## 6. Editable fields (already supported by PATCH)

These are **API-editable today**. There is no Organizer form that exposes them after the event is opened in Command Center.

**Event columns**

- `title`
- `starts_at` (`startsAt`)
- `ends_at` (`endsAt`)

**Metadata (if present in PATCH body)**

- `tagline`, `description`
- `city`, `venue`, `venueName`, `venueAddress`, `venueType`, `venueLatitude`, `venueLongitude`, `googlePlaceId`, `venueDeferred`
- `state`, `lga`
- `category`, `categorySlug`, `tags`
- `eventAccessMode`, `listingVisibility`
- `budgetMinor`, `expectedGuests`, `budgetAllocation`
- `requiredServices`, `preferredVendorIds`, `selectedTemplateSlug`
- `celebrantImageUrl`
- `language`, `ageRestrictionMin`
- `registrationEnabled`, `checkInEnabled`
- `bannerLabel`, `themeColor`, `mediaLabels`
- `coverGradientStart`, `coverGradientEnd`, `isFeatured`
- `galleryMedia`, `speakers`, `sponsors`, `faqs`
- `organizerName`, `organizerContactEmail`, `organizerContactPhone`

**Related table (when `ticketTiers` sent)**

- Draft/public ticket tier sync (`event_ticket_tiers`) — commerce, not identity form

---

## 7. Immutable / controlled fields

**Immutable (patch does not change)**

- `id`
- `tenant_id`
- `organizer_id`
- `slug`
- `external_ref`
- `created_at`

**Controlled / sensitive (dedicated APIs or policy, not a free-form details form)**

- `status` — create=`draft`; `publish`, `go-live`, `discard` only
- `eventAccessMode` / `listingVisibility` — stored in metadata; changing them after publish affects discovery/tickets (Phase 14 freeze)
- `ticketTiers` — belongs to Tickets module; do not duplicate in a header-edit form
- `isFeatured` — platform/listing concern
- Tenant, organizer ownership, RBAC

Do not invent extra fields. Header chrome (`region`, `organizer@owanbe.dev`, `2026-06-01`, `Updated 5 minutes ago`, `Enterprise`, `Production`) is **display placeholder data**, not event columns.

---

## 8. Exact event header widget

**Widget:** `WorkspaceEntityHeader`  
**File:** `mobile/lib/eos/layout/workspace/workspace_widgets.dart`  
**Mounted by:** `WorkspaceShell` (`workspace_shell.dart` lines ~81–93)  
**Organizer caller:** `EventWorkspace` (`event_workspace.dart`)

Structure matching the screenshot:

1. Breadcrumb ribbon: `PLATFORM` + chevron + event name (`TEST DATE`)
2. Avatar + title + plan/environment chips
3. Subtitle: `EVENT · Region: NG-LAGOS · Primary: organizer@owanbe.dev`
4. Meta row: Created On / Last Activity / Environment
5. Health Index on the right

`WorkspaceEntityHeader` has **no `onTap`**. It is informational.

**Shared widget warning:** the same header is used by Super-admin 360 workspaces (Event 360, Organizer 360, Vendor 360, Tenant 360, etc.). A global click handler would affect Control Tower, not only Organizer Event Management.

`EosWorkspaceHeader` in `eos_workspace_layout.dart` is a similar layout but is **not** the organizer screenshot (no call sites besides its own file).

---

## 9. Correct target route / screen

**There is no correct existing Event Details / Edit destination.**

| Candidate | Why not |
|-----------|---------|
| `/events/:eventId` Overview | Already the current page. Header click would no-op or loop. |
| Settings tab | Stub; not an editor. |
| `/events/create` | Create/resume **another** draft. Risk of duplicate event records. |
| `/events/:eventId/edit` | Unregistered. Would 404 / fall through incorrectly. |
| `/events/:eventId/website` | Public website config, not event identity. |
| `EventDetailScreen` | Attendee/public. Wrong role and contract. |

Desired interaction:

```
Organizer Event Header
  → click
  → existing Event Details / Edit
```

cannot be completed without **first** adding an edit experience that reuses `PATCH /events/:eventId` and the same `events.id`. That is **new UI wiring**, which this sprint must not implement.

---

## 10. Canonical Event record (one ID)

```
events.id  (UUID)
  → EventView / OrganizerEvent.id / CustomerEvent.id
    → Event Overview  /events/:eventId  (EventWorkspace)
      → (missing) Event Details / Edit
```

All listed organizer surfaces take the same path id:

- Overview, Tickets, Attendees/Guests, Vendors, Finance, Operations, Analytics, Reports, Timeline, Audit, Settings
- Modules: website, wall, seating, program, invitations, budget, vendor-pipeline, day/check-in

Do not create a second Event entity or a parallel update API. `PATCH /events/:eventId` is the canonical update.

---

## 11. Minimum implementation needed to make the header clickable

**Not implementable as a navigation-only change.** Clicking the header has nowhere valid to go.

Minimum **future** work (do not do in this sprint), if product later approves an edit experience:

1. **Choose one reuse path (do not invent a second editor):**
   - **A (preferred reuse):** add an explicit **edit mode** to `EventCreateWizardV2Screen` that loads the existing event by id and calls `patchEventFromV2Draft` (already used for drafts). Register a real route such as a query/flag on create **or** a registry path — only after product approval; do not collide with create-draft autosave.
   - **B:** implement the dead `SettingsTabV3` “Event details” tile as a form that PATCHes the same fields. Still new UI; still one API.
2. **Do not** add `/events/:id/edit` as a second entity or second PATCH.
3. Only after a destination exists: add an **optional** `onTap` to `WorkspaceEntityHeader` / `WorkspaceShell`, wired **only** from `EventWorkspace`. Do not make all 360 headers clickable.
4. Affordances: `InkWell`/`MouseRegion` on the identity block only (title + subtitle), not the tab bar, not Health Index, not sidebar Quick Actions.
5. Optionally replace hardcoded header meta with real `CustomerEvent.createdAt` / `updatedAt` / organizer contact — that is identity display, not a new edit system. Out of scope until approved.

Until step 1 exists, **leave the header non-clickable**.

---

## 12. Regression check — clickable header vs existing modules

The header sits **above** the tab bar. Tabs (Tickets, Attendees, Vendors, Finance, Operations, Analytics, Reports, Timeline, Audit, Settings) and Overview (`EventDesktop` / setup checklist) are siblings, not children of the header.

If a destination existed and the header navigated **away** from `/events/:eventId`:

- User would leave whichever tab they were on (including Tickets / Finance / Ops).
- Frozen Phase 14–18 workflows would not change **unless** the destination duplicated tickets/finance/analytics.

If the header only selected the Settings/Overview tab **on the same shell**:

- No route change; low interference.
- Still does not deliver Event Details/Edit, because those tabs are not editors.

Shared-header change without an optional callback **would** affect Super-admin 360 screens. That is a regression risk outside Organizer.

Setup checklist already points “details” at Overview. A header click to create-wizard would **compete** with that checklist and with Create Event autosave.

---

## 13. Files that would be changed (future only)

Investigation created **this document only**. If a later sprint implements header → existing editor:

| File | Why |
|------|-----|
| `mobile/lib/eos/layout/workspace/workspace_widgets.dart` | Optional `onTap` on `WorkspaceEntityHeader` |
| `mobile/lib/eos/layout/workspace/workspace_shell.dart` | Pass through `onHeaderTap` |
| `mobile/lib/portals/customer/workspace/event_workspace.dart` | Wire destination; stop using fake region/contact/dates if editing identity |
| `mobile/lib/portals/customer/router/event_route_registry.dart` | Only if a real edit path is registered |
| `mobile/lib/router/app_router.dart` | Only if a real edit route is registered |
| `mobile/lib/portals/customer/navigation/event_navigator.dart` | `openEventEdit` if a destination exists |
| `mobile/lib/features/organizer/wizard_v2/event_create_wizard_v2_screen.dart` | Only if edit-mode reuse is chosen |
| `mobile/lib/features/organizer/command_center_v3/tabs/settings_tab_v3.dart` | Only if Settings “Event details” is chosen **and** actually mounted |

Do **not** change: Vendor Identity, Marketplace, CRM, auth/RBAC, ticket purchase, finance, analytics, or `PATCH /events` contract.

---

## 14. Architecture freeze note

Phase 14 (publish/discovery) is frozen. Reusing `PATCH /events/:eventId` for organizer identity fields is consistent with existing create/draft behavior. A **new** edit screen or parallel update API would require approval. This investigation does not request that work.

---

**Investigation complete. No implementation performed.**
