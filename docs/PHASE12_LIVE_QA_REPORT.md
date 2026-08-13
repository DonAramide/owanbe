# PHASE 12 — LIVE QA REPORT  
## Event Creation & Configuration

**Date:** 2026-07-27  
**Reference:** `docs/PHASE12_EVENT_CREATION_COMPLETION_REPORT.md`  
**Environment:** Windows 10 · Nest API `http://127.0.0.1:8080/v1` (health `http://127.0.0.1:8080/health` → **200**) · Flutter `flutter run` (Chrome, API `http://127.0.0.1:8080/v1`) · Tenant `11111111-1111-4111-8111-111111111111`

**Validation method:** Live API probes (`scripts/phase12_live_qa.mjs`) + source-path verification. **No Flutter UI automation** in this session; visual checks marked **OPERATOR REQUIRED** where applicable.

---

## Test identity

| Field | Value |
|-------|--------|
| Organizer user | `akwajadaniel875@gmail.com` · `eb061885-7854-41db-b390-3a2b62eaeef5` |
| Organizer record | `5681adac-409b-4ba9-85a6-4ae3e5d86b0e` |
| `GET /organizers/me` | **200** |

---

## SECTION 1 — CREATE EVENT

| Check | Result | Evidence |
|-------|--------|----------|
| Create Event launches Wizard V2 | **PASS** (wired) | `customer_create_event_screen.dart` → `EventCreateWizardV2Screen`; route `/organizer/events/new` |
| Wizard opens correctly | **OPERATOR REQUIRED** | Active `flutter run` on Chrome; hot restart (**R**) after Phase 12 bundle |
| No crashes | **OPERATOR REQUIRED** | `dart analyze` on wizard/readiness paths: **0 errors** (5 info hints) |
| Validation behaves correctly | **PASS** (wired) | `_next` / `_saveAndOpen` snackbars for category, title, end>start, venue, services, public tickets |

**Section result: PASS** (visual confirmation pending operator)

---

## SECTION 2 — DRAFT

| Check | Result | Evidence |
|-------|--------|----------|
| Draft created | **PASS** | `POST /events` → **201**; mid-wizard `_maybeAutosaveServer` → `createEventFromV2Draft` after title set |
| Resume draft | **PARTIAL PASS** | Local resume dialog on wizard open (`loadLocal` + `Resume draft?`); **server event id not stored in SharedPreferences** → after browser refresh resume is local-only; `_serverEventId` not restored → risk of second `POST` on continue |
| Discard draft | **PARTIAL PASS** | `_discard` clears local autosave + navigates away; **does not delete** server draft if `_serverEventId` already created |
| Cancel behaviour | **PASS** (wired) | `PopScope` + close → discard confirmation |
| Draft visible on Dashboard | **PASS** | `GET /organizers/me/events?status=draft` **200** includes Phase 12 probe draft; dashboard KPI `draftEvents` present |

**Section result: PARTIAL PASS**

---

## SECTION 3 — AUTOSAVE

| Check | Result | Evidence |
|-------|--------|----------|
| Autosave triggers | **PASS** (wired) | `persistLocal` debounced 600ms; app bar “Draft saved” / “Saving…” |
| PATCH persists | **PASS** (API) | `PATCH /events/:id` **200** — title + `endsAt` updated on probe event `6f9eb365-…` |
| Refresh browser | **PARTIAL PASS** | Local JSON persists fields in `draftToJson`; **server id binding lost** (see Section 2) |
| Continue editing | **PASS** (local) | Resume dialog restores draft fields via `_applySeed` |
| No data loss | **PARTIAL PASS** | Local path OK; **PATCH body (`v2DraftToApiBody`) omits `ticketTiers`** — tiers only on initial `POST` in `createEventFromV2Draft`; mid-wizard server sync does not persist ticket edits until final create |

**Section result: PARTIAL PASS**

---

