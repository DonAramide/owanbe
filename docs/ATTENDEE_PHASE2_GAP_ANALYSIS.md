# ATTENDEE PHASE 2 – DISCOVERY GAP ANALYSIS

**Date:** 2026-07-24  
**Scope:** Live QA of Attendee Discover / Browse Events vs planned Phase 2 experience  
**Codebase:** Flutter `mobile/`, Nest `services/api/`  
**Method:** Evidence-only gap analysis — **no code was written for this report**

---

## Executive verdict

The Attendee Discover tab is a **single flat catalog**: search + category chips + one event grid. It is **not** a merchandised discovery feed with rails, advanced filters, or recommendations.

Most Phase 2 gaps are **not hidden**. They are **absent from the Discover UI**, and in most cases **absent from the public events API**. Partial building blocks exist elsewhere (`isFeatured`, `venueType`, lat/long on the server; Featured on the public landing page; a heuristic “Recommended for you” on the Tickets tab).

| Area | Live QA | Root cause (one line) |
|------|---------|------------------------|
| Upcoming Events | ✓ | Flat list ordered by `starts_at` — behaves as upcoming catalog |
| Featured / Trending / Nearby / Free / Paid rails | ✗ | No section UI on Discover; most lack dedicated APIs |
| Search | ✓ | Wired end-to-end (`q` + category) |
| Filters panel (date/price/distance/venue type…) | ✗ | Only category chips exist; no filter sheet/providers |
| Recommendations | ✗ | No recommendation service; no Discover rails |

---

## Classification legend

| Code | Meaning |
|------|---------|
| **Hidden** | Implemented and present in this surface but obscured / conditional |
| **Not wired** | Exists in codebase but not connected to Attendee Discover UI |
| **BE ready / FE missing** | Backend (or server model) has the data; Flutter Discover does not use it |
| **FE ready / BE missing** | UI pattern exists elsewhere; no event discovery backend |
| **Not implemented** | No meaningful product implementation for this feature |

---

## 1. What Discover renders today

### Primary surface (live QA target)

| Item | Evidence |
|------|----------|
| Shell | `AttendeeDashboardScreen` — Discover is tab index 0 |
| Widget | `mobile/lib/portals/attendee/widgets/attendee_discover_tab.dart` |
| Title | “Discover events” |
| Search | `EosSearchField` → `discoverQueryProvider` |
| “Filters” | Horizontal `FilterChip` list from `eventCategoriesProvider` only |
| Catalog | Single `PublicEventGrid` over `publicEventsProvider` |
| Navigation | Tap → `AttendeeRoutes.eventDetail(id)` |

**Not rendered on Discover:** section headers/rails for Featured, Trending, Nearby, Free, Paid; date/price/distance/venue-type controls; recommendation blocks; map.

### Parallel surfaces (not Attendee Discover)

| Surface | Path | Relevance |
|---------|------|-----------|
| Public Discover | `DiscoverScreen` (`/events`) | Same providers/grid as attendee tab |
| Public Landing | `LandingScreen` | **Featured events** section (`isFeatured`, take 2) |
| Tickets tab | `AttendeeTicketsTab` | Heuristic **Recommended for you** (not Discover) |

### Data flow

```
AttendeeDiscoverTab
  → discoverQueryProvider + discoverCategoryProvider
  → publicEventsProvider
  → EventsApi.listPublicEvents(query, category)
  → GET /v1/events?q=&category=
  → EventsService.listPublic
```

**Providers involved (Discover):**

- `discoverQueryProvider` — `StateProvider<String>`
- `discoverCategoryProvider` — `StateProvider<String>`
- `publicEventsProvider` — `FutureProvider` (list)
- `eventCategoriesProvider` — `FutureProvider` (chip labels)
- `eventsApiProvider` — HTTP client

**Files:**

- `mobile/lib/portals/attendee/widgets/attendee_discover_tab.dart`
- `mobile/lib/features/public/providers/public_providers.dart`
- `mobile/lib/core/api/events_api.dart`
- `mobile/lib/features/public/widgets/public_event_grid.dart`
- `mobile/lib/features/public/models/public_models.dart`
- `services/api/src/modules/events/events.controller.ts`
- `services/api/src/modules/events/events.service.ts`

**API (only list params today):**

- `GET /events` — query: `q`, `category` only  
- `GET /events/:eventId` — detail

---

## 2. Browse Events rails

### 2.1 Upcoming Events — ✓ Working

