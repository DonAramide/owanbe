# PHASE 30 — CANONICAL MANUAL LIVE QA CHECKLIST

**Purpose:** Original manual Live QA cycle after FULL PLATFORM CERTIFIED (API harness).  
**Date:** 2026-08-03  
**Constraint:** Implemented features only (completion reports Phases 13–29 + Phase 30 evidence).  
**Do not test:** Deferred / Unavailable / roadmap items listed in §4.

**Alignment**

| Source | Alignment |
|--------|-----------|
| Phase completion reports 13–19, 21–29 | Journeys and PASS capabilities only |
| Phase 30 final evidence | Same API surfaces certified operable (`docs/evidence/phase30_final_certification_run.json`) |
| Architecture ownership | Finance owns money; Analytics/Reporting consume; Compliance governs lifecycle; Automation/Integrations transport only |

**Environment gate (before any journey)**

| Check | Expected | ☐ |
|-------|----------|---|
| `GET /health` | `status=ok`, `database=ok`, migrations applied (automation/webhook tables present) | |
| `QUASER_WEBHOOK_SECRET` | Configured (health `quaserWebhookSecret=configured`) | |
| `GET /metrics` | Prometheus text | |
| Auth | Organizer owner, Attendee/Buyer, Door staff (or owner), Admin (`admin_super`), Vendor (for CRM) | |
| Data | At least one draft event; ability to publish; payment rail for paid path (or free tier) | |

Mark each case **PASS** / **FAIL** / **BLOCKED** (env). FAIL = wrong behavior on an implemented path. Do not FAIL on documented Unavailable honesty.

---

# 1. Phases 14–18 — Attendee + Organizer operational loop

**Canonical chain**

```
Publish → Discover → Ticket purchase → Invitation → RSVP → Entitlement
  → Check-in → Finance → Analytics
```

*(Tier/commerce rules from Phase 13 are in-loop prerequisites; they are implemented and required for a coherent 14–18 run.)*

---

## L14 — Publishing & discovery

### L14-01 Publish public ticketed event

| Field | Detail |
|-------|--------|
| **Role** | Organizer (owner) |
| **Starting condition** | Draft event with title, schedule, city; ≥1 public listing tier with open sales window; publish readiness satisfied |
| **Action** | Publish event (`POST /v1/events/:id/publish` or Wizard V2 publish) |
| **Expected** | Event `status` becomes published (or live); discoverable when `PUBLIC_TICKETED` + `listingVisibility=public` |
| **API/DB** | `events.status`, `listing_visibility`, `event_access_mode`; `GET /v1/events` (public list) includes event |
| **PASS** | Event appears in Discover / public list |
| **FAIL** | Publish succeeds but event missing from public discovery, or draft remains publicly listed |

### L14-02 Non-public events stay off Discover

| Field | Detail |
|-------|--------|
| **Role** | Organizer; Public/Attendee |
| **Starting condition** | Second event set to private / hidden / invite-only (or draft) |
| **Action** | Open Discover / `GET /v1/events` as unauthenticated or attendee |
| **Expected** | Only public published/live/completed ticketed events appear |
| **API/DB** | `listPublic` filter; private event id absent from public feed |
| **PASS** | Private/hidden/draft never in Discover |
| **FAIL** | Restricted event visible in public catalog |

### L14-03 Storefront tier filtering

| Field | Detail |
|-------|--------|
| **Role** | Public / Buyer |
| **Starting condition** | Event has public tier + hidden tier + future `salesStartAt` tier (Phase 13 rules) |
| **Action** | `GET /v1/events/:id/tiers` (public storefront) |
| **Expected** | Hidden and not-yet-on-sale tiers omitted; open public tier visible |
| **API/DB** | Response item ids; no `tier_hidden` / future-only ids |
| **PASS** | Filters match eligibility rules |
| **FAIL** | Hidden/future tiers shown on public storefront |

---

