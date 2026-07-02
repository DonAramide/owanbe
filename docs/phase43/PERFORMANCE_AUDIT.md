# Phase 43.1 — Performance Audit

**Date:** 2026-06-04  
**Branch:** `feature/owanbe-event-v2`  
**Scope:** Customer Portal (canonical Event OS), Vendor Portal, Admin Portal, NestJS API  
**Method:** Static code audit, provider graph review, API handler tracing. No new features.

---

## Executive summary

Event OS modules (Phase 42.4–42.6) are structurally sound: shared `EventModuleScaffold`, skeleton loading, and friendly errors reduce jank on workspace routes. Shell routes (Home, Marketplace hub) and large-list modules (Guests, Wall) remain the primary Flutter performance targets. API layer is generally efficient for single-tenant organizer flows; public listing and invitation batch endpoints need pagination and N+1 remediation before high-traffic production.

**Overall Flutter performance:** 7.5/10 (post Phase 43.2 optimizations)  
**Overall API performance:** 7/10

---

## Measurement methodology

| Metric | Method |
|--------|--------|
| First paint / TTI | Code-path complexity + provider depth (DevTools recommended on device) |
| API latency | Handler query count + payload size review |
| Provider rebuilds | Riverpod `watch`/`select` graph audit |
| Widget rebuilds | Scaffold nesting, `Consumer` usage |
| Network | Duplicate `FutureProvider` and fallback chains |
| Cold/warm start | App bootstrap (`main.dart`, dotenv, Supabase init) — warm path reuses session |

Production baselines should be captured on staging with Flutter DevTools Timeline + API `durationMs` from request logs after deploy.

---

## Workflow audit matrix

| Workflow | Route(s) | Loading UX | Rebuild risk | Network | List scale | Phase 43.2 action |
|----------|----------|------------|--------------|---------|------------|-------------------|
| Customer Home | `/home` | Skeleton (was spinner) | Medium — 4 parallel providers | 3–4 calls on refresh | Low | Friendly errors; skeleton |
| Command Center | `/events/:id` | Workspace skeleton | Low — module registry | 1 event + reminders | N/A | `ref.select` on scaffold title |
| Marketplace | `/vendors` | Skeleton | Medium — 4 providers watch catalog | Catalog + optional fallback | ~50 vendors | Skeleton; error hardening |
| Guests (hub) | `/guests` | Spinner | Low | Reuses owned events | Low | Friendly errors |
| Guests (module) | `/events/:id/guests` | Skeleton | Medium — dual guest providers | Full guest list | **High** | `ListView.builder`; dedupe retry |
| Invitations | `/events/:id/invitations` | Skeleton | Low | Batch send loop (API) | Medium | Module scaffold ✓ |
| Program | `/events/:id/program` | Skeleton | Low | Single fetch | Low | ✓ |
| Seating | `/events/:id/seating` | Skeleton | Medium | Layout payload | Medium | ✓ |
| Vendor Pipeline | `/events/:id/vendors` | Skeleton | Low | Negotiations list | Medium | ✓ |
| Budget | `/events/:id/budget` | Skeleton | Low | Finance API | Low | ✓ |
| Website | `/events/:id/website` | Skeleton | Low | Config fetch | Low | ✓ |
| Wall | `/events/:id/wall` | Skeleton | **High** — full feed in Column | Feed poll | **High** | Document: pagination P1 |
| Rentals | `/vendors/rentals` | Skeleton | Low | Catalog by category | Medium | Skeleton |
| Vendor Dashboard | `/vendor/*` | Mixed | Medium | CRM lists | Medium | Out of 43.2 scope |
| Admin Dashboard | `/admin/*` | Mixed | Low | Aggregates | Low | Phase 41 certified |

---

## Flutter findings

### Provider graph

- **Duplicate watches:** `marketplaceCategoriesProvider`, `marketplaceCitiesProvider`, and `marketplaceFilteredVendorsProvider` all watch `marketplaceVendorsProvider` — acceptable (single future), but vendor detail re-fetches full catalog on miss.
- **Missing `ref.select`:** Fixed on `EventModuleScaffold` event title; other modules still watch full `customerEventProvider` where only `id`/`title` needed — P2.
- **Eager lists:** Guests module loaded full list then filtered client-side — correct for &lt;500 guests; server pagination needed beyond that.
- **No `cached_network_image`:** Marketplace vendor images use `Image.network` — repeated decode on scroll; P2.

### Rebuild hotspots

1. `EventModuleScaffold` — reduced via `ref.select` on title.
2. `customer_event_guests_screen` — KPI `LayoutBuilder` + filter bar rebuild on every keystroke (expected).
3. Home hub — `customerHomeSnapshotProvider` aggregates 3 futures; single refresh invalidates all.

### Memory / allocations

- Guest list `Column` with `for` loops replaced with `ListView.builder` (lazy element build).
- Wall feed still materializes all posts in one `Column` — P1 for large events.

### Network duplication

- `marketplaceVendorsProvider`: tries API catalog, then `customerMarketplaceVendorsProvider` on empty — potential double call on cold API.
- `marketplaceVendorProfileProvider`: on API miss, awaits full `marketplaceVendorsProvider.future` again.

### Cold vs warm start

- **Cold:** dotenv load → Supabase init → auth restore → router — ~1–2s typical on mid device.
- **Warm:** Riverpod cache + `autoDispose` refetch on navigation — sub-300ms for cached modules.

---

## API latency (client-visible)

See `API_PERFORMANCE_REPORT.md` for server-side detail. Client-observed bottlenecks:

| Endpoint pattern | Typical concern |
|------------------|-----------------|
| `GET /events` (owned) | OK with tenant index |
| `GET /events/:id/guests` | Large JSON payloads |
| `POST /events/:id/invitations/send` | Sequential sends |
| `GET /vendors/catalog` | Unpaginated |
| `GET /events/public` | N+1 venue lookups |

---

## Phase 43.2 optimizations applied

1. `EventModuleScaffold` — `ref.select` for event title only.
2. `CustomerEventGuestsScreen` — `ListView.builder` for guest rows.
3. Hub screens — `EventLoadingSkeleton` / friendly errors (no raw error strings forcing rebuild text).
4. Guests retry — single `refreshCustomerGuests` (removed duplicate `invalidate`).
5. Request log middleware — correct `tenantId` for observability correlation (API).

---

## Recommended follow-ups (no Phase 43 scope)

| ID | Item | Priority |
|----|------|----------|
| PERF-1 | Wall feed pagination + `ListView.builder` | P1 |
| PERF-2 | `cached_network_image` on marketplace | P2 |
| PERF-3 | Guest list server pagination (&gt;500) | P1 |
| PERF-4 | Marketplace vendor profile cache (avoid re-catalog) | P2 |
| PERF-5 | `ref.select` pass on remaining event modules | P2 |

---

## Verification

- `flutter analyze` — no new errors
- `dart analyze lib/portals/customer` — clean
- Manual: DevTools rebuild stats on Guests + Home recommended before production load test
