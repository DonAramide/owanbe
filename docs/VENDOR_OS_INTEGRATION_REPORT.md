# Vendor OS Integration Report

**Sprint:** Enterprise Vendor OS Integration  
**Status:** Complete — STOP (no new features beyond contract wiring)

---

## Mission

Connect the **Organizer Vendor Pipeline** to **Vendor OS** using existing `vendor_event_requests` business records. Organizer OS, Vendor OS, and Attendee OS remain **three separate worlds** — integration happens through **business contracts**, not shared UI.

---

## 1. Identity Unification

### Problem

Three disconnected vendor identifiers were in use:

| Surface | Legacy ID |
|---------|-----------|
| Marketplace mock | `v12` |
| Vendor workspace / VendorStore | `vendor_jollof` |
| Postgres canonical record | `55555555-5555-4555-8555-555555555555` |

Organizer requests targeted `v12`, which does not exist in `vendors` — requests appeared in organizer dev-store fallback but never reached the vendor inbox API.

### Solution

- **`VendorIdentity`** (`mobile/lib/features/vendor/vendor_identity.dart`) — maps legacy aliases to canonical UUID.
- **`canonicalVendorIdProvider`** — resolves signed-in vendor via `GET /me/vendor-id` (Identity API), with dev fallback.
- **Request creation** (`inviteVendorToEvent`, `inviteVendor`) now calls `VendorIdentity.resolveMarketplaceVendorId()` before `POST /events/:id/vendor-requests`.
- **Mock marketplace** Jollof & Co uses canonical UUID.
- **VendorStore** `demoVendorId` aligned to canonical UUID.

Every vendor request now references the same vendor row the Vendor OS session owns.

---

## 2. Request Lifecycle

### Canonical record

`vendor_event_requests` (Postgres) — one row per `(event_id, vendor_id)`.

### Stages

```
new → negotiating → accepted → scheduled → arrived → completed
                 ↘ declined / cancelled
```

### API (unchanged routes, fixed behavior)

| Action | Endpoint | Actor |
|--------|----------|-------|
| Create request | `POST /events/:eventId/vendor-requests` | Organizer |
| List event pipeline | `GET /events/:eventId/vendor-requests` | Organizer |
| List vendor inbox | `GET /vendors/:vendorId/requests` | Vendor |
| Transition stage | `POST /vendor-requests/:id/stage` | Organizer or Vendor |
| Counter quote | `POST /vendor-requests/:id/counter` | Vendor (**new**) |
| Message | `POST /vendor-requests/:id/messages` | Organizer or Vendor (**new**) |

### Backend fixes

1. **Vendor stage transitions** — `transitionStage` now returns `listForVendor` when the vendor acts (previously always called `listForEvent`, which failed for vendor sessions).
2. **Accept → participation** — `accepted` stage upserts `vendor_event_participations` with status `approved` so Vendor Events tab shows live events.
3. **Organizer name on inbox rows** — vendor inbox API includes `organizerName` for display.

### Correlation

`requestId` is the correlation ID across request → negotiation → acceptance → participation → feed → notifications (`metadata.correlationId`).

---

## 3. Organizer ↔ Vendor Interaction Flow

```
Organizer OS                          Vendor OS
────────────                          ─────────
Marketplace (discovery only)
    │
    ▼
Request Vendor ──POST vendor-requests──► Vendor Inbox (GET vendors/:id/requests)
    │                                        │
    ▼                                        ├─ Accept  ──POST .../stage (accepted)──►
Vendor Pipeline ◄── same CRM rows ──────────├─ Decline ──POST .../stage (declined)──►
(eventVendorCrmProvider)                   ├─ Counter ──POST .../counter────────────►
                                           └─ Message ──POST .../messages──────────►
```

- **Organizer pipeline UI unchanged** — `customer_event_vendor_pipeline_screen.dart` still drives `eventVendorCrmProvider`.
- **Vendor dashboard** — Negotiation Command Center now reads `vendorInboxSnapshotProvider` (live CRM) instead of `vendorIntelligenceProvider` mock negotiations when API data is available.
- **Marketplace** remains discovery-only; selecting a vendor creates a CRM request, not a dashboard view.

---

## 4. Notification Flow

### Infrastructure reused

- **`notifications` table** — in-app rows (`channel = in_app`, `status = delivered`).
- **`NotificationService`** — push delivery audit (`notification_deliveries`).
- **`event_feed_items`** — event-scoped activity (`feed_type = vendor_crm`).

### Events

| Trigger | Recipient | Kind |
|---------|-----------|------|
| Organizer creates request | Vendor owner | `vendor_request_incoming` |
| Vendor accepts / declines / stages | Organizer owner | `vendor_request_update` |
| Vendor counter quote | Organizer owner | `vendor_request_counter` |
| Either party messages | Other party | `vendor_request_message` |

### Mobile surfacing

- **Vendor dashboard** — `vendorInboxNotifications()` from live inbox replaces demo notification strings when CRM data loads.
- **Organizer hub alerts** — `organizerVendorCrmAlertsProvider` merges negotiating / accepted / declined CRM items into `hubOrganizerAlertsProvider`.