## L13/L14 — Ticket purchase & entitlements

### L14-04 Paid ticket purchase (happy path)

| Field | Detail |
|-------|--------|
| **Role** | Attendee / Buyer |
| **Starting condition** | Published public event; paid open tier; Quaser/payments configured |
| **Action** | Create order → complete payment → open My Tickets / passes |
| **Expected** | Order fulfilled/confirmed; `ticket_entitlements` issued; pass/QR available |
| **API/DB** | `POST /v1/events/:id/ticket-orders`; payment webhook settles; entitlements `issued` |
| **PASS** | Buyer has usable entitlement; organizer sales list shows order |
| **FAIL** | Payment success without entitlement, or entitlement without settled order |

### L14-05 Purchase rule rejection

| Field | Detail |
|-------|--------|
| **Role** | Buyer |
| **Starting condition** | Attempt buy on hidden tier **or** before sales window **or** over max/per-user limit |
| **Action** | `POST …/ticket-orders` with illegal selection |
| **Expected** | `422` with commerce code (`TIER_HIDDEN`, `SALES_NOT_STARTED`, `MAX_QUANTITY`, `PER_USER_LIMIT`, etc.) |
| **API/DB** | No new fulfilled order / no entitlement for rejected attempt |
| **PASS** | Rejected with clear code; inventory unchanged inappropriately |
| **FAIL** | Illegal purchase succeeds |

### L14-06 Free / complimentary auto-fulfill

| Field | Detail |
|-------|--------|
| **Role** | Buyer |
| **Starting condition** | Zero-price or complimentary-eligible tier on published event |
| **Action** | Complete checkout (no payment rail required) |
| **Expected** | Order auto-fulfilled; entitlements issued without Quaser charge |
| **API/DB** | Order status fulfilled; entitlements present; no pending payment stuck |
| **PASS** | Pass appears in My Tickets |
| **FAIL** | Free order stuck in `pending_payment` |

---

## L15 — Invitations & RSVP

### L15-01 Send invitation

| Field | Detail |
|-------|--------|
| **Role** | Organizer |
| **Starting condition** | Event with guest/invitation hub access |
| **Action** | Invite by email and/or generate invite link; optionally invite existing user |
| **Expected** | Invitation row + token; hub KPIs update (invited/awaiting) |
| **API/DB** | `POST …/invitations/send` or guest invite-link; `GET …/invitations` |
| **PASS** | Guest appears awaiting; link/token usable |
| **FAIL** | UI success with no invitation record |

### L15-02 RSVP Accept → entitlement

| Field | Detail |
|-------|--------|
| **Role** | Guest (may start unauthenticated) |
| **Starting condition** | Valid non-expired invitation token |
| **Action** | Open `/events/:id/rsvp?token=` → Accept |
| **Expected** | RSVP accepted; complimentary fulfilled order + entitlement (or pending claim until sign-in) |
| **API/DB** | `GET /v1/invitations/validate`; `POST /v1/invitations/rsvp`; guest status accepted; entitlement or `pendingEntitlement` |
| **PASS** | After claim/sign-in, pass in My Tickets / guest invitations resolved |
| **FAIL** | Accept without entitlement path, or invents “Maybe” status |

### L15-03 RSVP Decline → no ticket

| Field | Detail |
|-------|--------|
| **Role** | Guest |
| **Starting condition** | Valid invitation |
| **Action** | Decline on RSVP screen |
| **Expected** | Guest declined; **no** ticket entitlement issued |
| **API/DB** | Guest/invitation declined; no new complimentary order for that guest |
| **PASS** | Declined guest has no pass |
| **FAIL** | Decline still creates ticket |

### L15-04 Cancel / expired token

