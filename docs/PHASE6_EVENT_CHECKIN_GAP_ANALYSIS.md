# PHASE 6 — EVENT CHECK-IN & DIGITAL EVENT PASS GAP ANALYSIS

**Date:** 2026-07-24  
**Scope:** Event Check-in, Digital Event Pass, Venue Entry, Live Attendance, Organizer Integration  
**Surfaces:** Flutter `mobile/`, Nest `services/api/`, DB `infra/db/`  
**Method:** Evidence-only audit — **no code was written or modified**  
**Live QA input:** Attendee app exposes **no** visible Phase 6 gate/scan/venue/live-attendance flows

---

## Executive verdict

Phase 6 is **partially implemented**. It is **not** “already built but hidden” on the attendee surface.

| Layer | Reality |
|-------|---------|
| **Organizer / Event Ops check-in** | Largely built — manual check-in + ticket-code “scan” wired to Nest; **no camera QR scanner** |
| **Attendee digital QR pass** | Built in Phase 4–5 (My Passes / ticket QR) — **pass display, not gate operations** |
| **Attendee check-in / QR scan / venue entry / live attendance UX** | **Not implemented** as attendee product — and correctly unreachable from attendee nav |
| **Venue policy, re-entry, staff door roles, session attendance, SSE live client** | Missing or stubbed |

**Overall Phase 6 classification: Partially Implemented**

| Is Phase 6…? | Answer |
|--------------|--------|
| Already built but hidden | **No** |
| Partially implemented | **Yes** |
| Backend only | **No** (ops FE + attendee QR exist) |
| Frontend only | **No** (Nest check-in + DB exist) |
| Not implemented | **No** (core ops check-in + attendee QR are real) |

Prior docs still mark Attendee Phase 6 as **Not started** (`docs/PHASE5_ATTENDEE_DASHBOARD_COMPLETION_REPORT.md`). Existing pieces are Event OS / ticket commerce carry-forward, not a finished Phase 6 attendee sprint.

---

## Classification legend

| Label | Meaning |
|-------|---------|
| **Implemented and Working** | Present and wired for the intended persona/path |
| **Implemented but Hidden** | Built but not surfaced on the primary flow |
| **Implemented but Not Wired** | Exists in codebase; wrong provider/route/data contract or local-only |
| **Backend Complete / Frontend Missing** | API/DB ready; client UI missing |
| **Frontend Complete / Backend Missing** | UI or local store exists; no durable backend |
| **Partially Implemented** | Incomplete across layers |
| **Not Implemented** | No meaningful product implementation |

---

## Why Phase 6 is not accessible in the attendee app (Live QA)

Live QA is consistent with the architecture:

| Expected attendee Phase 6 surface | Status | Why unreachable |
|-----------------------------------|--------|-----------------|
| Check-in flow | Absent | Check-in APIs require **organizer ownership** (`EventsAccessService.assertOrganizerOwnsEvent`). Attendee shell has no check-in routes. |
| QR scanning flow | Absent | Scan UI lives under Event OS: `/events/:id/day/scan` — organizer/ops only. Attendees **display** QR; they do not scan. |
| Venue entry flow | Absent | No attendee “gate / you’re cleared” product surface. |
| Attendee check-in experience | Absent | Status chips only (`checked_in` from entitlements) — not an entry experience. |
| Live event attendance experience | Absent | No live “I’m at the event” / session attendance UI for attendees. |

**Attendee Phase 6 today = digital pass presentation + check-in status reflection.**  
**Gate operations Phase 6 today = organizer Event Operations.**

---

## Stack map (shared evidence)

| Layer | Evidence |
|-------|----------|
| **DB** | `infra/db/016_phase5_ticket_commerce_foundation.sql` — `ticket_entitlements` (`status`, `checked_in_at`, `ticket_code`); `infra/db/022_phase54_persistence.sql` — `event_check_ins`, `event_feed_items` |
| **Nest** | `services/api/src/modules/events/event-operations.service.ts`; `GET/POST events/:eventId/check-ins` in `events.controller.ts`; SSE `GET events/:eventId/feed/stream` in `event-feed-sse.controller.ts` |
| **Flutter ops** | `mobile/lib/features/operations/**`, `mobile/lib/core/api/operations_api.dart`, routes `/events/:id/day/check-in` & `/day/scan` |
| **Flutter attendee** | `attendee_my_passes_screen.dart`, `showAttendeeQrSheet` (`attendee_event_card.dart`), `attendee_events_provider.dart`, Tickets / My Events check-in chips |
| **Packages** | `qr_flutter` in `mobile/pubspec.yaml`; **no** `mobile_scanner` / `qr_code_scanner` / camera barcode package |

