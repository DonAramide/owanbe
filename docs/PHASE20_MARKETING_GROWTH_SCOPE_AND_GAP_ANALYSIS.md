# PHASE 20 — MARKETING & GROWTH — SCOPE DEFINITION & GAP ANALYSIS

**Date:** 2026-08-01  
**Method:** Architecture-derived (Phases 11–19 + live code audit) — not feature-wishlist  
**Constraint:** Scope definition only — **no implementation**, no application code changes beyond this document  
**Architecture freeze:** Phases **14–19** are frozen pending Live QA — Phase 20 may **consume** Publishing, Ticketing, Invitations, Door Ops, Finance, Analytics, and Vendor CRM only; it must not redesign them  
**Prerequisite:** Phase 19 Live QA / Certification (or explicit waiver)

---

## 1. Executive verdict

| Dimension | Finding |
|-----------|---------|
| **Prior phase outcome** | Organizer can create, publish, sell, invite, operate door, settle finance, measure performance, and hire vendors |
| **Proposed domain** | Marketing & Growth — **correct next Organizer capability** |
| **Prior roadmap** | Phase 18 scope already numbered Marketing → **20** (after Analytics 18, Vendor CRM 19) |
| **Natural Phase 20** | Campaign / audience / promo growth layer that **consumes** guests, buyers, notifications, Discover, Analytics — not a parallel CRM or analytics warehouse |
| **IA** | Primary = Organizer Marketing surface (new thin module or Event Workspace Marketing tab); secondary = reuse Super-admin Communication Center patterns carefully (do not promote platform mocks as organizer truth) |
| **Overall** | **✅ Phase 20 Scope Defined** |

---

## 2. Business flow review — next missing capability

```
Create (12) → Tickets (13) → Publish/Sell (14) → Invite (15)
    → Door (16) → Finance (17) → Analytics (18) → Vendor CRM (19)
    → ??? Grow attendance & sales
```

| After Phase 19 | Organizer can… | Still missing |
|----------------|----------------|---------------|
| Run & staff an event | Operate hire + ticket loops | **Outbound growth**: reach past guests/buyers, promote listings, measure campaign → ticket conversion |
| Analytics | See sales/RSVP/attendance honesty | Attribute growth actions to conversions |
| Invitations | Guest-list RSVP messaging | Bulk **marketing** campaigns beyond invite tokens |
| Discover | Organic listing visibility | Paid/organic promo, referral, discount-driven acquisition |

**Next missing business capability:** Organizer-facing **Marketing & Growth** — answer “how do we fill the room and sell more tickets using audiences we already have?” by composing notifications, invitations data, Discover, ticket commerce, and Analytics — without inventing a second guest/buyer truth.

### Alternative progression check

| Candidate | Why not Phase 20 (now) |
|-----------|-------------------------|
| **Deeper Vendor payouts / accounting** | Vendor OS money track; does not grow attendee demand; follows CRM accept truth later |
| **Attendee CRM depth** | Guests already Phase 15; marketing campaigns are the growth use of that data |
| **AI / ML recommendations** | Explicitly deferred; needs campaign + analytics substrate first |
| **Keep Marketing later** | Roadmap and Phase 11–18 docs already slot it after Analytics + CRM; growth is the natural organizer ask after operations exist |
| **Promo codes only as a micro-phase** | Valid **P0 slice** inside Marketing — insufficient alone as the whole phase name |

**Justification:** Phases 11–19 closed **operate**. Marketing is the **grow** loop. It depends on truthful audiences (guests, buyers) and truthful conversion (Analytics + Orders). Those prerequisites are met. Vendor CRM was correctly sequenced first so hire ops do not collide with growth workstreams.

---

## 3. Phase 20 definition

### Official Phase Name

**Organizer Marketing & Growth**

*(Working short name: Marketing)*

### Business goal

Give organizers a trustworthy way to **reach audiences**, **run campaigns**, **offer promotions**, and **see conversion into tickets/RSVPs** — using existing guests, buyers, notifications, Discover, Finance, and Analytics — without inventing parallel audience or conversion systems.