## SECTION 4 — EVENT DETAILS

| Check | Result | Evidence |
|-------|--------|----------|
| Title | **PASS** | Details step + validation |
| Description | **PASS** | `_description` in draft + API body |
| Category | **PASS** | Celebrate step + `eventCategoriesProvider` |
| Tags | **PASS** | `eventTagsProvider` chips on Details |
| Language | **PASS** | `_language` → metadata |
| Age restriction | **PASS** | `_ageMin` → `ageRestrictionMin` |
| Venue | **PASS** | Venue step + deferred mode |
| Visibility | **PASS** | Chips: invite only / public / hidden → `listingVisibility` + access mode |

**Section result: PASS** (operator UI confirmation recommended)

---

## SECTION 5 — DATES

| Check | Result | Evidence |
|-------|--------|----------|
| Start date | **PASS** | `_pickDateTime(isEnd: false)` |
| End date | **PASS** | `_pickDateTime(isEnd: true)` |
| Multi-day | **PASS** (API) | Probe used 45d start / 47d end; PATCH extended end to +50d |
| Validation | **PASS** | End must be after start on Continue / Create |
| No fixed +6 hour bug | **PARTIAL PASS** | End is user-selectable; **+6h only applied when start changes and end ≤ start** (helper, not forced on end-only edit). Default initial end still +6h from start |

**Section result: PASS** (accepted helper behaviour)

---

## SECTION 6 — BRANDING

| Check | Result | Evidence |
|-------|--------|----------|
| Banner | **PASS** | `bannerLabel` text field |
| Logo | **PARTIAL PASS** | No separate logo asset — **celebrant image picker** used as cover MVP |
| Theme colour | **PASS** | `EosSelectField` → `themeColor` in API metadata |
| Preview | **PASS** | Review step summary card + readiness list |

**Section result: PARTIAL PASS** (logo scope = celebrant cover per sprint MVP)

---

## SECTION 7 — TICKETS (public event)

| Check | Result | Evidence |
|-------|--------|----------|
| Ticket step appears | **PASS** (wired) | `_stepLabels` adds `Tickets` when `publicTicketed` |
| Ticket creation works | **PASS** (API) | `POST /events` with `ticketTiers` → tier **General** on event `c1d2fa15-…` |
| Tier persists | **PASS** (API) | `GET /events/:id/manage` returns tier after create |
| Ready checklist updates | **PASS** (wired) | `evaluateEventPublishReadiness` tickets item; workspace panel maps `event.ticketTiers` |

**Section result: PASS**

---

## SECTION 8 — PRIVATE EVENT

| Check | Result | Evidence |
|-------|--------|----------|
| Ticket step not required | **PASS** (wired) | No Tickets step when not `publicTicketed`; readiness tickets item non-blocking |
| Publish rules correct | **PASS** (API) | `POST /events/:id/publish` on private draft **201** `status=published` without tiers |

**Section result: PASS**

---

## SECTION 9 — READINESS CHECKLIST (Event Workspace)

| Check | Result | Evidence |
|-------|--------|----------|
| Checklist appears | **PASS** (wired) | `EventCreationReadinessPanel` on `EventDesktop` Overview |
| Missing items highlighted | **PASS** (wired) | Unchecked icons for incomplete items |
| Deep-links work | **PASS** (wired) | Primary CTA → `openTicketsManage` / `openOverview` |
| Progress updates immediately | **OPERATOR REQUIRED** | Panel rebuilds from `snapshot`; no live UI tap test |
| Completed items disappear/update | **PARTIAL PASS** | Items stay listed with checkmarks when done (not removed) — by design |
| `?focus=readiness` | **FAIL** (minor) | Navigation sets query param; **no handler** found to scroll/focus checklist |

**Section result: PARTIAL PASS**

---

## SECTION 10 — PUBLISH GATES

