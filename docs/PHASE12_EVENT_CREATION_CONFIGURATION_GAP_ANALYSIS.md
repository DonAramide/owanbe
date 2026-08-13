# PHASE 12 — EVENT CREATION & CONFIGURATION GAP ANALYSIS

**Date:** 2026-07-27  
**Scope:** Organizer Event Creation & Configuration — from **Create Event** through **ready to publish**  
**Method:** Read-only audit of Flutter (`mobile/`) and NestJS (`services/api/`) + DB (`infra/db/`)  
**Constraint:** Audit only — no code changes, no redesign, no fixes  

---

## Executive verdict

| Dimension | Finding |
|-----------|---------|
| **Live create path** | Wizard V2 at `/organizer/events/new` and `/events/create` → `POST /events` as **draft** → Event Workspace |
| **Publish** | Separate post-create action (`POST /events/:id/publish`) from Command Center / Events list — **not** inside the wizard |
| **Config depth in create** | Strong on category, title, start, venue modes, budget, services; weak on branding, visibility, tickets-in-wizard, end time, autosave |
| **Backend create/patch** | Working with rich `metadata` allowlist; thin validation; no scheduled publish / timezone / age / language |
| **Overall classification** | **Partially implemented** |

Create → draft → open workspace is production-usable. Configuration that makes an event “ready to publish” is split across the wizard and the Event Workspace; several create-time expectations (templates seed completeness, ticket tiers for public events, branding, preview, autosave) are incomplete or unwired.

---

## Classification legend

| Label | Meaning |
|-------|---------|
| **Implemented and Working** | End-to-end usable on the live create / publish path |
| **Implemented but Hidden** | Built; not reachable via current routing |
| **Implemented but Not Wired** | UI or API/provider exists; not connected |
| **Backend Complete / Frontend Missing** | API/DB ready; insufficient create UX |
| **Frontend Complete / Backend Missing** | UI present; API synthetic/stubbed/absent |
| **Partially Implemented** | Meaningful pieces; gaps block Phase 12 completeness |
| **Not Implemented** | No meaningful product implementation |

---

## Architecture map (reusable building blocks)

### Flutter

| Asset | Path | Role |
|-------|------|------|
| Live wizard | `features/organizer/wizard_v2/event_create_wizard_v2_screen.dart` | 5-step create |
| Wizard widgets | `wizard_v2/widgets/*` | Venue, budget, services, celebrant, unused vendor picker |
| Customer entry | `portals/customer/screens/customer_create_event_screen.dart` | Thin wrapper → V2 |
| Legacy wizard | `features/organizer/screens/event_create_wizard_screen.dart` | Orphaned (tickets/media/tags) |
| Persistence | `features/organizer/data/organizer_persistence.dart` | `createEventFromV2Draft`, `publishEvent` |
| Models | `features/organizer/models/organizer_models.dart` | `EventWizardV2Draft` |
| Seed / duplicate | `portals/customer/closing/event_closing_actions.dart` | `eventDuplicateSeedProvider` |
| Local templates | `portals/customer/portfolio/event_template_catalog.dart` | `buildTemplateDraft` |
| Template / duplicate pickers | `features/organizer/widgets/organizer_command_center.dart` | Dashboard entry |
| Config providers | `features/organizer/providers/event_config_providers.dart` | Categories (used); tags/templates (unused) |
| Routes | `router/app_router.dart`, `event_route_registry.dart` | `/organizer/events/new`, `/events/create` |

### Nest / DB

| Asset | Path | Role |
|-------|------|------|
| Events API | `events.controller.ts` / `events.service.ts` | `POST/PATCH`, publish, go-live |
| Metadata | `buildMetadata` in `events.service.ts` | Venue, branding keys, access mode, budget, etc. |
| Tiers | `event-tiers.service.ts` | Post-create CRUD; inline create for public |
| Config | `event-config.service.ts` | Categories, tags, templates, budget templates |
| Tables | `events` (`016_…`), tiers (`020_…`), config (`027_…`), websites (`028_…`) | Persistence |

---

## 12.1 Event Creation

| Feature | Classification | Evidence | Why available / not | Effort |
|---------|----------------|----------|---------------------|--------|
| Create Event button | **Implemented and Working** | Dashboard, Events, quick actions, home → `/organizer/events/new` or `/events/create` | Live CTAs | — |
| Create Event Wizard (V2) | **Implemented and Working** | 5 steps: Celebrate → Details → Venue → Budget → Services | Primary path | — |
| Quick Create | **Not Implemented** | No single-field / express create | Only full wizard | Medium |
| Draft creation | **Implemented and Working** | `POST /events` always inserts `status='draft'`; FE `createEventFromV2Draft` | By design | — |
| Autosave | **Not Implemented** | Wizard holds local state only until final save; no mid-flow `PATCH` callers in Flutter | `PATCH /events/:id` exists unused for create flow | Medium |
| Resume draft | **Partially Implemented** | Resume unpublished events from Dashboard / Events; **not** resume mid-wizard session | After create only | Medium |
| Validation | **Partially Implemented** | FE: category, title, venue/city, ≥1 service; BE: title only | Thin BE; soft budget warnings | Medium |
| Cancel / discard | **Not Implemented** | No discard confirm / PopScope on V2 (legacy had exit to `/organizer`) | Easy data loss | Small |