### Technical goal

Productize growth as a **consumer layer**:

1. Define organizer **Audience** as read models over guests + ticket buyers (+ optional Discover followers if present) — no second CRM table of truth  
2. Add **Campaign** records that dispatch via existing `NotificationService` / invitation channels where appropriate  
3. Add **Promo codes / referral links** into Ticket Commerce apply path (schema currently absent) without redesigning order lifecycle  
4. Measure opens/clicks/delivery from notification delivery logs where available; attribute ticket conversion via Analytics/Orders **read-only**  
5. Mount a thin Organizer Marketing surface + deep-links into Analytics / Discover / Invitations  
6. Do **not** redesign frozen phases; do **not** promote Super-admin Communication Center mocks as organizer production CRM  

### Primary user journeys

| # | Journey |
|---|---------|
| J1 | Organizer builds audience from event guests / past buyers → sends email (or SMS) campaign |
| J2 | Organizer schedules campaign; sees draft / sent / failed delivery status |
| J3 | Organizer creates promo code → buyer applies at checkout → order reflects discount |
| J4 | Organizer shares referral / event Discover link → Analytics shows sales lift honesty |
| J5 | Organizer opens campaign analytics: delivery, RSVP conversion, ticket conversion (from canonical sources) |

### Success criteria

- Organizer Marketing surface exists (dashboard strip and/or Event Workspace module)  
- Audiences compose from **canonical** guests/buyers — no duplicate audience warehouse  
- Campaigns send through existing notification rails (or clearly Unavailable per channel)  
- Promo/referral either **real** on commerce path or **Unavailable** — no fake conversion UI  
- Campaign metrics consume notification deliveries + Analytics/Orders — never invent open/click rates  
- Phases 14–19 untouched except consume / deep-link  
- No AI negotiation, no Vendor CRM redesign, no second Discover engine  

### Why this follows Phase 19

Vendor CRM closed the **hire** loop. Organizers next ask how to **grow demand**. Analytics (18) made conversion measurable; Invitations (15) and Ticketing (13–14) supply audiences and purchase paths; Notifications provide delivery. Marketing is the orchestration layer over those truths.

---

## 4. Classification legend

| Label | Meaning |
|-------|---------|
| **Fully Implemented** | End-to-end usable with real data on live organizer path |
| **Partially Implemented** | Meaningful pieces; gaps block Phase 20 completeness |
| **Implemented but Hidden** | Built; not on organizer Marketing route |
| **Backend Only** | API/DB ready; insufficient organizer UX |
| **Frontend Only** | UI present; API stubbed/mocked/synthesized |
| **Not Implemented** | No meaningful product implementation |

---

## 5. Feature breakdown & codebase audit