---

## 6.1 Check-in

### QR Code Scanner (camera)

| Field | Value |
|-------|--------|
| **Classification** | **Not Implemented** |
| **Flutter** | `mobile/lib/features/operations/screens/qr_scan_screen.dart` — decorative “scanner” panel + **Ticket ID text field** + “Scan now”; no `CameraPreview` / barcode stream |
| **Providers** | `performQrCheckIn` in `operations_providers.dart`; `lastQrScanProvider` |
| **API** | `POST events/:eventId/check-ins` with `ticketCode` + `source: 'qr'` via `OperationsApi.checkIn` |
| **Backend** | `EventOperationsService.checkIn` validates entitlement — does not care about camera vs typed code |
| **Why not accessible (attendee)** | Scanner is ops-only (`/events/:id/day/scan`, `OperationsShell` tab 2). Even for organizers, there is **no real camera scan**. |
| **Effort** | **Large** (package, permissions, continuous scan, torch, platform hardening) |

### Manual Check-in

| Field | Value |
|-------|--------|
| **Classification** | **Implemented and Working** (organizer/ops) |
| **Flutter** | `CheckInCenterScreen` → `performManualCheckIn`; guest drawer paths under operations widgets |
| **Providers** | `performManualCheckIn`, `operationsGuestsProvider` |
| **API** | `POST events/:eventId/check-ins` with `entitlementId`, `source: 'manual'` |
| **Backend / DB** | Updates `ticket_entitlements.status = checked_in`, inserts `event_check_ins` |
| **Why not accessible (attendee)** | Organizer ownership required; no attendee self-check-in product. |
| **Effort** | Done for ops; attendee self-check-in (if desired) = **Medium** |

### Check-in Validation

| Field | Value |
|-------|--------|
| **Classification** | **Implemented and Working** (backend + ops UI) |
| **Backend** | Lookup by `ticketCode` / `entitlementId`; require `status === 'issued'`; else `TICKET_INVALID` / `TICKET_NOT_FOUND` |
| **Flutter** | Maps success → VIP/VVIP/valid via tier name string; errors → `QrScanResult.invalid` |
| **Caveat** | No cryptographic signature verify on QR payload; VIP is string match on `tierName`, not policy engine. Platform stub `EventService.validateCheckIn` (always succeeds) is **not** the production path. |
| **Effort** | **Small** to harden (HMAC/signature, time windows) |

### Duplicate Check-in Prevention

| Field | Value |
|-------|--------|
| **Classification** | **Implemented and Working** |
| **Backend** | If already `checked_in` → `{ ok: true, duplicate: true }` |
| **DB** | Unique index `(event_id, ticket_code)` on `event_check_ins` + `ON CONFLICT DO NOTHING` |
| **Flutter** | `QrScanResult.alreadyUsed` / “Already checked in” |
| **Effort** | — |

### Invalid Ticket Handling

| Field | Value |
|-------|--------|
| **Classification** | **Implemented and Working** |
| **Backend** | `TICKET_NOT_FOUND`, `TICKET_INVALID` (voided/refunded/non-issued) |
| **Flutter** | `QrScanResult.invalid` + `QrScanResultPanel`; demo chip `tkt_invalid` |
| **Effort** | — |

### Check-in Status

| Field | Value |
|-------|--------|
| **Classification** | **Partially Implemented** |
| **Ops** | List pending (`issued`) vs checked-in; filters; KPIs in command center / health |
| **Attendee** | Entitlement `status == checked_in` → chips / KPI / My Events (`attendee_events_provider.dart`, Phase 5 mapping) |
| **Gap** | Attendee status is boolean/chip only — no rich door-state pass UX |
| **Effort** | **Small–Medium** for richer attendee status |

### Check-in Timestamp

| Field | Value |
|-------|--------|
| **Classification** | **Partially Implemented** |
| **DB** | `ticket_entitlements.checked_in_at`, `event_check_ins.checked_in_at` |
| **Ops API** | Returns `checkedInAt` in check-in list |
| **Attendee API** | `TicketEntitlementsService.listForUser` **does not select or return `checked_in_at`** |
| **Flutter attendee** | No arrival timestamp on My Passes |
| **Effort** | **Small** (expose field + UI) |

---

## 6.2 Digital Event Pass

### QR Ticket