**12.1 sub-verdict:** **Partially implemented**.

---

## 12.2 Basic Information

| Feature | Classification | Evidence | Why | Effort |
|---------|----------------|----------|-----|--------|
| Event name | **Implemented and Working** | V2 Details step → `title` | Required | — |
| Slug | **Backend Complete / Frontend Missing** | Server `slugify(title)` + `uniqueSlug`; no FE edit | Auto-generated; immutable on patch | Small |
| Description | **Backend Complete / Frontend Missing** | BE `metadata.description`; V2 has no description field (legacy wizard did) | Dropped in V2 | Small |
| Category | **Implemented and Working** | Celebrate step + `eventCategoriesProvider` / fallback | Seeds from `event-config` | — |
| Event type / access mode | **Partially Implemented** | Derived from category → `PRIVATE_INVITATION` \| `PUBLIC_TICKETED`; no explicit type step | Implicit | Small |
| Tags | **Backend Complete / Frontend Missing** | `eventTagsProvider` + BE tags; V2 sends `tags: []` usually | Provider unused | Small |
| Language | **Not Implemented** | No metadata key / UI | — | Small |
| Age restriction | **Not Implemented** | No field / API | — | Small–Medium |
| Organizer details | **Partially Implemented** | BE allowlist `organizerName` / contact email/phone; not collected in V2 | Profile exists separately | Medium |

**12.2 sub-verdict:** **Partially implemented**.

---

## 12.3 Date & Time

| Feature | Classification | Evidence | Why | Effort |
|---------|----------------|----------|-----|--------|
| Start date | **Implemented and Working** | Date/time picker → `startsAt` | Required path | — |
| End date | **Partially Implemented** | Hard-coded `startsAt + 6 hours` in V2 save | No end picker | Small |
| Time zone | **Not Implemented** | TIMESTAMPTZ / ISO only; no event timezone field | — | Medium |
| Multi-day events | **Partially Implemented** | Possible if end set correctly; UX assumes ~6h party | End picker needed | Small |
| Registration close | **Not Implemented** | No event-level field; tier sales end only (optional, not enforced at purchase in audit) | — | Medium |
| Publish date / schedule | **Not Implemented** | Publish is immediate; `metadata.publishedAt` stamp only | No job / `publishAt` | Large |
| Validation | **Partially Implemented** | DB CHECK `ends_at >= starts_at`; FE does not expose end | — | Small |

**12.3 sub-verdict:** **Partially implemented**.

---

## 12.4 Venue

| Feature | Classification | Evidence | Why | Effort |
|---------|----------------|----------|-----|--------|
| Physical venue | **Implemented and Working** | Address / Centres / Map pin / Later modes | Primary | — |
| Virtual venue | **Frontend Complete / Backend Missing** (in V2) | Legacy wizard had venue type; V2/BE `venueType` in metadata but V2 UI omits virtual/hybrid | — | Medium |
| Hybrid event | Same as virtual | Same | Medium |
| Address | **Implemented and Working** | Address mode + city / state / LGA | Persisted | — |
| Map integration | **Partially Implemented** | Demo pin (e.g. VI Lagos); not production maps / Places | — | Large |
| Capacity | **Partially Implemented** | `expectedGuests` as attendance proxy; no dedicated venue capacity | — | Small |
| Seating | **Not Implemented** (in create) | Seating is post-create Event OS module | Out of create scope | — (later) |
| Location validation | **Partially Implemented** | Required fields by mode; no geocode verify | — | Medium |

**12.4 sub-verdict:** **Partially implemented**.

---

## 12.5 Branding

| Feature | Classification | Evidence | Why | Effort |
|---------|----------------|----------|-----|--------|
| Event banner | **Backend Complete / Frontend Missing** | `bannerLabel`, gradients in metadata; legacy mock only | V2 skips | Medium |
| Logo | **Not Implemented** (create) | Website module has cover/hero separately | Post-create website | Medium |
| Cover image | **Partially Implemented** | Optional celebrant upload; not general cover | — | Medium |
| Theme colour | **Backend Complete / Frontend Missing** (create) | `event_websites.theme_color` post-create | Not in wizard | Medium |
| Gallery | **Backend Complete / Frontend Missing** | `galleryMedia` in metadata allowlist | No V2 UI | Medium |
| Branding preview | **Not Implemented** | No create-time brand preview | — | Medium |

