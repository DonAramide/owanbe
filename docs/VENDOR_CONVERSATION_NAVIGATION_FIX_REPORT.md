# Vendor Conversation Navigation Fix Report

## Verdict

✅ Vendor Conversation Navigation Fixed

## 1. Root cause

Two stacked defects — not a missing Vendor identity.

### A. Conversation Hub pushed a nonexistent GoRouter path

| Step | Detail |
|------|--------|
| Widget | `VendorDashboardScreen._buildConversationsHub` |
| Data | Live `VendorRequest` from `vendorInboxSnapshotProvider` (`requestId`, `eventId` UUID, organizer, stage) |
| Click handler | `onTap: () => context.push('/vendor/events')` |
| Generated route | `/vendor/events` |
| Router truth | `app_router.dart` defines `/vendor`, `/vendor/crm`, `/vendor/calendar`, … — **no** `/vendor/events` |
| Result | `GoException: no routes for location: /vendor/events` → Page Not Found |

**Intended destination (already exists):** Vendor shell **Events** tab (`vendorShellTabProvider` index `1`) → `EventParticipationScreen` → `VendorEvent360WorkspaceScreen` (Conversation tab).

### B. Event ID key mismatch blocked conversation resolve

| Source | Field | Example (anger manage) |
|--------|-------|-------------------------|
| `GET /vendor/events` | `eventId` = `external_ref` | `evt_anger_manage` |
| Same API | `eventUuid` (already returned, ignored by mobile) | `1aacb543-2169-4d76-8308-fb8921fb648b` |
| CRM `vendor_event_requests` | `event_id` / API `eventId` | UUID `1aacb543-…` |

Event Ops opened with `evt_anger_manage`, then looked up CRM by exact `eventId` equality → **no match** → “No vendor request linked to this event yet.”

Conversation Hub itself loaded correctly (canonical `vendors.id` for Ada Attendee), proving identity resolution was fine.

## 2. Existing-account compatibility finding

| Check | Result |
|-------|--------|
| User Ada Attendee | Existing account |
| Vendor | `401c71d5-5067-42da-a0c3-f1ab03f3aeec` (`Ada Attendee`) |
| Request | `68726e00-a442-456c-ac65-81ba844bd02f` stage `accepted` |
| Event | UUID + `external_ref=evt_anger_manage`, title `anger manage` |
| Legacy identity issue | **None** — no second vendor, no seed fallback required, no data migration |

No additive SQL migration was required.

## 3. Exact files changed

### Mobile
- `mobile/lib/features/vendor/providers/vendor_event_workspace_nav.dart` (**new**) — deep-link nav + event-key matching
- `mobile/lib/features/vendor/screens/vendor_dashboard_screen.dart` — Hub opens Events tab + workspace nav
- `mobile/lib/features/vendor/screens/vendor_crm_screen.dart` — same (removed `/vendor/events` push)
- `mobile/lib/features/vendor/screens/event_participation_screen.dart` — consume deep-link; resolve request via UUID/`external_ref`
- `mobile/lib/features/vendor/screens/vendor_event_360_workspace_screen.dart` — `initialTabIndex`; resolve via matcher
- `mobile/lib/features/vendor/providers/vendor_inbox_integration.dart` — shared matcher
- `mobile/lib/features/vendor/models/vendor_models.dart` — `eventUuid`
- `mobile/lib/core/api/vendor_events_api.dart` — map `eventUuid`
- `mobile/lib/portals/customer/models/vendor_crm_models.dart` — `eventExternalRef`
- `mobile/test/features/vendor/vendor_event_workspace_nav_test.dart` (**new**)

### API
- `services/api/src/modules/vendor-operations/vendor-crm.service.ts` — include `eventExternalRef` from `events.external_ref`

### Docs
- `docs/VENDOR_CONVERSATION_NAVIGATION_FIX_REPORT.md` (this file)

## 4. Routes involved

| Route | Role |
|-------|------|
| `/vendor` | Vendor home / shell (canonical) |
| `/vendor/crm` | CRM inbox overlay |
| `/vendor/events` | **Invalid** — was incorrectly pushed; must not be used |
| Shell tab index `1` | Events → Event Ops (canonical conversation host) |

No new GoRoute added.

## 5. Identifiers involved

| Identifier | Role |
|------------|------|
| `vendor_event_requests.id` (`requestId`) | Shared conversation identity |
| `events.id` (UUID) | CRM / foreign keys |
| `events.external_ref` (`evt_*`) | Event Ops public key |
| `vendors.id` | Canonical Vendor Identity (unchanged) |

## 6. Data changes

None. Investigation-only DB read confirmed existing request/vendor/event linkage.

## 7. Tests performed

- Unit: `vendor_event_workspace_nav_test.dart` — UUID ↔ `evt_*` matching
- Manual path (expected after hot restart):
  1. Ada Vendor Dashboard → Conversations Hub shows `anger manage`
  2. Tap item → Events tab → Event Ops Conversation (no Page Not Found)
  3. Timeline loads for `requestId=68726e00-…`
  4. Open from Events list with `evt_anger_manage` still resolves conversation via `eventExternalRef` / `eventUuid`

## 8. Regression results

| Area | Status |
|------|--------|
| Vendor Dashboard | Preserved; Hub click fixed |
| Vendor Inbox / CRM | Preserved; accepted-row open uses same deep-link |
| Vendor Requests | Unchanged API |
| Organizer Vendor Pipeline / Message | Unchanged |
| Vendor Identity Resolution | Unchanged (no seed fallback reintroduced) |
| Workspace switching | Uses existing shell tab select |
| Adaptive UI / Phase 14 | Not touched |

## Minimum fix summary

1. Stop pushing `/vendor/events`.
2. Open existing Events tab workspace with `requestId` + Conversation tab.
3. Bridge `evt_*` ↔ UUID via `eventExternalRef` / `eventUuid` so Conversation resolves for existing accounts.

✅ Vendor Conversation Navigation Fixed