| Field | Detail |
|-------|--------|
| **Role** | Organizer then Guest |
| **Starting condition** | Sent invitation |
| **Action** | Organizer cancels invitation; guest opens old link |
| **Expected** | Validate/RSVP fails clearly (cancelled/expired) |
| **API/DB** | Token cancelled / `expires_at` set |
| **PASS** | RSVP screen shows invalid/cancelled; no entitlement |
| **FAIL** | Cancelled token still accepts |

---

## L16 — Door / check-in

### L16-01 Check-in issued ticket

| Field | Detail |
|-------|--------|
| **Role** | Organizer / door operator (`ops.door`) |
| **Starting condition** | Attendee with `issued` entitlement (paid or invite) |
| **Action** | Check-in via paste/code entry on QR/Check-in center (camera package not required) |
| **Expected** | Entitlement → checked_in; door summary counts increase |
| **API/DB** | `POST /v1/events/:id/check-ins`; `GET …/door-summary`; `event_check_ins` row |
| **PASS** | Status Inside/checked-in; counters coherent |
| **FAIL** | Check-in UI success without entitlement update |

### L16-02 Duplicate / invalid / cancelled

| Field | Detail |
|-------|--------|
| **Role** | Door operator |
| **Starting condition** | Already checked-in ticket; plus invalid code; plus voided/refunded if available |
| **Action** | Re-scan / submit each code |
| **Expected** | Duplicate flagged; invalid/cancelled rejected with clear outcome |
| **API/DB** | Soft duplicate response or error codes `TICKET_*` |
| **PASS** | No second silent check-in as success |
| **FAIL** | Duplicate treated as first-time success |

### L16-03 Door summary & ops dashboard

| Field | Detail |
|-------|--------|
| **Role** | Organizer / ops |
| **Starting condition** | Mix of issued + checked-in entitlements |
| **Action** | Open Check-in center / Operations dashboard |
| **Expected** | Checked-in, remaining, attendance % match entitlement reality |
| **API/DB** | `GET /v1/events/:id/door-summary` |
| **PASS** | KPI math matches counts |
| **FAIL** | Fabricated capacity/attendance unrelated to entitlements |

---

## L17 — Finance

### L17-01 Event finance summary (money SoT)

| Field | Detail |
|-------|--------|
| **Role** | Organizer owner/admin/manager (`finance.read`) |
| **Starting condition** | Event with fulfilled orders (and optional refunds) |
| **Action** | Open Finance tab / `GET /v1/events/:id/finance/summary` |
| **Expected** | Gross/net/fees/refunds/escrow labels from finance services — **Finance owns money** |
| **API/DB** | Summary fields; compare to fulfilled `ticket_orders` totals |
| **PASS** | Totals reconcile to commerce settlement truth |
| **FAIL** | Numbers disagree with orders without explanation, or Budget module used as ticket ledger |

### L17-02 Organizer finance hub

| Field | Detail |
|-------|--------|
| **Role** | Organizer |
| **Starting condition** | ≥1 event with sales |
| **Action** | Dashboard finance strip / `GET /v1/organizers/me/finance/hub` |
| **Expected** | Portfolio finance KPIs load; deep-link to events |
| **API/DB** | Hub 200; event ids owned by organizer |
| **PASS** | Hub reflects organizer events only |
| **FAIL** | Cross-organizer leakage |

### L17-03 Refund case lifecycle (if refund UI used)

| Field | Detail |
|-------|--------|
| **Role** | Organizer with refund capability |
| **Starting condition** | Fulfilled paid order |
| **Action** | Create refund case → approve/reject path per UI |
| **Expected** | Case state machine advances; completed refund updates finance + voids issued entitlement when applicable |
| **API/DB** | `POST …/finance/refunds`; `…/refunds/:caseId/:action`; ledger/entitlement effects |
| **PASS** | Finance summary and attendee pass reflect outcome |
| **FAIL** | Refund completed but entitlement still check-inable as valid issued |

### L17-04 Staff denied finance