**12.5 sub-verdict:** **Partially implemented** (celebrant photo only).

---

## 12.6 Visibility

| Feature | Classification | Evidence | Why | Effort |
|---------|----------------|----------|-----|--------|
| Draft | **Implemented and Working** | Create always draft | — | — |
| Published | **Implemented and Working** | `POST …/publish` after create | Workspace / Events | — |
| Private | **Partially Implemented** | `PRIVATE_INVITATION` access mode via category | Not a listing visibility enum | Small |
| Invite only | **Partially Implemented** | Same as private invitation mode | Guest invites post-create | — |
| Hidden | **Partially Implemented** | Tier `visibility: hidden` only; no event listing “hidden” | — | Medium |
| Unlisted | **Not Implemented** | No unlisted status | — | Medium |
| Scheduled publish | **Not Implemented** | Immediate publish only | — | Large |

**12.6 sub-verdict:** **Partially implemented**.

---

## 12.7 Event Settings

| Feature | Classification | Evidence | Why | Effort |
|---------|----------------|----------|-----|--------|
| Registration enabled | **Not Implemented** (create) | Implied by access mode / guests module later | — | Medium |
| Ticketing enabled | **Partially Implemented** | `PUBLIC_TICKETED` from category; tiers only if seed has them **and** seed applies (currently incomplete) | No dedicated tickets step in V2 | Medium |
| RSVP only | **Partially Implemented** | Private invitation path | Not explicit toggle | Small |
| Waitlist | **Not Implemented** | — | Large |
| Check-in enabled | **Not Implemented** (create) | Ops / day modules post-create | — | Medium |
| Notifications | **Not Implemented** (create) | Settings tiles largely empty | Large |
| Sharing | **Not Implemented** (create) | Website / invites post-create | Medium |
| Public page | **Partially Implemented** | Website module after create; not wizard preview | Medium |

**12.7 sub-verdict:** **Partially implemented**.

---

## 12.8 Event Preview

| Feature | Classification | Evidence | Why | Effort |
|---------|----------------|----------|-----|--------|
| Organizer preview | **Partially Implemented** | Services-step summary card + `VenuePreviewCard` | Not guest-facing | Small |
| Public preview | **Not Implemented** | No pre-create public page preview | Website exists post-create | Medium |
| Mobile preview | **Not Implemented** | — | Medium |
| Desktop preview | **Not Implemented** | — | Medium |
| Validation summary | **Partially Implemented** | Step validation + soft budget health; no publish-readiness checklist in wizard | Medium |

**12.8 sub-verdict:** **Partially implemented**.

---

## 12.9 Template Support

| Feature | Classification | Evidence | Why | Effort |
|---------|----------------|----------|-----|--------|
| Event templates (local) | **Implemented and Working** | `event_template_catalog.dart` + dashboard/portfolio pickers | Seeds wizard | — |
| Save as template | **Not Implemented** | No FE/API to persist organizer template from event | Config table exists tenant-wide | Large |
| Load template | **Partially Implemented** | Local load works; `GET event-config/templates` / `eventTemplatesProvider` unused; DB templates often unseeded | Medium |
| Duplicate from template | **Partially Implemented** | Template → seed → wizard; `_applyDuplicateSeed` **omits** category, ticketTiers, tags, celebrant URL, lat/lng, budgetAllocation, endsAt | Medium |

**Critical seed gap (evidence):** `_applyDuplicateSeed` in `event_create_wizard_v2_screen.dart` applies title/tagline/city/venue/guests/budget/starts/services/state/lga only — not full draft.

**12.9 sub-verdict:** **Partially implemented**.

---

## 12.10 Technical Quality

| Feature | Classification | Evidence | Why | Effort |
|---------|----------------|----------|-----|--------|
| Loading states | **Partially Implemented** | Category load / save progress; uneven across steps | Small |
| Error handling | **Partially Implemented** | SnackBars + retry on save; BE errors thin | Medium |
| Empty states | **Partially Implemented** | Category fallback; empty services blocked at save | Small |
| Offline behaviour | **Partially Implemented** | Mock persistence fallback when allowed | Medium |
| Autosave reliability | **Not Implemented** | N/A until autosave exists | Medium |
| Performance | **Implemented and Working** | Lightweight wizard; acceptable | — |

**12.10 sub-verdict:** **Partially implemented**.

---

## Backend detail (create → publish)

