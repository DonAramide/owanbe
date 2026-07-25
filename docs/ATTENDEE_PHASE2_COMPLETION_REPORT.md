# ATTENDEE PHASE 2 — EVENT DISCOVERY COMPLETION REPORT

**Date:** 2026-07-24  
**Scope:** Attendee Discover marketplace (Phase 2 certification)  
**Constraint honored:** No redesign/rewrite of Search; reuse existing APIs/providers/Event OS; no parallel catalog stacks  
**Phase 3:** Not started

---

## Certification summary

| Status | Meaning |
|--------|---------|
| **PASS** | Feature present on Attendee Discover, wired to existing architecture, validated in code review + static analysis |
| **PARTIAL PASS** | Feature shipped with deterministic/heuristic or soft fallback; replaceable by stronger engine later |
| **FAIL** | Missing or broken |

**Phase 2 Discover result: COMPLETE with PARTIAL PASS on ranking/geo depth (architecture-ready).**

All checklist items are implemented on the Attendee Discover tab. Items marked PARTIAL PASS are intentional Phase 2 heuristics (replaceable), not missing UI.

---

## Checklist

| Feature | Result | Notes |
|---------|--------|-------|
| Featured Events | **PASS** | Rail on Discover; uses `isFeatured` from existing catalog |
| Upcoming Events | **PASS** | Paginated grid (“See more”); start-date sort |
| Trending Events | **PARTIAL PASS** | Heuristic engine on `ticketsSold` / engagement; swappable via `DiscoverRecommendationEngine` |
| Nearby Events | **PARTIAL PASS** | Haversine on exposed lat/lng + location bootstrap; soft fallback when coords sparse |
| Free Events | **PASS** | Rail from `ticketTiers.priceMinor == 0` |
| Paid Events | **PASS** | Rail from paid tiers |
| Search | **PASS** | Unchanged wiring: `EosSearchField` → `discoverQueryProvider` (predicate preserved) |
| Date Filter | **PASS** | Filters panel date From/To |
| Price Filter | **PASS** | Max price slider + Free/Paid toggles |
| Distance Filter | **PARTIAL PASS** | Requires location; filters by km when set |
| Category Filter | **PASS** | Existing chips kept + panel multi-select + Categories footer |
| Physical Filter | **PASS** | `venueType` exposed + Event type chips |
| Virtual Filter | **PASS** | Same |
| Hybrid Filter | **PASS** | Same |
| Personalized Suggestions | **PARTIAL PASS** | Interests/categories/recent/purchases heuristic |
| Similar Events | **PARTIAL PASS** | Category/organizer/city/tags heuristic from last viewed seed |
| Recently Viewed | **PASS** | SharedPreferences store; recorded on event detail open |
| Popular Near You | **PARTIAL PASS** | Nearby ∩ engagement ranking |

---

## What changed (architecture)

### Single catalog fetch (no duplicate list calls)

- `publicEventCatalogProvider` — one `GET /events` (or mock fallback)
- `discoverFilteredEventsProvider` / `publicEventsProvider` — client filter using search + chips + panel
- Section providers derive slices from the filtered catalog (lazy when watched)

### Model: stop stripping discovery fields

`PublicEvent` now includes:

- `venueType`
- `tags`
- `organizerId`
- `venueLatitude` / `venueLongitude`
- `ticketsSold`

Mapped in `mapPublicEvent` and `OrganizerEvent.toPublicEvent()`.

### Minimal backend extension

`EventsService.listPublic` attaches `ticketsSold` ≈ Σ(capacity − remaining) per event for trending heuristics. No new routes. No duplicate services.

### Recommendation layer (replaceable)

```
DiscoverRecommendationEngine (abstract)
  └─ HeuristicDiscoverRecommendationEngine (Phase 2)
```

Provider: `discoverRecommendationEngineProvider` — swap implementation later for AI without Discover UI rewrite.

### Recently viewed

`RecentlyViewedEventsStore` + `recordEventViewed` from `AttendeeEventDetailScreen`.

### Location

Platform-conditional `resolveDiscoverLocation()`:

- Web: Geolocation API (`discover_location_web.dart`)
- Other: Lagos CBD default (`discover_location_stub.dart`)

Bootstrapped on Discover tab open; refreshable in Filters → Use my location.

---

## Discover layout (live order)

1. Featured Events  
2. Search *(unchanged)*  
3. Filters chip + category chips  
4. Trending  
5. Upcoming (paginated grid)  
6. Free  
7. Paid  
8. Nearby  
9. Recommended for you  
10. Similar Events  
11. Recently Viewed  
12. Popular Near You  
13. Categories  

Empty rails hide themselves (`DiscoverEventRail` returns shrink when empty).

---

## Files touched / added

### Added