| Feature | Classification | Evidence |
|---------|----------------|----------|
| **Campaign Dashboard** | **Not Implemented** (organizer) | No organizer Marketing nav (`eos_role_destinations` / Event modules). Super-admin `CommunicationCenterScreen` is a separate platform UI with in-memory `communicationEngineProvider` |
| **Email Campaigns** | **Partially Implemented** (infra) / **Not Implemented** (organizer product) | `NotificationService` + `EmailService` transactional send; invitation email path; ECP `communication_templates` seeded in `041_enterprise_communications.sql` — **no Nest organizer campaign API** using those tables |
| **WhatsApp Campaigns** | **Not Implemented** (product) | Invitation channel enum includes `whatsapp` (`038`); ECP prefs `allow_whatsapp`; no organizer blast product |
| **SMS Campaigns** | **Partially Implemented** (infra) | `NotificationService` SMS (Twilio/webhook/log); invitation `sms` channel — no campaign scheduler UX |
| **Push Notifications** | **Partially Implemented** (infra) | Channel `push` on NotificationService + in-app `notifications` table used by CRM/ops — not marketing campaign builder |
| **Audience Builder** | **Not Implemented** | No saved audience entity; guests (`event_guests`) + buyers (`ticket_orders`) exist as sources |
| **Saved Audiences / Segments** | **Not Implemented** (organizer) | Vendor mock “segments” in intelligence engine / Super-admin CRM mocks — not attendee marketing segments |
| **Campaign Templates** | **Backend Only** / **Hidden** | DB `communication_templates`; Flutter ECP engine holds in-memory templates; not organizer-facing |
| **Scheduled / Draft Campaigns** | **Not Implemented** | No campaign schedule tables for organizers; platform intelligence seed text mentions campaigns (`042`) as advice copy only |
| **Campaign History** | **Not Implemented** (organizer) | `notification_deliveries` + `communication_logs` schemas exist; not exposed as campaign history product |
| **Delivery Status** | **Partially Implemented** | Delivery rows on send; CRM/ops notifications; no campaign dashboard |
| **Open / Click / Conversion Rate** | **Not Implemented** | No open/click instrumentation for marketing; Analytics has ticket/RSVP conversion for events — reusable for attribution, not campaign pixel tracking |
| **RSVP Conversion** | **Fully Implemented** (Analytics consume) | Phase 18 invitation metrics — Marketing should **read**, not rebuild |
| **Ticket Conversion** | **Fully Implemented** (Analytics/Orders consume) | Phase 13–18 sales metrics — Marketing should **read** |
| **Promo Codes** | **Not Implemented** | Explicit Phase 13 deferral; no promo tables in `infra/db`; orders lack discount lines |
| **Referral Links** | **Not Implemented** | No referral entity; Discover/public event URLs exist as organic share targets |
| **Discount Campaigns** | **Not Implemented** | Depends on promo apply path |
| **A/B Campaigns** | **Not Implemented** | No experiment framework for organizer campaigns |
| **Organic Reach** | **Partially Implemented** | Discover / public publish (Phase 14); event website share URLs; `isFeatured` consumed by Discover but **no organizer featured/boost control** |
| **Campaign Analytics** | **Not Implemented** | Would compose Phase 18 Analytics + delivery logs |
| **Early-bird / sales windows** | **Partially Implemented** (pricing, not coupons) | Ticket tier `earlyBird` + sales start/end windows — reuse as simple promo levers until coupon schema exists |

### Related (not Marketing Phase 20 core)

| Surface | Classification | Notes |
|---------|----------------|-------|
| Day-of ops “Broadcast” | Ops command | `broadcastAnnouncement` — live event ops, freeze Phase 16; do not confuse with marketing blasts |
| Invitation send | Phase 15 | Guest RSVP messaging — audience source / channel reuse, not campaign suite |
| Super-admin Communication Center | Frontend Only / platform | Mock campaign list in UI — **do not** treat as organizer Marketing MVP without API honesty |

---

## 6. Existing implementation (keep / reuse)

| Layer | Assets |
|-------|--------|
| **Audiences (sources)** | `event_guests`, invitation RSVP status; `ticket_orders` / entitlements buyers; organizer event list |
| **Delivery** | `NotificationService`, `EmailService`, `notification_deliveries`, in-app `notifications` |
| **Channels (invite)** | `event_invitation_channel` email/sms/link/whatsapp |
| **Prefs / templates (ECP)** | `communication_templates`, `communication_preferences`, `communication_logs` (`041`) |
| **Conversion truth** | Phase 18 Analytics APIs; ticket sales summaries; invitation stats |
| **Organic** | Discover / public events (Phase 14) |
| **Money** | Phase 17 Finance (promo impact later as consume) |
| **UI shells** | Organizer Dashboard strip pattern; Event Workspace tab mount pattern; Super-admin Communication Center as UX reference only |
| **Closest shipped substrate** | Invitation Hub (templates, email send, share/RSVP links); Event Website; Publish → Discover visibility; Analytics RSVP/ticket conversion |

---

## 7. Missing implementation