| Check | Result | Evidence |
|-------|--------|----------|
| Cannot publish public without tiers | **PASS** | `POST /publish` → **422** `code=TICKETS_REQUIRED` |
| Cannot publish without title | **PASS** (wired) | `INVALID_TITLE` in `events.service.ts` `publish()` |
| Validation messages | **PASS** (API) | Actionable `message` on 422 body |
| Public with tiers publishes | **PASS** | `POST /publish` → **201** `status=published` on tiered public event |

**Section result: PASS**

---

## SECTION 11 — TEMPLATES & DUPLICATE

| Check | Result | Evidence |
|-------|--------|----------|
| Template hydration | **PASS** (wired) | `buildTemplateDraft` — category, tiers, services, description, visibility |
| Duplicate hydration | **PARTIAL PASS** | `buildDuplicateDraftFromOrganizerEvent` — category, tiers, dates, branding URL, access; **missing `requiredServices`, registration/check-in, tags, budget allocation** from source event |
| Tickets on duplicate | **PASS** (wired) | Tiers copied with reset `remaining` |

**Section result: PARTIAL PASS**

---

## SECTION 12 — REGRESSION

| Area | Result | Evidence |
|------|--------|----------|
| Dashboard | **PASS** | `GET /organizers/me/dashboard` **200** |
| Workspace / Events APIs | **PASS** | `GET /organizers/me/events` **200** |
| Command Center / create route | **PASS** (wired) | Wizard route unchanged |
| Tickets module | **PASS** (API) | Tier insert on create; manage returns tiers |
| Drafts | **PASS** | Draft list includes new probes |
| Portfolio | **PASS** (wired) | Template catalog unchanged |

**Section result: PASS**

---

## Issue summary

### Critical

None observed in API layer for publish safety or auth.

### High

| ID | Issue | Sections |
|----|--------|----------|
| H1 | Wizard discard / back does not delete server draft created by mid-flow autosave | 2 |
| H2 | Local autosave does not persist `serverEventId` — browser refresh can orphan or duplicate server drafts | 2, 3 |
| H3 | `v2DraftToApiBody` / PATCH does not send `ticketTiers` — server autosave cannot sync tiers until final submit | 3, 7 |

### Medium

| ID | Issue | Sections |
|----|--------|----------|
| M1 | `?focus=readiness` query not wired to UI focus | 9 |
| M2 | Duplicate draft omits several fields from source event | 11 |
| M3 | API `EventView` responses do not surface metadata fields (e.g. `themeColor`) on manage/list — storage may still be correct in DB | 4, 6 |

### Low

| ID | Issue | Sections |
|----|--------|----------|
| L1 | Separate “logo” upload not implemented (celebrant cover only) | 6 |
| L2 | Demo map / Places still placeholder (documented deferral) | 4 |
| L3 | Analyzer info hints (null-aware, unused import) | 1 |

---

## Certification recommendation

### ⚠️ PHASE 12 — **FAIL** (not certified)

**Rationale:** Publish gates, public/private rules, ticket create, PATCH for core fields, and workspace checklist wiring **PASS** live API and static review. **P1 autosave / draft lifecycle** (Sections 2–3) **PARTIAL PASS** with **High** defects (H1–H3) that contradict “production-ready” autosave and can create duplicate or orphan drafts. **Section 9** lacks operator confirmation and has dead `focus=readiness`.

**Path to certify**

1. Operator: hot restart Flutter, walk completion report QA checklist (visual).
2. Product/engineering: address H1–H3 (or accept explicit “single-session wizard only” product waiver).
3. Re-run `node scripts/phase12_live_qa.mjs` + UI smoke.

**Accepted partials (if waiving H1–H3 for a time-boxed release):** celebrant-as-logo MVP, +6h start-adjust helper, checklist items remain visible when complete, scheduled publish deferred.

---

## STOP

Do not begin Phase 13. Re-certify Phase 12 after remediation or signed waiver on H1–H3.