---

## 5. Messaging Flow

No second chat system was built.

- **Contract:** `POST /vendor-requests/:id/messages` appends to `vendor_request_stage_history` and `event_feed_items`.
- **Vendor dashboard** — message sheet on negotiation cards calls `vendorMessageOrganizer()`.
- **Request `message` field** — preserved from organizer at creation; shown in vendor inbox context.

---

## 6. Event Participation Flow

```
Vendor accepts request (stage = accepted)
        │
        ▼
UPSERT vendor_event_participations (status = approved)
        │
        ▼
GET /vendor/events → Vendor Events tab (vendorParticipationsProvider)
```

Accepted jobs appear in Vendor OS Events — not seed/mock participations when API succeeds.

---

## 7. Regression Report

| Area | Status | Notes |
|------|--------|-------|
| Attendee OS | **Unchanged** | No attendee files modified |
| Organizer Event OS (Phases 1–6) | **Unchanged** | Pipeline screen/layout preserved |
| Organizer Vendor Pipeline | **Reused** | Same UI + `eventVendorCrmProvider` |
| Marketplace | **Discovery only** | Still creates requests via sheet |
| Vendor dashboard layout | **Preserved** | Data source swapped for negotiations/notifications |
| Vendor finance / contracts mock | **Retained** | No live finance contract in CRM sprint scope |
| Navigation architecture | **Unchanged** | Prior sprint intact |

---

## 8. End-to-End Validation

| # | Scenario | Expected | Implementation |
|---|----------|----------|----------------|
| 1 | Organizer requests caterer → Vendor inbox | Incoming request | Canonical vendor ID + `vendorInboxProvider` on dashboard |
| 2 | Vendor accepts → Organizer pipeline | Stage `accepted` | `transitionStage` + organizer `refreshVendorCrm` |
| 3 | Vendor declines → Organizer pipeline | Stage `declined` | Same |
| 4 | Vendor counter quote → Organizer | Stage `negotiating` + alert | `counterOffer` endpoint + `organizerVendorCrmAlertsProvider` |
| 5 | Accepted → Vendor Events | Participation row | `ensureParticipationOnAccept` |
| 6 | Organizer event vendor module | Shows accepted | Existing pipeline reads same CRM API |
| 7 | Notifications both directions | In-app + feed | `enqueueInAppNotification` + hub alerts |
| 8 | Attendee unaffected | PASS | No attendee changes |
| 9 | Organizer Event OS unaffected | PASS | No Event OS redesign |
| 10 | No demo data where live exists | PASS | Dashboard prefers inbox over mock when snapshot loads |

### Device verification checklist

1. Sign in as **organizer** → create event → Marketplace → Request **Jollof & Co** (or Golden Pot Catering from live catalog).
2. Sign in as **vendor@owanbe.dev** → Vendor Dashboard → Negotiation Command Center shows incoming request with event title and organizer name.
3. **Accept** → switch to organizer → event Vendor Pipeline shows **Accepted**.
4. Vendor → **Events** tab shows event participation (after API refresh).
5. Hub → **Alerts** shows vendor CRM items for organizer; vendor notifications list shows inbox summary.

---

## 9. Files Changed

### Backend

- `services/api/src/modules/vendor-operations/vendor-crm.service.ts`
- `services/api/src/modules/vendor-operations/vendor-operations.controller.ts`

### Mobile

- `mobile/lib/features/vendor/vendor_identity.dart` *(new)*
- `mobile/lib/features/vendor/providers/vendor_inbox_integration.dart` *(new)*
- `mobile/lib/features/vendor/providers/vendor_providers.dart`
- `mobile/lib/features/vendor/screens/vendor_dashboard_screen.dart`
- `mobile/lib/features/vendor/data/vendor_store.dart`
- `mobile/lib/portals/customer/providers/vendor_crm_providers.dart`
- `mobile/lib/portals/customer/models/vendor_crm_models.dart`
- `mobile/lib/portals/customer/data/customer_event_persistence.dart`
- `mobile/lib/portals/customer/providers/customer_home_providers.dart`
- `mobile/lib/features/organizer/data/organizer_persistence.dart`
- `mobile/lib/features/home/providers/living_home_providers.dart`
- `mobile/lib/platform/repositories/impl/vendor_repository_impl.dart`

### Tests

- `mobile/test/features/vendor/vendor_inbox_integration_test.dart` — **4/4 passing**

---

## 10. Architectural Compliance

| Principle | Compliance |
|-----------|------------|
| Three independent OSes | ✓ No merged dashboards |
| Business contracts not shared UI | ✓ CRM API is the contract |
| Marketplace = discovery | ✓ Creates request only |
| Reuse organizer pipeline | ✓ No redesign |
| Reuse notification infra | ✓ `notifications` + feed + push audit |
| Event context persistence | ✓ tenant / event / vendor / requestId |

---

**STOP.** This sprint connects existing enterprise modules into a single end-to-end vendor request workflow. No new worlds, no Attendee changes, no dashboard redesign.
