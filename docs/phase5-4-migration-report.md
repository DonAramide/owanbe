# Phase 5.4 — Persistence Migration Report

**Date:** 2026-06-20  
**Gate result:** **PASS** (19/19 checks)  
**Phase 6 Platform Administration:** **BLOCKED until this gate passes** → **UNBLOCKED for readiness review**

---

## Objective

Replace in-memory mock stores with Postgres-backed APIs for core event operations. No new UI modules, dashboards, or business features.

---

## 1. Mock stores — production path status

| Store | Path | Production path | Dev fallback |
|-------|------|-----------------|--------------|
| `OrganizerEventStore` | `mobile/lib/features/organizer/data/organizer_event_store.dart` | **API via `EventsApi` + providers** | `ALLOW_MOCK_PERSISTENCE_FALLBACK=true` |
| `PublicEventCatalog` | `mobile/lib/features/public/data/public_event_catalog.dart` | **API via `EventsApi.listPublicEvents`** | same flag |
| `VendorStore` (participation) | `mobile/lib/features/vendor/data/vendor_store.dart` | **API via `VendorEventsApi`** | same flag |
| `OperationsStore` | `mobile/lib/features/operations/data/operations_store.dart` | **API via `OperationsApi`** (check-ins, incidents, feed) | same flag |

Mock store files remain for dev fallback only. Screens and providers no longer call stores directly on the production path.

---

## 2. API endpoints implemented

### 5.4A — Events
- `GET /v1/events`
- `GET /v1/events/:id`
- `POST /v1/events`
- `PATCH /v1/events/:id`
- `POST /v1/events/:id/publish`
- `POST /v1/events/:id/go-live`
- `GET /v1/events/:id/manage` (organizer full event)

### 5.4B — Ticket tiers
- `GET /v1/events/:id/tiers`
- `GET /v1/events/:id/tiers/manage`
- `POST /v1/events/:id/tiers`
- `PATCH /v1/tiers/:id`
- `DELETE /v1/tiers/:id`

### 5.4C — Organizer
- `GET /v1/organizers/me`
- `GET /v1/organizers/me/events` (full `EventView` list)
- `GET /v1/organizers/me/dashboard`

### 5.4D — Vendor participation
- `GET /v1/vendor/events`
- `POST /v1/vendor/events/:id/apply`
- `POST /v1/vendor/events/:id/accept`
- `POST /v1/vendor/events/:id/reject`

### 5.4E — Operations
- `GET/POST /v1/events/:id/check-ins`
- `GET/POST /v1/events/:id/incidents`
- `GET /v1/events/:id/feed`

Module: `services/api/src/modules/events/`

---

## 3. Database tables

Migration: `infra/db/022_phase54_persistence.sql`

| Table | Purpose |
|-------|---------|
| `vendor_event_participations` | Vendor invitations, applications, approvals |
| `event_check_ins` | Persisted check-in records |
| `event_incidents` | Operational incidents |
| `event_feed_items` | Live ops feed |

Existing tables reused: `events`, `event_ticket_tiers`, `ticket_entitlements`, `ticket_order_lines`.

Apply: `node scripts/apply-phase54-migration.js`

---

## 4. Mobile providers migrated

| Provider file | API client |
|---------------|------------|
| `organizer_providers.dart` | `EventsApi` |
| `public_providers.dart` | `EventsApi` |
| `vendor_providers.dart` | `VendorEventsApi` (+ finance unchanged) |
| `operations_providers.dart` | `OperationsApi` |

New clients:
- `mobile/lib/core/api/events_api.dart`
- `mobile/lib/core/api/vendor_events_api.dart`
- `mobile/lib/core/api/operations_api.dart`
- `mobile/lib/core/api/persistence_providers.dart`

Persistence helpers:
- `organizer_persistence.dart` — create, publish, go-live, tiers
- `vendor_persistence.dart` — apply, accept participation

---

## 5. Gate success criteria

| Criterion | Result |
|-----------|--------|
| Create event → publish → marketplace updates | **PASS** |
| Event persists after restart (DB proxy) | **PASS** |
| Organizer-created tiers in checkout list | **PASS** |
| Dashboard API (metrics from DB) | **PASS** |
| Vendor participation survives restart | **PASS** |
| Check-ins survive restart | **PASS** |
| Incidents survive restart | **PASS** |
| Marketplace uses real events | **PASS** |

Verification script: `node scripts/verify-phase5-4-persistence.js`

---

## 6. Dev configuration

```env
OWANBE_API_BASE=http://localhost:8080/v1
OWANBE_TENANT_ID=11111111-1111-4111-8111-111111111111
OWANBE_ORGANIZER_USER_ID=22222222-2222-4222-8222-222222222222
ALLOW_MOCK_PERSISTENCE_FALLBACK=false   # production path
```

API requires `ALLOW_DEV_COMMERCE_AUTH=true` for dev header auth.

---

## 7. Known residual mock scope (out of 5.4)

- Organizer vendor slot invite/approve (no API yet — mock fallback only)
- Attendee list in organizer portal (entitlements not surfaced in organizer event view)
- Vendor catalog / orders (unchanged local mock)
- Incident status updates (no PATCH endpoint — open incidents only via API)

These do not block Phase 5.4 gate; they are follow-up hardening items.

---

## Overall result

**PASS** — Core event operations are API-backed and Postgres-persisted. Phase 5.4 gate cleared.
