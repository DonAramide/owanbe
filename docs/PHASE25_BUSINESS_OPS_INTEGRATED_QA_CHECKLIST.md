# PHASE 25 — BUSINESS OPERATIONS INTEGRATED QA CHECKLIST

**Status:** Prepared for Integrated Live QA Planning (not executed in this sprint)  
**Covers:** Phases 19–25  
**Migrations required:** `055`, `056`, `057`, `058`

---

## Environment gate

- [ ] API + DB up; migrations 055–058 applied  
- [ ] Enterprise email provider configured (or document Unavailable)  
- [ ] `INTEGRATIONS_MODE` documented; production mode has Quaser URL + webhook secret  
- [ ] Test organizer with Owner / Admin / Manager / Staff members  

---

## Critical journeys

| ID | Journey | Pass? |
|----|---------|-------|
| J1 | Ticket purchase → Finance summary → Report finance pack (totals agree) | |
| J2 | Invite → RSVP → Automation run → Notification delivery visible | |
| J3 | Vendor CRM stage → Automation → outbound webhook delivery | |
| J4 | Org invite → accept → access; staff denied finance APIs (`ORG_CAPABILITY_DENIED`) | |
| J5 | Register webhook → domain event → delivery success / retry / DLQ | |
| J6 | Quaser inbound payment still settles tickets/finance | |
| J7 | Analytics finance KPIs match Finance summary (`monetarySource=organizer_finance`) | |
| J8 | Refund → automation/integration without ledger corruption | |

---

## Regression matrix (frozen domains)

| Domain | Smoke | Pass? |
|--------|-------|-------|
| Auth / RBAC / workspace switching | Login + portal switch | |
| Events / publishing | Open manage event | |
| Ticketing / payments | Create order / capture path | |
| Invitations | Send + RSVP | |
| Live Operations | Door summary (staff OK) | |
| Finance | Hub + event summary (staff denied) | |
| Analytics | Event intelligence loads | |
| Vendor CRM | List requests (staff denied) | |
| Reporting | Catalog + export | |
| Organization | Team directory | |
| Automation | Definitions + runs + observability | |
| Integrations | Hub registry + webhook list | |

---

## Production readiness checklist

- [ ] Org capabilities enforced on finance / analytics / reports / vendors / automations / integrations / door  
- [ ] Finance owns money; Analytics consumes monetary truth  
- [ ] Notification statuses: queued → sent/delivered / retrying / dead_letter  
- [ ] Webhook secrets ciphertext at rest  
- [ ] Health includes automation, webhooks, notifications  
- [ ] UX: Automations / Team / Hub show retry on errors  
- [ ] Phase 20 Marketing remains Unavailable  

---

## Script

See `scripts/phase25_business_ops_live_qa.mjs` (scaffold — superseded for certification execution).

**Superseded by Phase 30:** use `docs/PHASE30_PLATFORM_CERTIFICATION_CHECKLIST.md` and `scripts/phase30_platform_certification_qa.mjs` for Integrated Live QA + certification evidence.