| Field | Value |
|-------|--------|
| **Classification** | **Implemented and Working** |
| **Flutter** | `qr_flutter` `QrImageView` in `attendee_my_passes_screen.dart`, `showAttendeeQrSheet` in `attendee_event_card.dart` |
| **Providers** | `attendeeTicketsSyncProvider` / `attendeeEventsProvider` |
| **API** | `GET me/ticket-entitlements` → `qrPayload` / `ticketCode` |
| **Backend** | `TicketEntitlementsService` — `qrPayload` from metadata or ticket code |
| **Effort** | — |

### Live Event Pass

| Field | Value |
|-------|--------|
| **Classification** | **Partially Implemented** |
| **Evidence** | Dedicated `/attendee/passes` with lifecycle chip (Upcoming / Ongoing / …) |
| **Missing** | Door-state UX (“ready for entry” / “already used” / gate instructions), auto-brightness, live refresh when ops checks in |
| **Effort** | **Medium** |

### Pass Status

| Field | Value |
|-------|--------|
| **Classification** | **Partially Implemented** |
| **Evidence** | Entitlement statuses `issued \| checked_in \| voided \| refunded` + lifecycle labels on passes/registrations |
| **Missing** | Valid window, gate lane, transfer lock, expired-before-entry states |
| **Effort** | **Medium** |

### Access Level

| Field | Value |
|-------|--------|
| **Classification** | **Partially Implemented** |
| **Evidence** | Tier / `accessLevel` metadata shown on some event detail paths; ops VIP/VVIP messaging from tier **name** string |
| **Missing** | Policy-driven access levels tied to venue zones |
| **Effort** | **Medium** |

### Offline Pass

| Field | Value |
|-------|--------|
| **Classification** | **Partially Implemented** |
| **Evidence** | `attendeeOfflineProvider` + offline banner on My Passes (“Passes already on this device remain available”) — depends on prior Riverpod cache, not a durable vault |
| **Actions** | `AttendeePassActions.downloadTicket` / share — plaintext / clipboard, not signed offline credential |
| **Effort** | **Large** (local store + signed payload + expiry) |

### Multi-ticket Support

| Field | Value |
|-------|--------|
| **Classification** | **Implemented and Working** |
| **Evidence** | One entitlement = one pass/QR; My Passes and Tickets list multiple entitlements |
| **Gap** | No dedicated “bundle selector” beyond list UX |
| **Effort** | **Small** for polish |

---

## 6.3 Venue Entry

### Entry Validation

| Field | Value |
|-------|--------|
| **Classification** | **Partially Implemented** |
| **Evidence** | Gate logic = entitlement exists for event + `status === 'issued'` then flip to `checked_in` |
| **Missing** | Venue/session/time-window, zone, capacity gate, door assignment |
| **Effort** | **Large** for full venue policy |

### VIP Access

| Field | Value |
|-------|--------|
| **Classification** | **Partially Implemented** |
| **Evidence** | Ops filters VIP/VVIP (`CheckInFilter`); success copy “VIP — lounge access” / “VVIP — fast lane” |
| **Missing** | Separate lane/zone entities; access policy beyond tier name heuristics |
| **Effort** | **Medium** |

### General Admission

| Field | Value |
|-------|--------|
| **Classification** | **Partially Implemented** |
| **Evidence** | Default tier “General” / non-VIP → `QrScanResult.valid` |
| **Missing** | Explicit GA lane / capacity / entry rules |
| **Effort** | **Medium** (with VIP) |

### Staff Validation

| Field | Value |
|-------|--------|
| **Classification** | **Not Implemented** |
| **Evidence** | Check-in requires **event organizer owner** (`assertOrganizerOwnsEvent`). No door-staff role, scanner-staff grant, or delegated validator identity. |
| **Effort** | **Large** |

### Re-entry Rules

| Field | Value |
|-------|--------|
| **Classification** | **Not Implemented** |
| **Evidence** | `checked_in` is terminal for validation purposes; duplicates → already used. No `re_entry_allowed`, exit scan, or multi-entry entitlement. |
| **Effort** | **Medium–Large** |

---

## 6.4 Live Attendance

### Attendance Status

| Field | Value |
|-------|--------|
| **Classification** | **Implemented and Working** (organizer); **Partially Implemented** (attendee) |
| **Ops** | `listCheckIns` → pending + checkedIn; KPIs in `EventCommandCenterScreen`, ops health, closing analytics |
| **Attendee** | Checked-in chips / KPI from entitlement status only |
| **Effort** | Ops done; richer attendee history = **Small** |

### Live Event Indicator