| Field | Detail |
|-------|--------|
| **Classification** | Implemented (as default catalog), not a named “Upcoming” rail |
| **Why it appears** | `EventsService.listPublic` selects published/live/completed and `ORDER BY starts_at ASC`. The Discover grid shows that list. QA’s “Upcoming” maps to this flat catalog. |
| **Evidence** | `events.service.ts` `listPublic`; `AttendeeDiscoverTab` → `PublicEventGrid` |
| **Enable effort** | N/A (already live). A labeled “Upcoming” section would be **small UI** (client slice by `startsAt` / status). |

---

### 2.2 Featured Events — ✗ Missing on Discover

| Field | Detail |
|-------|--------|
| **Classification** | **Not wired** into Attendee Discover + **partially implemented** elsewhere |
| **Why absent** | Discover never filters/slices `isFeatured`. There is no “Featured” section widget on the tab. |
| **What exists** | Server: `EventView.isFeatured` from metadata. Flutter: `PublicEvent.isFeatured` mapped in `mapPublicEvent`. Card badge in `public_event_grid.dart`. Landing: `LandingScreen` “Featured events” (`where isFeatured take 2`). Tickets: recommended includes featured. |
| **Providers** | Same `publicEventsProvider` — no `featuredEventsProvider` |
| **API** | No `?featured=true`; flag is on each list item |
| **Enable effort** | **Small UI integration** — mirror `landing_screen.dart` section on `AttendeeDiscoverTab` using existing list + `isFeatured` |

---

### 2.3 Trending Events — ✗ Missing

| Field | Detail |
|-------|--------|
| **Classification** | **Not wired** stub + **not implemented** as real trending |
| **Why absent** | No Discover UI. Only dead stub: `livingHomeTrendingEventsProvider` returns first 4 public event **titles** — **zero UI references** after home redesign. |
| **What exists** | Stub provider in `living_home_providers.dart`. `ticketsSold` may exist on server `EventView` but is not a ranking API. Home redesign docs removed hub carousels. |
| **API** | None for trending |
| **Enable effort** | **Small UI** if “trending” = arbitrary slice/sort of existing list. **Large** if real popularity (metrics pipeline + `GET /events/trending` or sort by sales/views). |

---

### 2.4 Nearby Events — ✗ Missing

| Field | Detail |
|-------|--------|
| **Classification** | **BE ready (fields) / FE missing** → overall **not implemented** as Nearby product |
| **Why absent** | No device location in Discover; no distance UI; public Flutter model omits coordinates. |
| **What exists** | Server `EventView.venueLatitude` / `venueLongitude` (metadata). Organizer Flutter maps lat/long (`mapOrganizerEvent`). `mapPublicEvent` / `PublicEvent` **do not** include them. |
| **Providers** | None for nearby/geo |
| **API** | No geo query / radius filter on `GET /events` |
| **Enable effort** | **Large** — expose coords on `PublicEvent`, location permission, distance sort/filter, ideally server bounding-box/radius |

---

### 2.5 Free Events — ✗ Missing

| Field | Detail |
|-------|--------|
| **Classification** | **Not implemented** (as rail or filter); price data exists |
| **Why absent** | No Free section and no free/paid filter. Price only used for “From ₦…” on cards via `cheapestTier()`. |
| **What exists** | `TicketTier.priceMinor` on each `PublicEvent` from `GET /events` |
| **API** | No `?price=free` / `maxPrice` |
| **Enable effort** | **Small UI** — client filter `cheapestTier()?.priceMinor == 0` + section or chip. **Medium** if server-side filter for scale. |

---

### 2.6 Paid Events — ✗ Missing

| Field | Detail |
|-------|--------|
| **Classification** | **Not implemented** (same as Free) |
| **Why absent** | Inverse of Free; nothing in Discover UI |
| **Enable effort** | **Small UI** (client filter `priceMinor > 0`) |

---

## 3. Search (working — context)

Live QA: name, organizer, category, location, tags — reported working.

| Field | Detail |
|-------|--------|
| **Classification** | **Implemented** for text + category path |
| **Wiring** | `discoverQueryProvider` → `EventsApi.listPublicEvents` → `GET /events?q=` |
| **Server filter** | `listPublic` matches **title, city, category only** (case-insensitive substring) |
| **Code vs QA note** | Tags exist on server `EventView.tags` but are **not** included in the `q` filter, and **not** mapped onto `PublicEvent`. Organizer is only `organizerId` — **no organizer display-name search**. Location maps to **city** (and venue is not in the `q` filter). If live QA saw organizer/tag hits, they likely matched title/city/category text, not dedicated fields. |
| **Files** | `attendee_discover_tab.dart`, `public_providers.dart`, `events_api.dart`, `events.service.ts` |

---

## 4. Filters

Live QA expected a visible filter set. Discover only shows **category chips**. There is **no** filter sheet, filter bar, or filter state model for events.

