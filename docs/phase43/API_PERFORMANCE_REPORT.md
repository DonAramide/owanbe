# Phase 43.3 — API Performance Review

**Date:** 2026-06-04  
**Service:** `services/api` (NestJS + PostgreSQL)  
**Method:** Controller/service trace, SQL pattern review, metrics inventory

---

## Executive summary

Core organizer APIs use parameterized queries with tenant scoping. RBAC guards run before handlers — acceptable overhead. Primary risks: unpaginated public listings, N+1 in `listPublic` events, sequential invitation dispatch, in-memory metrics/throttling (not multi-pod safe), and large guest payloads without cursor pagination.

---

## Endpoint audit matrix

| Domain | Key routes | Query pattern | Pagination | Index use | N+1 risk | Caching |
|--------|------------|---------------|------------|-----------|----------|---------|
| Events | `GET /events`, `GET /events/:id` | Single tenant filter | List: offset implicit | `tenant_id` | Low | None |
| Events public | `GET /events/public` | Join + map | **None** | Partial | **High** | CDN candidate |
| Guests | `GET /events/:id/guests` | `WHERE event_id` | **None** | `event_id` | Low | None |
| Invitations | `POST .../send` | Loop per guest | N/A | Per-row | **Medium** | None |
| Marketplace | `GET /vendors/catalog` | Catalog tenant | **None** | OK | Low | Redis P2 |
| Vendor CRM | vendor-scoped | Tenant + vendor | Partial | OK | Low | None |
| Rentals | bookings CRUD | FK joins | List limited | OK | Low | None |
| Finance | treasury, invoices | Aggregates | Some | OK | Low | None |
| Admin | dashboard aggregates | Multiple COUNT | N/A | OK | Low | Short TTL P2 |

---

## Detailed findings

### Events (`modules/events`)

- **listPublic:** Loads events then resolves venue/media per row — classic N+1. **Recommendation:** batch venue fetch or JOIN.
- **getById / organizer list:** Efficient single-query patterns with `tenant_id` guard.

### Guests (`modules/guests` / event-config)

- Returns full guest array including ticket metadata — payload grows O(n). **Recommendation:** cursor pagination `?limit=&cursor=`, default limit 100.

### Invitations (`event-invitations.service`)

- Send loop issues individual notification + DB writes per guest.
- Metrics: `rsvp_total` incremented on RSVP — good.
- **Recommendation:** batch insert + queue notifications (P1, not Phase 43).

### Marketplace (`vendors` module)

- `listCatalog` returns full vendor set for catalog tenant — acceptable at current scale (~100 vendors), not at marketplace scale.

### Payments / Commerce

- Ticket capture increments `payments_captured_total` with `rail: ticket`.
- **Gap:** Booking/rental webhook capture does not increment same metric — observability gap (documented in OBSERVABILITY_REPORT).

### Admin / Platform

- Launch ops dashboard reads in-memory metric snapshot — fast but pod-local.

---

## Execution time estimates (staging target SLOs)

| Endpoint class | Target p95 | Current risk |
|----------------|------------|--------------|
| Health | &lt;50ms | Low |
| Auth / JWT validate | &lt;100ms | Low |
| Single resource GET | &lt;200ms | Low |
| Guest list (500 rows) | &lt;500ms | Medium |
| Public events list | &lt;800ms | High (N+1) |
| Invitation batch (100) | &lt;30s async | High if sync |

---

## Index review

Existing migrations include tenant and event FK indexes (Phase 41 DB validation PASS). Verify on production:

- `events(tenant_id, status)`
- `guests(event_id)`
- `event_invitations(event_id)`
- `vendor_catalog(tenant_id)`

Run `EXPLAIN ANALYZE` on staging for top 10 slow queries from request logs.

---

## Filtering & sorting

- Guest filters: client-side in Flutter — API supports full dump only.
- Marketplace: server returns full catalog; client filters by category/city/rating.
- Admin lists: generally filtered by tenant — OK.

---

## Caching opportunities (future)

| Resource | Strategy | Invalidation |
|----------|----------|--------------|
| Public event cards | CDN + short TTL | On publish |
| Vendor catalog | Redis 5m | On vendor update |
| Event config snapshot | Per-request memo (request scope) | N/A |

---

## Phase 43 changes

- **Request log middleware:** `tenantId` now prefers JWT-resolved `req.tenantId` over raw header — improves log correlation, no behavior change.

No new endpoints introduced. Pagination/N+1 fixes deferred to P1 debt register.

---

## Verification

- `npm run build` (api) — must pass
- `npm test` — 10 spec files (guards, tenant isolation, Quaser signature)
- Load test: recommend `k6` or Artillery against staging guest list + public events before GA