| Field | Value |
|-------|--------|
| **Classification** | **Implemented but Not Wired** (realtime) |
| **Frontend** | `EosLiveIndicator` on ops shells / feed / dashboard — visual only |
| **Backend** | `RealtimeBroadcastService` + `GET events/:eventId/feed/stream` publishes on check-in |
| **Gap** | **No Flutter client** consumes SSE (`feed/stream` unused in `mobile/`). Updates via provider refresh / revision bump after local actions. |
| **Effort** | **Medium** |

### Session Attendance

| Field | Value |
|-------|--------|
| **Classification** | **Not Implemented** |
| **Evidence** | No session/agenda check-in entities; only event-level entitlement check-in |
| **Effort** | **Large** |

### Attendance History

| Field | Value |
|-------|--------|
| **Classification** | **Partially Implemented** |
| **Evidence** | Persisted in `event_check_ins` + feed `guest_checked_in`; platform admin ops center lists recent check-ins |
| **Stub** | Check-in center “History” button → Snackbar only (`CheckInCenterScreen`) |
| **Effort** | **Small–Medium** |

---

## 6.5 Organizer Integration

### Capability matrix

| Capability | Classification | Evidence |
|------------|----------------|----------|
| QR scanning UI | **Partially Implemented** | Routes `/events/:id/day/scan`, `OperationsShell`, `EventNavigator` / `openCheckIn` — **text ticket ID**, not camera |
| Ticket validation | **Implemented and Working** | Nest validation + Flutter result mapping |
| Check-in | **Implemented and Working** | Manual + “QR” (typed) → `POST …/check-ins` |
| Entry approval (human queue) | **Not Implemented** | Auto-commit on valid ticket; no approve/deny queue |
| Attendance recording | **Implemented and Working** | Entitlement update + `event_check_ins` + feed + realtime bus publish |
| Command Center v3 “Check in” | **Implemented but Not Wired** | `attendees_tab_v3.dart` `_checkIn` only mutates **local organizer store** — does **not** call commerce/ops API |

### How the attendee flow should integrate (existing design)

```
Attendee buys / receives ticket
  → ticket_entitlements issued + qrPayload
  → Attendee shows QR (My Passes / ticket sheet)
  → Organizer ops scans/enters ticketCode OR manual check-in by entitlementId
  → POST events/:eventId/check-ins (organizer-owned)
  → status → checked_in, checked_in_at set, event_check_ins row, feed item
  → Attendee sees checked-in chips on next GET me/ticket-entitlements refresh
```

**Integration gaps for a finished Phase 6:**

1. No live pass update push/SSE on attendee device after gate scan.  
2. No attendee “you’re in / welcome” confirmation surface.  
3. Camera scanner missing on ops side.  
4. Command Center v3 check-in not wired to the same API as Event Operations.  
5. Staff roles / re-entry / venue policy not modeled.

| Effort to finish organizer↔attendee integration (pass live-state + refresh + ops camera) | **Medium–Large** |

---

## Feature scorecard

| # | Feature | Classification | Effort |
|---|---------|----------------|--------|
| 6.1 | Camera QR scanner | Not Implemented | Large |
| 6.1 | Manual check-in | Implemented and Working (ops) | — |
| 6.1 | Check-in validation | Implemented and Working | Small harden |
| 6.1 | Duplicate prevention | Implemented and Working | — |
| 6.1 | Invalid ticket handling | Implemented and Working | — |
| 6.1 | Check-in status | Partially Implemented | Small–Medium |
| 6.1 | Check-in timestamp | Partially Implemented | Small |
| 6.2 | QR ticket | Implemented and Working | — |
| 6.2 | Live event pass | Partially Implemented | Medium |
| 6.2 | Pass status | Partially Implemented | Medium |
| 6.2 | Access level | Partially Implemented | Medium |
| 6.2 | Offline pass | Partially Implemented | Large |
| 6.2 | Multi-ticket | Implemented and Working | Small polish |
| 6.3 | Entry validation | Partially Implemented | Large |
| 6.3 | VIP access | Partially Implemented | Medium |
| 6.3 | General admission | Partially Implemented | Medium |
| 6.3 | Staff validation | Not Implemented | Large |
| 6.3 | Re-entry rules | Not Implemented | Medium–Large |
| 6.4 | Attendance status | Implemented and Working (ops) / Partial (attendee) | Small |
| 6.4 | Live event indicator | Implemented but Not Wired | Medium |
| 6.4 | Session attendance | Not Implemented | Large |
| 6.4 | Attendance history | Partially Implemented | Small–Medium |
| 6.5 | Organizer QR / validate / check-in / record | Partial → Working | Medium–Large to finish |
| 6.5 | Entry approval queue | Not Implemented | Medium |

