# OWANBE Launch Hardening Report

**Sprint:** Launch Hardening  
**Date:** 4 June 2026  
**Branch:** `feature/owanbe-event-v2`  
**Verdict:** **CONDITIONAL GO** — core blockers addressed; limited production soak required

---

## Executive summary

This sprint froze new feature work and focused on security, guest/invitation infrastructure, mock removal, vendor onboarding, chat removal, portal separation, and branding. Five MVP audit security items (S1–S5) are fixed in code. Guest and invitation APIs are implemented end-to-end. Production mock persistence is disabled by default.

**Updated MVP readiness: ~74%** (up from ~61%)

| Portal | Before | After |
|--------|--------|-------|
| Customer | 58% | 72% |
| Business (Vendor + Organizer) | 52% | 68% |
| Admin | 72% | 74% |
| Backend | 65% | 78% |

**Go / No-Go:** **CONDITIONAL GO** — ship to staging with migration `038` applied, Quaser configured for production API, and a 48-hour soak on guest invite → RSVP → check-in.

---

## Priority 1 — Security (S1–S5)

| ID | Issue | Status | Fix |
|----|-------|--------|-----|
| **S1** | Service-role key returned on presign | **Fixed** | Presign always returns API upload proxy URL; service key used only server-side in `StorageService.proxyUpload` |
| **S2** | Public aso-ebi pay bypass | **Fixed** | `CommerceAuthGuard` + reservation ownership; production blocks stub pay without Quaser |
| **S3** | No guest/RSVP/invitation API | **Fixed** | Migration `038`, `EventGuestsService`, `EventInvitationsService`, token validate + RSVP endpoints |
| **S4** | `requireProductionConfig()` never called | **Fixed** | Called at bootstrap in `main.ts` |
| **S5** | Public aso-ebi cancel | **Fixed** | `CommerceAuthGuard` + actor must own reservation or be event organizer |

---

## Priority 2 — Guest & Invitation Infrastructure

| Deliverable | Status |
|-------------|--------|
| `event_guests` API (`GET/POST/bulk`) | **Done** |
| `event_invitations` API (`GET hub`, `POST send`) | **Done** |
| Invitation token validation (`GET /invitations/validate`) | **Done** |
| RSVP tracking (`POST /invitations/rsvp`) | **Done** |
| Delivery tracking (status + notification log) | **Done** |
| Flutter invitation send wired to API | **Done** |
| Flutter guest list wired to API | **Done** |

**Apply migration:**
```bash
node scripts/apply-phase38-guests-migration.js
```

---

## Priority 3 — Mock Removal

| Item | Status |
|------|--------|
| `ALLOW_MOCK_PERSISTENCE_FALLBACK=false` in `mobile/assets/env/supabase.env` | **Done** |
| Guest add → API when mocks off | **Done** |
| Invitation send → API when mocks off | **Done** |
| Contact import gated (frozen feature) | **Done** — UI hidden when mocks off |
| `OrganizerEventStore` / `OperationsStore` / `VendorStore` read fallbacks | **Partial** — writes for organizer publish/vendor catalog still use mocks when API unavailable; reads fall back only when `ALLOW_MOCK_PERSISTENCE_FALLBACK=true` |

---

## Priority 4 — Vendor Onboarding

| Deliverable | Status |
|-------------|--------|
| Mobile flow `/vendor/onboarding` | **Done** |
| `createApplication` → `upsertBusiness` → `submit` | **Done** |
| Dashboard entry point | **Done** |

Dev vendor ID: `55555555-5555-4555-8555-555555555555`

---

## Priority 5 — Chat (Option B)

| Surface | Action |
|---------|--------|
| `vendor_contact_bar.dart` Chat button | **Removed** |
| `vendors_tab_v3.dart` Chat button | **Removed** |
| In-app request chat | **Not implemented** (by design this sprint) |

SMS / Email / WhatsApp share actions on attendee comms remain as external-channel stubs (not in-app chat).

---

## Priority 6 — Portal Separation

| Change | Status |
|--------|--------|
| Public event subpaths only: detail, `tickets`, `aso-ebi`, `wall/display` | **Done** |
| All other `/events/:eventId/*` require client auth | **Done** |
| Vendor/admin redirected away from customer event management routes | **Done** |

---

## Branding

| Asset | Location |
|-------|----------|
| App logo | `mobile/assets/branding/owanbe_logo.png` |
| Favicon | `mobile/web/favicon.png` |
| `OwanbeLogo` widget | `mobile/lib/eos/widgets/owanbe_logo.dart` |
| Shells updated | Public shell, app shell, customer shell, landing, auth |

---

## Remaining blockers (post-sprint)

1. **Migration apply** — Run `038` (and `035`–`037` if not yet applied) on staging/production DB.
2. **Organizer write paths** — `organizer_persistence.dart` still writes to `OrganizerEventStore` when API calls fail; needs full API coverage for publish/tiers/vendors.
3. **Vendor catalog/orders writes** — `VendorStore` still used for catalog toggle and order status in some screens.
4. **Public seating/program GET** — Still public; consider organizer-scoped reads for PII (not in S1–S5 scope).
5. **Customer signup** — `signUpAttendee` wired on auth screen; confirm email confirmation settings in Supabase for production.
6. **Quaser production** — Set `INTEGRATIONS_MODE=production`, `QUASER_ROUTER_BASE_URL`, `PUBLIC_API_BASE_URL` on API.
7. **Contact import** — Intentionally frozen; do not enable in production UI.

---

## Test plan (staging)

- [ ] Apply DB migration `038`
- [ ] API boot with `INTEGRATIONS_MODE=production` + Quaser URL (or dev stubs off)
- [ ] Presign upload → PUT proxy → object reachable; no service key in response
- [ ] Aso-ebi pay/cancel without auth → 401; wrong user → 403
- [ ] Add guest → send invitation → validate token → RSVP confirm/decline
- [ ] Vendor role opens `/events/:id/guests` → redirected to `/vendor`
- [ ] Vendor onboarding submit → application `under_review` in DB
- [ ] Logo visible on landing, auth, shells, favicon

---

## Recommendation

**CONDITIONAL GO** for a **staging / limited beta** release after migration apply and payment integration verification. Promote to full production GO after organizer/vendor write-path mock removal and 48h soak with real invite + checkout flows.

**Frozen (do not ship this sprint):** Contact Import, Invitation Designer, EventBook, new marketplace categories, new AI features.
