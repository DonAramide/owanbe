# Phase 40 — Beta Test Scripts

**Environment:** Staging with `INTEGRATIONS_MODE=production`, mocks off, migration `038` applied.  
**Dev credentials:** `attendee@owanbe.dev` / `123456` (client), organizer/vendor via staff login.

---

## Customer journey

**Goal:** Discover event → sign up → create event → add guests → send invitations → guest RSVPs → buy ticket → check-in.

| Step | Action | Expected | API / UI |
|------|--------|----------|----------|
| C1 | Open `/` | Logo, featured events | Public shell |
| C2 | Browse `/events` | Published events from API | `GET /events` |
| C3 | Sign up `/auth` | Account created or email confirm message | Supabase `signUpAttendee` |
| C4 | Sign in → `/home` | Customer shell, my events | JWT `client` role |
| C5 | Create event `/events/create` | Event in DB as draft | `POST /events` |
| C6 | Open event command center | Modules visible (guests, invitations, seating…) | Auth required on subroutes |
| C7 | Add guest `/events/:id/guests` | Guest in `event_guests` | `POST /events/:id/guests` |
| C8 | Send invitations `/events/:id/invitations` | `sent` count > 0, stats update | `POST .../invitations/send` |
| C9 | Validate token | `valid: true`, guest name | `GET /invitations/validate?token=` |
| C10 | RSVP confirm | `rsvp_status=confirmed` | `POST /invitations/rsvp` |
| C11 | Public tickets `/events/:id/tickets` | Tiers listed | `GET /events/:id/tiers` |
| C12 | Checkout + pay | Quaser flow → entitlements | Commerce + webhook |
| C13 | Attendee dashboard `/attendee` | Ticket visible | Entitlements API |
| C14 | Event day check-in (organizer ops) | Guest checked in | `POST /events/:id/check-ins` |

**Pass criteria:** C7–C10 without mock fallback; C12 with real or sandbox Quaser.

**curl examples (after obtaining JWT)**

```bash
# Add guest
curl -X POST "$API/events/$EVENT_ID/guests" \
  -H "Authorization: Bearer $JWT" -H "X-Tenant-Id: $TENANT" \
  -H "Content-Type: application/json" \
  -d '{"name":"Ada Okafor","email":"ada@test.com"}'

# Send invitations
curl -X POST "$API/events/$EVENT_ID/invitations/send" \
  -H "Authorization: Bearer $JWT" -H "X-Tenant-Id: $TENANT" \
  -d '{"channel":"link"}'

# RSVP
curl -X POST "$API/invitations/rsvp" \
  -H "X-Tenant-Id: $TENANT" \
  -d '{"token":"TOKEN","status":"confirmed"}'
```

---

## Vendor journey

**Goal:** Onboard → marketplace visibility → receive request → manage participation.

| Step | Action | Expected | API / UI |
|------|--------|----------|----------|
| V1 | Staff login `?role=vendor` | Vendor home | JWT `vendor` role |
| V2 | Start onboarding `/vendor/onboarding` | Application `applied` | `POST .../onboarding/applications` |
| V3 | Business details + submit | Status `under_review` | PUT business + POST submit |
| V4 | Marketplace `/vendors` | Vendor listed (if active) | `GET /vendors` |
| V5 | Customer requests vendor | CRM pipeline entry | Vendor CRM API |
| V6 | Accept participation | Status updated in DB | `VendorEventsApi` |
| V7 | Orders screen | Bookings + catalog from API | `GET /bookings`, `GET /vendor/packages` |

**Pass criteria:** V2–V6 on API; V7 via bookings/packages API (P40.1/P40.2 complete).

---

## Admin journey

**Goal:** Review vendor application → monitor platform health → finance oversight.

| Step | Action | Expected | API / UI |
|------|--------|----------|----------|
| A1 | Staff login `?role=admin` | Admin home | JWT `admin_*` |
| A2 | Vendor onboarding queue | Pending applications | Admin onboarding module |
| A3 | Approve vendor | Vendor `active` | Admin approve endpoint |
| A4 | Platform health | DB ok, integrations status | `GET /health` |
| A5 | Metrics scrape | Counters present | `GET /metrics` |
| A6 | Finance dashboard | Ledger / payouts visible | Admin finance screens |
| A7 | Dispute / compliance | Read-only audit | Compliance module |

**Pass criteria:** A2–A4 on staging data; A5 shows `api_errors_total`, `invitations_*`, `notifications_*`.

---

## Regression smoke (15 min)

1. Vendor role → `/events/:id/guests` → redirect to `/vendor` (portal separation).
2. Unauthenticated → `/events/:id/budget` → redirect to `/auth`.
3. Presign upload → no `Authorization: Bearer sb_secret` in response.
4. Aso-ebi pay without JWT → 401.
5. `ALLOW_MOCK_PERSISTENCE_FALLBACK=false` → contact import hidden on invitations screen.

---

## Test data setup

```bash
node scripts/apply-phase38-guests-migration.js
# Ensure dev seed users exist (organizer + vendor + client)
```

**Record results** in a shared sheet: step ID, pass/fail, screenshot, `request_id` from API errors.