| Gap | Priority for Phase 20 |
|-----|------------------------|
| Organizer Marketing IA (nav + workspace entry) | **P0** |
| Audience builder over guests + buyers | **P0** |
| Campaign create / draft / send (email first) via NotificationService | **P0** |
| Delivery status list from `notification_deliveries` | **P0** |
| Promo codes schema + checkout apply | **P0** |
| Campaign → ticket/RSVP conversion panel (consume Analytics/Orders) | **P1** |
| SMS / WhatsApp campaign channels (honest Unavailable if provider weak) | **P1** |
| Scheduled campaigns | **P1** |
| Referral links tied to Discover/event URLs | **P1** |
| Saved audiences | **P2** |
| Open/click tracking instrumentation | **P2** (or Unavailable) |
| A/B campaigns | **Defer** |
| Full WhatsApp Business productization | **Defer** |

---

## 8. Hidden implementation

| Asset | Status |
|-------|--------|
| ECP DB templates / prefs / logs | Schema present; no organizer Nest product surface found |
| Super-admin Communication Center + Flutter `CommunicationEngine` | Platform / mock — **Implemented but Hidden** from organizer Marketing |
| Invitation multi-channel enum | Hidden capacity for campaign channel reuse |
| Analytics conversion KPIs | Live for events; not wired as “campaign analytics” |

---

## 9. Reuse opportunities (do not duplicate)

| Capability | Reuse |
|------------|-------|
| Audience people | Guests + buyers — **not** a new identity graph |
| Send email/SMS/push | `NotificationService` / Email infrastructure |
| RSVP messaging patterns | Invitation services (tokenized invites remain Phase 15) |
| Conversion | Organizer Analytics + ticket orders |
| Organic share | Discover / public event routes |
| Finance impact of promos | Finance summary consume after promo apply |
| Dashboard strip / Workspace mount | Same patterns as Finance / Analytics / Vendors |
| ECP templates table | Prefer wiring Nest to DB over Flutter in-memory engine |

**Do not duplicate:** guest CRM, analytics warehouse, Discover engine, ticket order state machine, Vendor CRM.

---

## 10. Dependencies

| Dependency | Relationship |
|------------|--------------|
| **Analytics (18)** | Conversion & growth insights (read-only) |
| **Finance (17)** | Promo revenue impact honesty (read; apply discounts carefully on commerce) |
| **Invitations (15)** | Audience + channel patterns |
| **Orders / Ticket Sales (13–14)** | Conversion target; promo apply point |
| **Notifications** | Campaign delivery |
| **Profiles / prefs** | `communication_preferences.allow_marketing` respect |
| **Discover (14)** | Organic / referral destination |
| **Vendor CRM (19)** | **Out of Marketing core** — do not mix vendor hire blasts into attendee growth without explicit product decision |

---

## 11. Risks

| Risk | Mitigation |
|------|------------|
| Treating Super-admin Communication Center as done | Require Nest + organizer UX; mark mocks Unavailable |
| Parallel audience DB | Compose guests/buyers only |
| Inventing open/click rates | Show Unavailable until instrumentation exists |
| Promo codes breaking commerce freeze | Additive schema + apply on order create; stop for approval if order rules must change |
| Spamming guests ignoring prefs | Enforce `allow_marketing` / channel prefs |
| Scope explosion into A/B + WhatsApp Business | P0 email + promo; defer A/B |
| Confusing ops Broadcast with Marketing | Keep Phase 16 broadcast frozen as day-of ops |
| Touching frozen phases silently | Architecture freeze — document dependency + approval |

---

## 12. Implementation effort

| Workstream | Size |
|------------|------|
| Organizer Marketing shell + audience compose | **Medium** |
| Campaign send (email) + history via notifications | **Medium** |
| Promo codes + checkout apply | **Medium–Large** |
| Conversion panel (Analytics consume) | **Small–Medium** |
| SMS/WhatsApp campaign honesty | **Medium** |
| Open/click tracking | **Large** (defer) |
| A/B framework | **Large** (defer) |
| **Overall Phase 20 completion sprint** | **Large** |