### 4.1 Date — ✗

| Field | Detail |
|-------|--------|
| **Classification** | **Not implemented** |
| **Evidence** | No date providers; `GET /events` has no `startsAfter` / `startsBefore` |
| **Enable effort** | **Medium** — UI date range + API query params (or client filter on full list for small catalogs) |

### 4.2 Price — ✗

| Field | Detail |
|-------|--------|
| **Classification** | **Not implemented** for events |
| **Near-miss** | Vendor marketplace has `MarketplaceFilters.maxPriceMinor` (`marketplace_filters.dart`) — **vendors only**, not events |
| **Enable effort** | **Medium** — mirror marketplace filter UX against tier prices |

### 4.3 Distance — ✗

| Field | Detail |
|-------|--------|
| **Classification** | **Not implemented** (blocked by same geo gap as Nearby) |
| **Enable effort** | **Large** (with Nearby) |

### 4.4 Category — live QA ✗ under Filters; code has chips

| Field | Detail |
|-------|--------|
| **Classification** | **Already implemented** as Discover chips — **not** as a Filters panel control |
| **Why QA marks missing** | Product checklist expects a Filters group; UX only exposes horizontal category chips (also covered under Search/category). |
| **Evidence** | `FilterChip` + `discoverCategoryProvider` + `?category=` |
| **Enable effort** | **Small** if only packaging chips into a “Filters” sheet; already functional |

### 4.5 Physical / Virtual / Hybrid — ✗

| Field | Detail |
|-------|--------|
| **Classification** | **BE ready / FE missing** |
| **Why absent** | Server returns `venueType` on `EventView`. Organizer models map it. `PublicEvent` / `mapPublicEvent` **strip** it. No Discover chips. |
| **Source of truth** | Organizer create metadata (`venueType`); defaults to `'physical'` in `mapEvent` |
| **API** | Present on list JSON; no `?venueType=` filter |
| **Enable effort** | **Small–Medium** — add field to `PublicEvent` + chips/client filter; optional query param |

---

## 5. Recommendations

None appear on the Discover tab. Closest related UX is on **Tickets**, not Discover.

### 5.1 Personalized Suggestions — ✗

| Field | Detail |
|-------|--------|
| **Classification** | **Not implemented** |
| **Near-miss** | Tickets tab label “Recommended for you” = `publicEventsProvider` filtered `isFeatured \|\| status == upcoming`, take 4 — **not** profile/interest personalization |
| **Docs** | `ATTENDEE_WORKSPACE_COMPLETION_REPORT.md` documents that heuristic |
| **API** | No attendee recommendation endpoint. Platform `ai_recommendations` (if present) is admin/copilot, not Discover rails |
| **Enable effort** | **Large** — rules/ML using attendee profile interests + history |

### 5.2 Similar Events — ✗

| Field | Detail |
|-------|--------|
| **Classification** | **Not implemented** |
| **Evidence** | No similar-events UI on Discover or event detail; no API |
| **Enable effort** | **Large** — similarity by category/tags + endpoint or detail-page section |

### 5.3 Recently Viewed — ✗

| Field | Detail |
|-------|--------|
| **Classification** | **Not implemented** |
| **Near-miss** | Tickets “Recent activity” = ticket/check-in feed, **not** browse history |
| **Evidence** | No SharedPreferences / API for viewed event IDs in attendee Discover path |
| **Enable effort** | **Medium** — local persistence + rail; sync optional |

### 5.4 Popular Near You — ✗

| Field | Detail |
|-------|--------|
| **Classification** | **Not implemented** |
| **Depends on** | Nearby geo + popularity signal (neither productized for Discover) |
| **Enable effort** | **Large** |

---

## 6. Feature matrix (Phase 2 checklist)

| Feature | Live | Classification | Effort to enable |
|---------|------|----------------|------------------|
| Upcoming Events | ✓ | Implemented as default list | — |
| Featured Events | ✗ | Not wired (data + landing exist) | Small UI |
| Trending Events | ✗ | Stub unused / not real trending | Small (fake) / Large (real) |
| Nearby Events | ✗ | BE coords; FE + API product missing | Large |
| Free Events | ✗ | Not implemented (tier prices exist) | Small UI |
| Paid Events | ✗ | Not implemented | Small UI |
| Search (name/city/category) | ✓ | Implemented | — |
| Filter: Date | ✗ | Not implemented | Medium |
| Filter: Price | ✗ | Not implemented (vendor pattern only) | Medium |
| Filter: Distance | ✗ | Not implemented | Large |
| Filter: Category | Chips ✓ / Panel ✗ | Implemented as chips, not Filters panel | Small packaging |
| Filter: Physical/Virtual/Hybrid | ✗ | BE ready / FE missing | Small–Medium |
| Personalized Suggestions | ✗ | Not implemented | Large |
| Similar Events | ✗ | Not implemented | Large |
| Recently Viewed | ✗ | Not implemented | Medium |
| Popular Near You | ✗ | Not implemented | Large |