| Field | Detail |
|-------|--------|
| **Role** | Organizer **staff** member |
| **Starting condition** | Active staff membership (Phase 22); no finance capability |
| **Action** | Call finance hub or open Finance tab |
| **Expected** | `ORG_CAPABILITY_DENIED` / access blocked |
| **API/DB** | 403 with capability code |
| **PASS** | Staff cannot read finance SoT |
| **FAIL** | Staff sees monetary totals |

---

## L18 — Analytics

### L18-01 Event analytics consumes finance

| Field | Detail |
|-------|--------|
| **Role** | Organizer (`analytics.read`) |
| **Starting condition** | Same event as L17 with sales + check-ins + RSVPs |
| **Action** | Open Analytics tab / `GET /v1/events/:id/analytics` |
| **Expected** | KPIs from orders, entitlements, check-ins, invitations; finance block has `monetarySource=organizer_finance` |
| **API/DB** | Analytics JSON `monetarySource`; attendance matches door; RSVP funnel matches invitations |
| **PASS** | No second money ledger; traffic/page views show Unavailable if present |
| **FAIL** | Invented page views/UTM as real, or monetary totals diverge from Finance without source tag |

### L18-02 Portfolio analytics

| Field | Detail |
|-------|--------|
| **Role** | Organizer |
| **Starting condition** | Multiple events |
| **Action** | `GET /v1/organizers/me/analytics/portfolio` / dashboard portfolio |
| **Expected** | Per-event sold/revenue/attendance read-only rollup |
| **API/DB** | Portfolio items match event-level truths |
| **PASS** | Coherent comparison strip |
| **FAIL** | Synthetic portfolio metrics |

---

# 2. Phases 19–29 — Business Operations Live QA

**Canonical chain**

```
Vendor CRM → Reporting → Organization → Automation → Integrations
  → Marketing → Compliance → Control Plane → Identity Security
```

---

## L19 — Vendor CRM

### L19-01 Organizer vendor pipeline

| Field | Detail |
|-------|--------|
| **Role** | Organizer (vendors capability — not staff) |
| **Starting condition** | Event workspace; marketplace/vendor request available |
| **Action** | Open Vendors tab / CRM pipeline; advance stage or message if flow allows |
| **Expected** | Requests from `vendor_event_requests`; stages/timeline real; no fake e-sign |
| **API/DB** | CRM list/stage/timeline (`GET /vendor-requests/:id/timeline`) |
| **PASS** | Pipeline matches DB requests |
| **FAIL** | Cosmetic pipeline inventing vendors/contracts |

### L19-02 Vendor inbox / calendar

| Field | Detail |
|-------|--------|
| **Role** | Vendor |
| **Starting condition** | Vendor with live request/job |
| **Action** | Open vendor CRM inbox / calendar / jobs |
| **Expected** | Live data (no demo mask); calendar jobs from CRM |
| **API/DB** | Vendor-scoped requests/jobs |
| **PASS** | Vendor sees own pipeline truth |
| **FAIL** | Demo/synthetic bookings shown as live |

### L19-03 Staff denied vendor CRM

| Field | Detail |
|-------|--------|
| **Role** | Organizer staff |
| **Starting condition** | Active staff membership |
| **Action** | Access vendor CRM APIs/UI |
| **Expected** | Capability deny |
| **API/DB** | 403 `ORG_CAPABILITY_DENIED` |
| **PASS** | Staff blocked |
| **FAIL** | Staff can mutate hire pipeline |

---

## L21 — Reporting & exports

### L21-01 Event report packs

| Field | Detail |
|-------|--------|
| **Role** | Organizer |
| **Starting condition** | Event with tickets, door activity, guests, vendors as available |
| **Action** | Reports tab → export Event Summary / Attendance / Finance / Ticket Sales / Vendor / Guest packs |
| **Expected** | CSV/Excel download; numbers match Finance/Analytics/Door/Invitations/CRM for same filters |
| **API/DB** | `GET …/reports/catalog`; `GET …/reports/export/:pack` |
| **PASS** | Packs compose canonical sources (reporting owns export only) |
| **FAIL** | Export invents ledger rows or disagrees with Finance for same window |