| File | Role |
|------|------|
| `mobile/lib/features/public/models/discover_filters.dart` | Filter model + apply + location types |
| `mobile/lib/features/public/data/discover_recommendation_engine.dart` | Heuristic recommendation engine |
| `mobile/lib/features/public/data/recently_viewed_events_store.dart` | View history persistence |
| `mobile/lib/features/public/data/discover_location.dart` | Location facade |
| `mobile/lib/features/public/data/discover_location_web.dart` | Web geolocation |
| `mobile/lib/features/public/data/discover_location_stub.dart` | Non-web default |
| `mobile/lib/features/public/widgets/discover_event_rail.dart` | Horizontal marketplace rails |
| `mobile/lib/features/public/widgets/discover_filters_sheet.dart` | Filters panel |
| `docs/ATTENDEE_PHASE2_COMPLETION_REPORT.md` | This report |

### Modified

| File | Role |
|------|------|
| `mobile/lib/portals/attendee/widgets/attendee_discover_tab.dart` | Marketplace UI |
| `mobile/lib/features/public/providers/public_providers.dart` | Catalog + section providers |
| `mobile/lib/features/public/models/public_models.dart` | Discovery fields |
| `mobile/lib/core/api/events_api.dart` | `mapPublicEvent` |
| `mobile/lib/features/organizer/models/organizer_models.dart` | `toPublicEvent` |
| `mobile/lib/portals/attendee/screens/attendee_event_detail_screen.dart` | Record view |
| `mobile/lib/features/home/providers/living_home_providers.dart` | Trending stub uses engine |
| `services/api/src/modules/events/events.service.ts` | `ticketsSold` on list |

---

## Providers (Discover)

| Provider | Purpose |
|----------|---------|
| `publicEventCatalogProvider` | Cached full list |
| `discoverQueryProvider` | Search text (unchanged) |
| `discoverCategoryProvider` | Category chips (unchanged) |
| `discoverFiltersProvider` | Panel filters |
| `discoverUserLocationProvider` | Lat/lng for distance/nearby |
| `discoverUpcomingPageSizeProvider` | Upcoming pagination |
| `discoverFeaturedEventsProvider` | Featured rail |
| `discoverTrendingEventsProvider` | Trending rail |
| `discoverUpcomingEventsProvider` | Upcoming grid page |
| `discoverFreeEventsProvider` / `discoverPaidEventsProvider` | Price rails |
| `discoverNearbyEventsProvider` | Nearby rail |
| `discoverPersonalizedEventsProvider` | Recommended |
| `discoverSimilarEventsProvider` | Similar |
| `discoverRecentlyViewedEventsProvider` | Recently viewed |
| `discoverPopularNearYouProvider` | Popular near you |
| `discoverRecommendationEngineProvider` | Engine DI |
| `recentlyViewedEventIdsProvider` | View IDs |
| `publicEventsProvider` | Compat for landing/tickets (same catalog) |

---

## API

| Endpoint | Change |
|----------|--------|
| `GET /events` | Unchanged params (`q`, `category`). Response items now include computed `ticketsSold` for list rows; `venueType` / coords already existed on `EventView` |
| `GET /events/:id` | Unchanged |

No new Nest controllers. No parallel discovery microservice.

---

## Regression guardrails

| Area | Status |
|------|--------|
| Search wiring | Preserved (`discoverQueryProvider`) |
| Event detail / ticket purchase routes | Unchanged paths; detail now records views only |
| Organizer / Vendor / Auth | Not modified for this sprint (except `toPublicEvent` field pass-through) |
| Public landing Featured | Still uses `publicEventsProvider` / `isFeatured` |
| Tickets tab Recommended | Still uses `publicEventsProvider` |

Static checks: Dart analyze on touched Discover files — no errors (1 pre-existing unused param warning in `events_api.dart`). API `tsc --noEmit` — pass.

---

## Live QA notes

1. Hard-refresh Flutter web after API reload so `ticketsSold` + `venueType` map correctly.  
2. Open an event detail once to populate **Recently Viewed** / improve **Similar**.  
3. Use **Filters → Use my location** (or auto-bootstrap) for Distance / Nearby ranking.  
4. If no events are marked featured / free, those rails hide — seed data or organizer flags may be needed for visual QA.  
5. Events without lat/lng still appear in Nearby soft-fallback (upcoming order) until organizers save venue coordinates.

---

## Phase 2 declaration

**Attendee Phase 2 Event Discovery is COMPLETE for certification**, with PARTIAL PASS on trending/personalized/similar/nearby/popular/distance where deterministic heuristics or geo data density apply.

These PARTIAL items are **architecture-ready** for a future AI / analytics engine via `DiscoverRecommendationEngine` and existing `EventView` geo fields — not deferred UI.

**Do not begin Phase 3 until product accepts this certification.**
