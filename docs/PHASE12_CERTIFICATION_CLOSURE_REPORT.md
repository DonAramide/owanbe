# PHASE 12.1 — CERTIFICATION CLOSURE REPORT

**Date:** 2026-07-27  
**Reference:** `docs/PHASE12_LIVE_QA_REPORT.md`  
**Scope:** Resolve Live QA certification blockers H1–H3 and triage medium findings.  
**Not Phase 13.** No architecture redesign. No new product surfaces beyond blocker fixes.

---

## Final conclusion

### ✅ Ready for Certification

API probes (`scripts/phase12_1_closure_qa.mjs`) confirm discard, PATCH ticket tiers, metadata exposure, publish-after-tier-patch, and discard-of-published rejection. Flutter resume/discard/autosave wiring is implemented. Operator should **hot restart** Flutter once before formal sign-off.

---

## H1 — Discard Draft

### Root cause
Wizard discard cleared local SharedPreferences only. Mid-flow autosave had already `POST /events` (draft), so the server draft remained visible in organizer lists and draft KPIs. No discard/cancel API existed.

### Fix implemented
- Soft-discard: `POST /events/:eventId/discard` sets `status = cancelled` for **draft-only** events (metadata `discardedAt` / `discardedReason`).
- Default organizer event list excludes `cancelled` unless `?status=cancelled`.
- Dashboard already counted only `draft` — cancelled drafts no longer inflate draft counts.
- Wizard `_discard` and resume-decline call `discardServerDraft` then clear local state.
- Published discard rejected with `422 INVALID_STATUS`.

### Evidence
| Check | Result |
|-------|--------|
| Discard draft → **201** `{ ok: true }` | **PASS** |
| Discarded id absent from list + `status=draft` | **PASS** |
| Discard published → **422** | **PASS** |

---

## H2 — Resume Draft (`serverEventId` lost)

### Root cause
Local autosave stored a **flat draft JSON** without `serverEventId` or wizard step. After refresh, resume restored fields but `_serverEventId` stayed null → risk of a second `POST`.

### Fix implemented
- Local envelope **v2**: `{ v, serverEventId, wizardStep, dirty, draft }`.
- Legacy flat JSON still loads (no server id).
- On resume: restore draft + `serverEventId` + `wizardStep`; bind autosave provider.
- On every local persist / server bind: rewrite envelope with current step + server id.

### Evidence
| Check | Result |
|-------|--------|
| Envelope includes `serverEventId` + `wizardStep` | **PASS** (source) |
| Resume applies both into wizard state | **PASS** (source) |
| UI refresh smoke | **OPERATOR** (hot restart + resume dialog) |

---

## H3 — Autosave / PATCH omits ticket tiers

### Root cause
`v2DraftToApiBody` omitted `ticketTiers`. Backend `patch()` never synced tiers — only `create()` inserted them for public events.

### Fix implemented
- Flutter: always include `ticketTiers` in PATCH body.
- Backend: `syncDraftTiers` on PATCH — upsert incoming tiers; delete unsold tiers removed from the payload.
- Publish after tier PATCH works (gate satisfied).

### Evidence
| Check | Result |
|-------|--------|
| PATCH adds General Admission tier | **PASS** |
| Publish after PATCH → **201** published | **PASS** |

---

## Medium findings

| ID | Finding | Disposition |
|----|---------|-------------|
| M1 | `?focus=readiness` unused | **Fixed** — `EventDesktop` scrolls Setup checklist into view via `_FocusableReadiness` when query is `readiness` |
| M2 | Duplicate hydration incomplete | **Fixed** (Command Center path) — `buildDuplicateDraftFromOrganizerEvent` copies services, language, age, registration/check-in, theme, venue deferred/state/lga, branding, listing visibility, fresh tier ids. Closing-workspace duplicate already carried services/tags; venueType not mapped (`CustomerVenueType` ≠ `VenueType`) — accepted |
| M3 | Metadata not on EventView | **Fixed** — `language`, `ageRestrictionMin`, `listingVisibility`, `registrationEnabled`, `checkInEnabled`, `themeColor`, `requiredServices`, `venueDeferred`, `state`, `lga`, `selectedTemplateSlug` on API view + Flutter `OrganizerEvent` / mapper |

---

## Files changed

### Backend
- `services/api/src/modules/events/events.service.ts` — discard, list filter, patch tier sync, metadata map
- `services/api/src/modules/events/events.controller.ts` — `POST events/:eventId/discard`

### Mobile
- `mobile/lib/features/organizer/wizard_v2/event_wizard_autosave.dart` — v2 envelope
- `mobile/lib/features/organizer/wizard_v2/event_create_wizard_v2_screen.dart` — resume/discard/step persist
- `mobile/lib/features/organizer/data/organizer_persistence.dart` — tiers in PATCH body; `discardServerDraft`
- `mobile/lib/core/api/events_api.dart` — `discardEvent`; metadata mapping
- `mobile/lib/features/organizer/models/organizer_models.dart` — OrganizerEvent metadata fields
- `mobile/lib/features/organizer/widgets/organizer_command_center.dart` — fuller duplicate seed
- `mobile/lib/portals/customer/workspace/widgets/event_desktop.dart` — focus=readiness scroll
- `mobile/lib/portals/customer/closing/event_closing_actions.dart` — banner on closing duplicate

### Scripts / docs
- `scripts/phase12_1_closure_qa.mjs`
- `docs/PHASE12_CERTIFICATION_CLOSURE_REPORT.md` (this file)

---

## APIs changed

| Method | Path | Behaviour |
|--------|------|-----------|
| **NEW** `POST` | `/v1/events/:eventId/discard` | Soft-cancel draft only |
| **Extended** `PATCH` | `/v1/events/:eventId` | Syncs `ticketTiers` when present; rejects cancelled |
| **Extended** `GET` | `/v1/organizers/me/events` | Excludes cancelled unless status filter set |
| **Extended** EventView | — | Exposes Phase 12 metadata fields |

---

## Regression results

| Area | Result | Evidence |
|------|--------|----------|
| Dashboard | **PASS** | `GET /organizers/me/dashboard` **200** |
| Drafts list | **PASS** | Discarded draft absent; other drafts remain |
| Publish gates | **PASS** | Tier required for public; publish after PATCH tiers OK |
| Autosave / PATCH | **PASS** | Tiers + metadata persist |
| Wizard V2 | **PASS** (source) | Discard/resume/step envelope; no analyzer errors on touched paths after closing fix |
| Templates / duplicate | **PASS** (source) | Command Center seed expanded |
| Event Workspace | **PASS** (source) | Readiness panel + focus scroll |

---

## Remaining deferred items (accepted)

| Item | Reason |
|------|--------|
| Scheduled publish | No backend worker (Phase 12 completion deferral) |
| Real Maps / Places | Demo pin retained |
| Separate logo asset | Celebrant cover remains Branding MVP |
| Closing-path `venueType` map | Type mismatch; Command Center duplicate is primary |
| Hard delete of cancelled rows | Soft-cancel is intentional for audit consistency |

---

## Operator checklist (final sign-off)

1. Hot restart Flutter (`R`).
2. Create Event → advance past Details (server draft created) → Discard → confirm draft gone from Dashboard/Events.
3. Create Event → Save draft → refresh browser → Resume → confirm continues on same event (no duplicate).
4. Public event → add tickets mid-wizard → Create → Workspace checklist → publish.
5. Create Event → open workspace with `?focus=readiness` → checklist scrolled into view.

---

## STOP

**Do not begin Phase 13.** Proceed to Phase 12 Certification (operator UI walkthrough above) using this closure report + prior Live QA evidence.