### L21-02 Portfolio report export

| Field | Detail |
|-------|--------|
| **Role** | Organizer |
| **Action** | `GET /v1/organizers/me/reports/catalog` + portfolio export |
| **Expected** | Portfolio packs generate |
| **PASS** | File/download succeeds from catalog |
| **FAIL** | Empty fake success without catalog |

---

## L22 — Organization & team

### L22-01 Invite → accept → directory

| Field | Detail |
|-------|--------|
| **Role** | Owner invites; invitee accepts |
| **Starting condition** | Owner org; invitee email matches account |
| **Action** | `POST …/team/invites` → accept → list team |
| **Expected** | Member active; directory shows owner + members; activity in audit |
| **API/DB** | `organizer_members`; `GET …/team`; `GET …/team/activity` |
| **PASS** | Membership real and listed |
| **FAIL** | Accept without `organizer_members` row |

### L22-02 Role change & revoke

| Field | Detail |
|-------|--------|
| **Role** | Owner / admin |
| **Starting condition** | Active manager or staff |
| **Action** | Patch role; revoke member |
| **Expected** | Capabilities change; revoked cannot access org APIs |
| **API/DB** | `PATCH …/members/:id/role`; `POST …/revoke`; membership status |
| **PASS** | Revoked user denied org surfaces |
| **FAIL** | Revoked user still has finance/team write |

---

## L23 — Automation

### L23-01 Catalog, enable, runs

| Field | Detail |
|-------|--------|
| **Role** | Organizer (not staff) |
| **Starting condition** | Automations migration applied |
| **Action** | Open Automations → view catalog → toggle a template → trigger domain path if possible (e.g. RSVP or ticket issue) |
| **Expected** | Definitions list; enable persists; runs/observability show real job/run rows (or empty list — not fake success metrics) |
| **API/DB** | `GET …/automations`; `POST …/:workflowKey/enabled`; `GET …/runs`; `GET …/observability`; tables `automation_runs` / jobs |
| **PASS** | Orchestration only — does not rewrite ticket/RSVP/finance rows incorrectly |
| **FAIL** | Automation invents business outcomes without domain event |

---

## L24 / L25 — Integrations & hardening

### L24-01 Integrations status & webhook deliveries

| Field | Detail |
|-------|--------|
| **Role** | Organizer (integrations capability) |
| **Starting condition** | Integrations layer migrated; optional webhook registered |
| **Action** | `GET …/integrations/status`; list webhooks/deliveries; register webhook if testing outbound |
| **Expected** | Status coherent; deliveries list real or empty; secrets not returned plaintext |
| **API/DB** | `platform_webhook_deliveries`; health webhookDelivery ok |
| **PASS** | Transport/audit only |
| **FAIL** | Webhook UI invents ticket/finance payloads as SoT |

### L24-02 Quaser inbound payment regression

| Field | Detail |
|-------|--------|
| **Role** | System / Buyer |
| **Starting condition** | Paid order pending settlement |
| **Action** | Complete payment so Quaser webhook hits API |
| **Expected** | Order settles; entitlements/finance update (unchanged Phase 9/13 path) |
| **API/DB** | Webhook auth with configured secret; order status |
| **PASS** | Settlement path works with secret configured |
| **FAIL** | Unsigned/wrong secret accepted, or settle without entitlement |

### L25-01 Capability matrix spot-check

| Field | Detail |
|-------|--------|
| **Role** | Staff vs Owner |
| **Action** | Staff: door OK; finance/vendors/automations/integrations denied. Owner: allowed |
| **Expected** | Phase 25 matrix |
| **PASS** | Matches matrix |
| **FAIL** | Staff reaches finance or owner blocked from door incorrectly |

---

## L26 — Marketing