---

## Key file index

### Flutter — Organizer / Ops

| Path | Role |
|------|------|
| `mobile/lib/features/operations/screens/qr_scan_screen.dart` | Fake scanner + typed ticket ID |
| `mobile/lib/features/operations/screens/check_in_center_screen.dart` | Manual check-in, VIP filters, History stub |
| `mobile/lib/features/operations/screens/operations_shell.dart` | Ops tabs including scan |
| `mobile/lib/features/operations/providers/operations_providers.dart` | `performQrCheckIn`, `performManualCheckIn` |
| `mobile/lib/core/api/operations_api.dart` | HTTP check-ins / feed / incidents |
| `mobile/lib/portals/customer/router/event_route_registry.dart` | `/day/check-in`, `/day/scan` |
| `mobile/lib/portals/customer/navigation/event_navigator.dart` | `openCheckIn` |
| `mobile/lib/router/app_router.dart` | Registers day scan / check-in routes |
| `mobile/lib/features/organizer/command_center_v3/tabs/attendees_tab_v3.dart` | Local-only check-in (not wired to API) |

### Flutter — Attendee

| Path | Role |
|------|------|
| `mobile/lib/portals/attendee/screens/attendee_my_passes_screen.dart` | Digital passes + QR |
| `mobile/lib/features/public/widgets/attendee_event_card.dart` | `showAttendeeQrSheet` |
| `mobile/lib/features/public/providers/attendee_events_provider.dart` | Entitlements → checked-in mapping |
| `mobile/lib/portals/attendee/commerce/attendee_pass_actions.dart` | Share / download ticket text |
| `mobile/lib/portals/attendee/widgets/attendee_tickets_tab.dart` | Check-in chips / command centre links |
| `mobile/lib/core/api/ticket_commerce_api.dart` | Entitlement DTO including `qrPayload` |

### Nest / DB

| Path | Role |
|------|------|
| `services/api/src/modules/events/event-operations.service.ts` | listCheckIns + checkIn |
| `services/api/src/modules/events/events.controller.ts` | `GET/POST events/:eventId/check-ins` |
| `services/api/src/modules/commerce/ticket-entitlements.service.ts` | Attendee entitlements (no `checked_in_at`) |
| `services/api/src/integrations/realtime/event-feed-sse.controller.ts` | SSE feed stream |
| `services/api/src/modules/platform-admin/admin-operations-center.service.ts` | Admin recent check-ins |
| `infra/db/016_phase5_ticket_commerce_foundation.sql` | `ticket_entitlements` |
| `infra/db/022_phase54_persistence.sql` | `event_check_ins` |

### API endpoints

| Method | Path | Persona |
|--------|------|---------|
| `GET` | `events/:eventId/check-ins` | Organizer owner |
| `POST` | `events/:eventId/check-ins` | Organizer owner |
| `GET` | `events/:eventId/feed` | Organizer |
| `GET` | `events/:eventId/feed/stream` | SSE (no Flutter consumer found) |
| `GET` | `me/ticket-entitlements` | Attendee (status + QR; no timestamp) |

---

## Effort summary (if Phase 6 is started later)

| Work package | Effort | Notes |
|--------------|--------|-------|
| Expose `checkedInAt` to attendee entitlements + pass UI | Small | BE field + FE chip |
| Wire Command Center v3 check-in to ops API | Small | Align with Event Operations |
| Live pass door-state + post-check-in refresh | Medium | Compose existing status |
| Flutter SSE / live attendance client | Medium | Consume existing stream |
| Camera QR scanner for ops | Large | New dependency + UX |
| Staff door roles | Large | AuthZ model |
| Venue / re-entry / session attendance | Medium–Large | New policy + schema |
| True offline signed pass | Large | Crypto + local vault |

---

## Final determination

**Phase 6 is partially implemented.**

- **Already built:** organizer manual check-in, ticket-code validation, duplicate/invalid handling, attendance recording, attendee QR digital passes, multi-ticket list, attendee check-in **status chips**.  
- **Not built / stubbed:** camera scanning, attendee gate/venue/live-attendance experiences, staff validation, re-entry, session attendance, SSE-backed live updates on mobile, durable offline pass.  
- **Live QA explanation:** Attendee app correctly shows **no Phase 6 gate flows** because those flows are organizer Event OS surfaces (and even there, “QR scan” is typed ID, not camera). Attendee Phase 6 product work has **not been started** as a dedicated sprint.

**STOP — audit only. No implementation performed.**