| Capability | Classification | Evidence |
|------------|----------------|----------|
| `POST /events` | **Implemented and Working** | Title required; draft; metadata + optional public tiers |
| `PATCH /events/:id` | **Implemented and Working** | Metadata merge; **no Flutter create-flow callers** |
| `POST …/publish` | **Partially Implemented** | Sets published + `publishedAt`; **no readiness gates** |
| `POST …/go-live` | **Partially Implemented** | Status flip; weak preconditions |
| Cancel / complete APIs | **Not Implemented** | Enum exists on `event_status` |
| Typed DTOs | **Not Implemented** | `Record<string, unknown>` bodies |
| Categories / tags config | **Implemented and Working** | Auto-seed defaults |
| Event/budget templates API | **Partially Implemented** | Tables + GET; weak/no seed; limited admin write |
| Autosave endpoint | **Not Implemented** | Use PATCH if adopted |

**Create body (Flutter → API):**  
`title, tagline, city, venue, category, categorySlug, eventAccessMode, budgetMinor, expectedGuests, venue*, tags, startsAt, endsAt, budgetAllocation, requiredServices, venueDeferred, state, lga, celebrantImageUrl?, ticketTiers?`  
**Not sent though BE allows:** description, branding, `selectedTemplateSlug`, `preferredVendorIds` (model field unused in UI).

---

## Cross-cutting gaps (priority signals)

1. **Template/duplicate seed incomplete** — category & ticket tiers dropped → public templates under-deliver.  
2. **No ticket step in V2** — public events rely on post-create tickets module; publish not gated on tiers.  
3. **End time fixed +6h** — multi-day / accurate schedule weak.  
4. **No autosave / discard** — create UX fragility.  
5. **Branding / description / tags** — BE ready, FE missing in V2.  
6. **Map / centres demo** — not production discovery.  
7. **Legacy wizard orphaned** — still has tickets/media/tags patterns to migrate carefully.  
8. **Publish gates** — none server-side.

---

## Overall phase verdict

### Partially implemented

Wizard V2 + draft create + post-create publish form a working core. Configuration expected for “ready to publish” (complete templates, tickets-in-create or publish gates, branding, preview, scheduling, autosave) remains incomplete.

---

## Prioritized Phase 12 Completion Sprint roadmap

Single sprint focused on closing create→publish gaps **without** redesigning Event OS architecture. Reuse Wizard V2, existing metadata, and Event Workspace.

### P0 — Make create trustworthy

| # | Work | Classification today | Effort |
|---|------|----------------------|--------|
| 1 | Complete `_applyDuplicateSeed` / template hydrate (category, access mode, tiers, tags, image URL, endsAt, geo) | Partially Implemented | Medium |
| 2 | Public ticketed path: ticket tiers step **or** hard publish gate requiring ≥1 tier | Partially Implemented | Medium |
| 3 | End date/time picker (replace fixed +6h) + FE validation `endsAt >= startsAt` | Partially Implemented | Small |
| 4 | Cancel / discard confirmation on wizard exit | Not Implemented | Small |

### P1 — Configuration completeness in create

| # | Work | Effort |
|---|------|--------|
| 5 | Description + tags fields; wire `eventTagsProvider` | Small |
| 6 | Optional local autosave (or explicit “Save draft mid-flow” via `PATCH` after first create-id) | Medium |
| 7 | Wire `eventTemplatesProvider` / `selectedTemplateSlug` (seed BE templates if empty) | Medium |
| 8 | Explicit access-mode / visibility confirmation step (private vs public ticketed) | Small |

### P2 — Branding & preview (create-time MVP)

| # | Work | Effort |
|---|------|--------|
| 9 | Cover / banner (or celebrant + cover) using existing metadata keys | Medium |
| 10 | Organizer validation summary before “Create celebration” (checklist) | Small |
| 11 | Lightweight public/organizer preview sheet (reuse public event widgets if possible) | Medium |

### P3 — Backend hardening (same sprint if capacity)

| # | Work | Effort |
|---|------|--------|
| 12 | Publish readiness checks (title, startsAt, access mode; tiers if public) | Medium |
| 13 | Create/patch DTO validation (title, dates, accessMode enum) | Medium |
| 14 | Round-trip mapEvent for `state` / `lga` / `venueDeferred` / `selectedTemplateSlug` | Small |

### Explicitly defer (not Phase 12 Completion Sprint)

| Item | Reason |
|------|--------|
| Real Google Maps / Places | Large infra |
| Scheduled publish worker | Large / ops |
| Waitlist, age restriction, language | Later product |
| Save-as-template marketplace | Large |
| Full notification / sharing settings in create | Later settings phase |
| Quick Create express flow | Optional UX |
| Virtual/hybrid venue UX polish | Medium; after P0/P1 |
| Delete legacy wizard | Small cleanup after migration of useful steps |

### Suggested sprint outcome

Organizer can: pick template/duplicate → land in fully hydrated V2 → set accurate schedule → configure public tickets or private invitation clearly → create draft with confidence (discard/autosave) → publish only when readiness rules pass — still using Event Workspace for day-to-day ops.

---

## STOP

Audit complete. **Do not begin Phase 12 implementation** until this gap analysis is accepted.