---

## 13. Completion Sprint roadmap (definition only — do not implement yet)

### P0 — Grow with truth
1. Organizer Marketing entry (Dashboard strip + Event Workspace Marketing module/tab)  
2. Audience builder: event guests + ticket buyers (canonical IDs only)  
3. Campaign draft/send email via `NotificationService`; persist campaign metadata (new thin table OK if it references people, does not clone them)  
4. Delivery status from `notification_deliveries`  
5. Promo codes: schema + apply on ticket order create; organizer CRUD  
6. Respect marketing preferences  

### P1 — Channels & attribution
7. Schedule send  
8. SMS campaigns where Twilio/webhook configured; else Unavailable  
9. Referral / share links to Discover or public event URL  
10. Campaign results panel: delivery counts + ticket/RSVP conversion from Analytics/Orders  
11. WhatsApp: reuse invitation channel only if delivery path real; else Unavailable  

### P2 — Depth
12. Saved audiences  
13. Templates UI over `communication_templates`  
14. Open/click if instrumented  
15. Discount campaign wrappers over promo codes  

### Explicitly out of Phase 20
- Redesign of Publishing / Ticketing / Invitations / Door / Finance / Analytics / Vendor CRM  
- AI creative / ML audience scoring  
- Full ESP (Mailchimp replacement)  
- A/B multi-variant engine  
- New Discover ranking marketplace ads (unless thin “boost” later)  

---

## 14. Architecture question — canonical Marketing lifecycle

**What is the canonical Marketing lifecycle after Phase 20?**

```
Audience                         (compose event_guests + ticket buyers;
                                  optional Discover interest — read-only)
        │
Campaign                         (organizer campaign record: draft/scheduled/sent)
        │
Delivery                         (NotificationService / invitation channels;
                                  notification_deliveries + prefs)
        │
Engagement                       (opens/clicks if instrumented;
                                  else Unavailable — do not invent)
        │
Conversion                       (RSVP via Invitations; ticket purchase via Orders)
        │
Ticket Purchase                  (Ticket Commerce — frozen apply path + promo)
        │
Finance                          (Phase 17 summary consumes discounted totals)
        │
Analytics                        (Phase 18 read-only performance + campaign panel)
        │
Growth Insights                  (Marketing UI composing delivery + Analytics —
                                  never a second warehouse)
```

### Modules reused at each step

| Step | Modules |
|------|---------|
| Audience | Event Guests, Ticket Orders/Entitlements |
| Campaign | New thin Marketing service **orchestrating** existing send rails |
| Delivery | `NotificationService`, Email infra, invitation channels |
| Engagement | Delivery logs (+ future instrumentation) |
| Conversion / Purchase | Invitations RSVP + Ticket Commerce |
| Finance | Organizer Finance summary (consume) |
| Analytics / Growth Insights | Organizer Analytics APIs + Marketing results UI |

**Marketing is a consumer.** It must never become a second source of truth for guests, orders, money, or performance.

---

## 15. Deliverables checklist (this document)

| # | Section | Status |
|---|---------|--------|
| 1 | Recommended Phase title | **Organizer Marketing & Growth** |
| 2 | Business objective | Grow attendance & ticket sales via campaigns/promos |
| 3 | Technical objective | Consumer layer over notifications + audiences + commerce + analytics |
| 4 | Feature breakdown | §5 |
| 5 | Existing implementation | §6 |
| 6 | Missing implementation | §7 |
| 7 | Hidden implementation | §8 |
| 8 | Reuse opportunities | §9 |
| 9 | Dependencies | §10 |
| 10 | Risks | §11 |
| 11 | Completion Sprint roadmap | §13 |

---

## 16. Final result

**✅ Phase 20 Scope Defined**

**STOP.** Do not implement Phase 20. Do not modify application code from this document. Await Phase 19 Live QA / Certification (or waiver) before any Marketing Completion Sprint. Respect architecture freeze on Phases 14–19.