### L26-01 Audience preview & campaign send (email path)

| Field | Detail |
|-------|--------|
| **Role** | Owner/Admin/Manager (`marketing.manage`) |
| **Starting condition** | Guests and/or ticket buyers exist; Enterprise Email configured |
| **Action** | Preview segment → create campaign → send (≤200 recipients) |
| **Expected** | Channels show configured vs Unavailable honestly; campaign draft→sending→sent|failed; recipients audited |
| **API/DB** | `…/marketing/segments`, `audience/preview`, `campaigns`, `…/send`; `marketing_campaigns` |
| **PASS** | Uses NotificationService; no invented revenue |
| **FAIL** | Fake open/click attribution or promo-code checkout (not implemented) |

### L26-02 Staff denied marketing

| Field | Detail |
|-------|--------|
| **Role** | Staff |
| **Action** | Marketing APIs/UI |
| **Expected** | Denied |
| **PASS** | 403 / blocked UI |
| **FAIL** | Staff can send campaigns |

---

## L27 — Compliance

### L27-01 Dashboard, retention, activity

| Field | Detail |
|-------|--------|
| **Role** | Platform admin (`admin_super` / admin tiers) |
| **Starting condition** | Migration `060` |
| **Action** | Admin Compliance / Security 360 Compliance → dashboard, retention, activity |
| **Expected** | Live Nest data; retention readable/updatable per implemented categories |
| **API/DB** | `GET /v1/compliance/dashboard|retention|activity` |
| **PASS** | Governance surfaces only; no invented business rows |
| **FAIL** | Cosmetic compliance unrelated to Nest APIs |

### L27-02 Export / deletion lifecycle smoke

| Field | Detail |
|-------|--------|
| **Role** | Platform admin |
| **Action** | Create export request and/or deletion request and advance an allowed transition |
| **Expected** | Lifecycle states; download re-composes evidence; deletion anonymizes identity — **does not hard-delete finance/ticket ledgers** |
| **API/DB** | `/compliance/exports`, `/compliance/deletion-requests` |
| **PASS** | Ledger rows remain; identity fields anonymized when completed |
| **FAIL** | Process wipes monetary/ticket history |

---

## L28 — Control Plane

### L28-01 Dashboard, vendors, MDM dictionaries

| Field | Detail |
|-------|--------|
| **Role** | `admin_super` / admin tiers as required |
| **Action** | Control Plane dashboard; vendor governance list; MDM domains/entities |
| **Expected** | Live Nest over tenants/vendors/`mdm_*` |
| **API/DB** | `/v1/control-plane/dashboard|vendors|mdm/domains` |
| **PASS** | Governance over existing entities |
| **FAIL** | Fake device fleet or parallel vendor hire SoT |

### L28-02 Devices honest Unavailable

| Field | Detail |
|-------|--------|
| **Role** | Admin |
| **Action** | `GET /v1/control-plane/devices` / Devices UI |
| **Expected** | Honest Unavailable (`available: false` or equivalent banner) |
| **PASS** | No invented device rows |
| **FAIL** | Fake enrolled devices shown as live MDM |

### L28-03 Tenant suspend (if exercising governance)

| Field | Detail |
|-------|--------|
| **Role** | Super-admin / role with `tenant.suspend` |
| **Starting condition** | Non-prod lab tenant only |
| **Action** | Suspend → verify access impact → reactivate |
| **Expected** | Tenant status + audit activity |
| **API/DB** | Control-plane tenants APIs; activity feed |
| **PASS** | Audit evidence recorded |
| **FAIL** | Suspend with no status/audit change |

---

## L29 — Identity & Security

### L29-01 Self MFA status / enroll (Supabase TOTP)