---

## 7. Why this happened (architecture)

1. **Phase 1 Discover charter was minimal.** Workspace completion docs describe Discover as “search, filters, event grid” — implemented as search + **category chips** + grid, not Phase 2 rails.
2. **One list API.** `GET /events` only accepts `q` and `category`. No featured/trending/nearby/recommendation endpoints.
3. **Public DTO is thinner than server `EventView`.** `mapPublicEvent` drops `venueType`, tags, lat/long — so FE cannot filter on fields the API already returns without remapping.
4. **Merchandising lives elsewhere.** Featured on landing; “Recommended” heuristic on Tickets; trending provider abandoned after hub redesign.
5. **Marketplace filter UX was built for vendors**, not events — so date/price/distance patterns were never ported to Discover.

---

## 8. Effort buckets (if Phase 2 is scheduled)

### Quick wins (small UI + existing `GET /events`)

1. Featured rail on `AttendeeDiscoverTab` (`isFeatured`)
2. Free / Paid chips or sections (client tier price)
3. Optional labeled Upcoming section (by `startsAt`)
4. Map `venueType` (+ tags if desired) into `PublicEvent` + Physical/Virtual/Hybrid chips
5. Optionally surface category chips inside a labeled “Filters” sheet (packaging)

### Medium

1. Extend `GET /events` with date range, price band, `venueType`, `featured`
2. Recently Viewed (local storage + Discover rail)
3. Real “Trending” sort if `ticketsSold` (or views) is exposed and trusted

### Large

1. Nearby / Distance / Popular Near You (geo + privacy + query)
2. Personalized Suggestions + Similar Events (signals + API + UI)

---

## 9. File & symbol index

### Attendee Discover UI

| File | Symbols |
|------|---------|
| `mobile/lib/portals/attendee/widgets/attendee_discover_tab.dart` | `AttendeeDiscoverTab` |
| `mobile/lib/features/public/screens/attendee_dashboard_screen.dart` | Discover tab host |
| `mobile/lib/features/public/screens/discover_screen.dart` | Public twin of Discover |
| `mobile/lib/features/public/widgets/public_event_grid.dart` | `PublicEventGrid`, FEATURED badge |
| `mobile/lib/features/public/screens/landing_screen.dart` | Featured events section |
| `mobile/lib/portals/attendee/widgets/attendee_tickets_tab.dart` | Heuristic “Recommended for you” |

### Providers / models / API client

| File | Symbols |
|------|---------|
| `mobile/lib/features/public/providers/public_providers.dart` | `discoverQueryProvider`, `discoverCategoryProvider`, `publicEventsProvider`, `eventCategoriesProvider` |
| `mobile/lib/features/home/providers/living_home_providers.dart` | `livingHomeTrendingEventsProvider` (**unused**) |
| `mobile/lib/features/public/models/public_models.dart` | `PublicEvent` (no venueType/geo/tags) |
| `mobile/lib/core/api/events_api.dart` | `listPublicEvents`, `mapPublicEvent` |
| `mobile/lib/portals/customer/models/marketplace_filters.dart` | Vendor filter reference only |

### Backend

| File | Symbols |
|------|---------|
| `services/api/src/modules/events/events.controller.ts` | `GET events` (`q`, `category`) |
| `services/api/src/modules/events/events.service.ts` | `EventView`, `listPublic`, `isFeatured`, `venueType`, lat/long, tags |

### Docs that shaped current Discover (not Phase 2 rails)

| Doc | Claim |
|-----|-------|
| `docs/ATTENDEE_WORKSPACE_COMPLETION_REPORT.md` | Discover = search, filters, grid; recommendations = featured/upcoming heuristic on Tickets |
| `docs/ATTENDEE_EVENT_NAVIGATION_COMPLETION_REPORT.md` | In-shell Discover tab |
| `docs/WORKSPACE_EXPERIENCE_REDESIGN_REPORT.md` | Removed hub trending carousels |

---

## 10. Bottom line

Phase 2 Discovery features are missing from the Attendee Discover page primarily because **they were never built into that page**. The live screen correctly implements a **Phase 1 catalog browser**. Featured and venue-type data already exist deeper in the stack but are **not merchandised or filterable on Discover**. Trending, nearby, advanced filters, and true recommendations require **new UI at minimum**, and for geo/personalization **new product surface area on the API**.

No implementation was performed as part of this analysis.