| Field | Detail |
|-------|--------|
| **Role** | End user |
| **Starting condition** | Supabase MFA enabled |
| **Action** | Enterprise auth MFA enroll/verify; `GET /v1/me/security/mfa` |
| **Expected** | Real TOTP factors; no hardcoded QR secret |
| **API/DB** | MFA status; security events `mfa_*` when audited |
| **PASS** | Factor visible via Auth; Nest status coherent |
| **FAIL** | Hardcoded secret enrollment still present |

### L29-02 Security Center

| Field | Detail |
|-------|--------|
| **Role** | Admin |
| **Action** | Open Security Center / `GET /v1/identity-security/center` |
| **Expected** | Feed from `platform_security_events` (may be empty) |
| **PASS** | Nest-backed; no invented sessions list as SoT |
| **FAIL** | Cosmetic SecurityEngine data as operational truth |

### L29-03 Suspend → ACCOUNT_BLOCKED

| Field | Detail |
|-------|--------|
| **Role** | Admin suspends; target user |
| **Starting condition** | Lab user (not sole break-glass) |
| **Action** | Suspend with reason → target calls protected API → reactivate |
| **Expected** | `ACCOUNT_BLOCKED` / forbidden while suspended; security/audit events |
| **API/DB** | `users.suspended_*`; `POST …/suspend|reactivate` |
| **PASS** | Suspended user cannot use API; restore works |
| **FAIL** | Suspended user still authenticated successfully for API |

### L29-04 Sessions (honest PARTIAL allowed)

| Field | Detail |
|-------|--------|
| **Role** | Self or admin |
| **Action** | `GET /me/security/sessions` or admin sessions |
| **Expected** | Visibility/revoke when Auth Admin works; **or** honest limited/Unavailable — never invented multi-device rows |
| **PASS** | Either real Auth Admin data or honest limitation |
| **FAIL** | Fabricated device session inventory |

---

# 3. Cross-pack data ownership assertions (must hold)

| ID | Rule | How to confirm | ☐ |
|----|------|----------------|---|
| OWN-1 | Finance owns money | L17 totals are SoT; L18 `monetarySource=organizer_finance` | |
| OWN-2 | Analytics / Reporting consume | L18/L21 match L17/L16/L15 for same event/filters | |
| OWN-3 | Compliance governs lifecycle | L27 does not hard-delete ledgers | |
| OWN-4 | Automation / Integrations transport | L23/L24 do not become second ticket/CRM/finance writers | |
| OWN-5 | Control Plane / Identity govern | L28/L29 do not replace Auth IdP or reinvent RBAC | |

---

# 4. Explicit exclusions (do not include in this cycle)

| Area | Do not test as product |
|------|------------------------|
| Scheduled publish **job** | Metadata gate only |
| Maybe RSVP | Not in enum |
| Invitation CSV / SMS-WhatsApp guest CRM | Deferred |
| Camera hardware QR package | Paste/code only |
| Walk-in sales / multi-gate / emergency broadcast | Deferred |
| Page views / UTM / ML analytics | Unavailable honesty |
| Promo codes / tax engine / multi-currency redesign | Deferred |
| Legal e-sign / DAM / AI negotiation | Deferred |
| Report PDF/history/scheduler | Deferred |
| Visual automation builder / Bull-Redis | Deferred |
| Salesforce / Drive / GA / multi-PSP redesign | Deferred |
| Organizer Flutter Integrations screen as primary Hub | Super-admin Hub + org APIs |
| Device MDM enrollment | Honest Unavailable |
| SSO federation / API keys / SDK / AI Studio / i18n | Post-cert roadmap |

---

# 5. Sign-off

| Pack | Tester | Date | Result |
|------|--------|------|--------|
| Phases 14–18 operational loop | | | PASS / FAIL |
| Phases 19–29 business ops | | | PASS / FAIL |
| Ownership assertions OWN-1…5 | | | PASS / FAIL |

**References:** Phase 13–19 & 21–29 completion reports; `docs/PHASE30_FINAL_CERTIFICATION_REPORT.md`; `docs/evidence/phase30_final_certification_run.json`.
