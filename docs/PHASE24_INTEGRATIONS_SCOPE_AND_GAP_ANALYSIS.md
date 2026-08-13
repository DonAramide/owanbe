# PHASE 24 — INTEGRATIONS & EXTERNAL SERVICES — SCOPE DEFINITION & GAP ANALYSIS

**Date:** 2026-08-01  
**Method:** Architecture-derived (Phases 11–23 + live code audit) — not feature-wishlist  
**Constraint:** Scope definition only — **no implementation**, no application code changes beyond this document  
**Stabilization Mode:** Phases **14–22** architecture-frozen pending integrated Live QA — consume only  
**Business Operations Layer:** Phases **19–25** form one integrated layer; **one integrated Live QA after Phase 25**  
**Integration rule:** Integrations **extend** existing capabilities. They must **not** replace Payments, Notifications, Finance, CRM, Reporting, or Automation. They must **not** invent business data.

---

## 1. Executive verdict

| Dimension | Finding |
|-----------|---------|
| **Prior phase outcome** | Internal Business Ops loop is complete through Automation (23) |
| **Proposed domain** | Integrations & External Services — **correct next capability** |
| **Prior roadmap** | Automation (23) → **Integrations (24)** → Hardening (25) |
| **Natural Phase 24** | Connect trusted external providers to existing Notification / Payment / Automation / Reporting surfaces |
| **IA** | Primary = Platform / Super-admin **Integrations Hub** (API-backed); secondary = Organizer-visible connection status where relevant; do **not** promote Flutter `integration_engine.dart` mocks as truth |
| **Overall** | **✅ Phase 24 Scope Defined** |

Nothing else should precede Integrations in the Business Ops layer. Hardening (25) needs stable external boundaries (secrets, webhooks, retries). Automation (23) already emits events and calls `NotificationService` — Integrations productize **how** those calls leave the platform.

---

## 2. Why Integrations follow Automation

```
Internal business loop (Create → Operate → Finance → CRM → Report → Org)
        ↓
Automation (23) — when / if to act
        ↓
Integrations (24) — where / how external systems receive actions & send callbacks
        ↓
Hardening (25) — readiness, security, Live QA
```

Automation without Integrations still works via log/stub channels. Integrations make Automation, Invitations, Finance alerts, and Reporting **production-grade** by formalizing providers, secrets, webhooks, and failure handling — without rewriting domain rules.

---

## 3. Phase definition

### Official Phase Name

**Phase 24 — Integrations & External Services**

### Business Goal

Give the platform a governed way to connect **payment, messaging, storage, and outbound webhook** providers so organizers and operators can communicate, settle, and sync with the outside world — while Owambe remains the system of record.

### Technical Goal

Establish an **Integration Layer** with:

1. **Provider adapter pattern** (generalize email’s existing approach).  
2. **Secrets management** (extend `EmailSecretsCrypto` patterns; stop relying only on process env for new providers).  
3. **Inbound webhooks** (Quaser pattern) + **outbound webhooks** (wire or replace unused `043` hub tables).  
4. **Configuration / health / audit** for Super-admin (replace Integration Hub mocks with Nest APIs).  
5. **Consume** Automation, NotificationService, Payment, Reporting — never fork them.

### Primary User Journeys

| ID | Journey |
|----|---------|
| J1 | Super-admin configures email provider (already real) and verifies health |
| J2 | Super-admin configures SMS provider credentials (Twilio) via secured admin UI — not env-only tribal knowledge |
| J3 | Platform receives Quaser payment webhook → existing finance/ticket capture (unchanged) |
| J4 | Automation / Notification action → outbound provider with retries + delivery audit |
| J5 | Organizer/platform registers outbound webhook URL for `ticket.issued` / `rsvp.changed` → signed POST + retry |
| J6 | Super-admin views Integration Hub: live provider status (not hardcoded Stripe/Salesforce cards) |
| J7 | Failure path: provider down → retry → DLQ/log → audit; business order/RSVP state unchanged |

### Success Criteria

- [ ] No parallel payment ledger or parallel guest/CRM stores  
- [ ] Quaser remains primary payment path unless a second PSP is explicitly approved  
- [ ] Email adapter pattern reused for SMS (and later WhatsApp)  
- [ ] Outbound webhooks signed, tenant-isolated, audited  
- [ ] Integration Hub UI backed by Nest (mock registry retired or clearly labeled Unavailable)  
- [ ] Secrets encrypted at rest; not logged  
- [ ] Automation continues to call NotificationService / Reports — Integrations sit underneath  
- [ ] Frozen domains consume-only except approved thin adapter hooks  

---

## 4. Business context — which external connections create value

| Internal capability | External connection that adds value | Priority |
|---------------------|-------------------------------------|----------|
| Tickets / Payments | Quaser (live) + settlement visibility | **P0** harden |
| Invitations / Automation notifies | Email (live) + SMS (partial) | **P0** |
| Guest messaging (NG market) | WhatsApp Business | **P1** |
| Finance alerts / Ops digests | Email/SMS + outbound webhooks | **P0–P1** |
| Media / branding | Supabase Storage (live) | **P1** polish |
| Vendor scheduling | External Google/Apple Calendar | **P2** (internal calendar exists) |
| Accounting / Salesforce | External CRM/books | **P2 / defer** |
| GA / Mixpanel | External analytics | **Defer** (first-party Analytics exists) |
| Social share APIs | Meta/Twitter APIs | **Defer** (clipboard share enough) |

**Do not prioritize:** Rebuilding Integration Hub cosmetics, multi-PSP before Quaser hardening, Drive/Dropbox, or inventing engagement pixels.

---

## 5. Codebase audit (classification)

| Capability | Classification | Evidence |
|------------|----------------|----------|
| **Payment Gateways (Quaser)** | **Fully Implemented** (product path) | `QuaserRouterService`, ticket/payout capture, ledger |
| **Bank Settlement Providers** | **Partially Implemented** | Vendor bank accounts, Quaser payouts, treasury settlements |
| **Paystack / Stripe** | **Not Implemented** (runtime) | Hub SQL/Flutter mocks only |
| **Email Providers** | **Fully Implemented** (platform) | `048` + `EmailService` / transport adapter / Super-admin UI |
| **SMS Providers** | **Partially Implemented** | Twilio in `NotificationService`; env-config; no admin UI |
| **WhatsApp Business API** | **Not Implemented** | Channel enums / clipboard share only |
| **Push (FCM/APNs)** | **Backend Only / stub** | Log-only push channel |
| **Calendar Sync (Google/Apple)** | **Not Implemented** | Internal vendor calendar Fully elsewhere |
| **Cloud Storage (Supabase)** | **Partially Implemented** | `StorageService` / media API; no Drive/Dropbox |
| **Inbound Webhooks** | **Partially Implemented** | Quaser signed webhook live |
| **Outbound Webhooks** | **Not Implemented** (product) | Env notify/alert URLs; `043` tables unused |
| **OAuth (user login)** | **Partially Implemented** | Supabase Google OAuth for identity |
| **API keys / Integration Hub keys** | **Frontend Only / mock** | Flutter generates fake keys; no Nest persistence |
| **Secrets Management** | **Partially Implemented** | Email AES-GCM vault; other providers = env |
| **Analytics integrations (GA)** | **Not Implemented** | First-party Analytics only |
| **CRM / Accounting external** | **Not Implemented** | Internal Vendor CRM Fully |
| **Social sharing** | **Frontend Only** | Copy / mailto / WhatsApp text |
| **Import/export** | **Partially Implemented** | First-party CSV/reports/guest import — not SaaS sync |
| **Integrations Hub admin** | **Frontend Only** (mock) + **Backend** email/mode real | `integration_engine.dart` vs Enterprise Email screen |
| **Retry / failure / audit** | **Partially Implemented** | Email retries + `notification_deliveries`; no outbound webhook DLQ |

---

## 6. Existing vs missing (summary)

### Existing (keep / harden)

- Quaser payments + inbound webhook  
- Enterprise Email Infrastructure (adapter + encrypted secrets + audit)  
- SMS Twilio hook inside NotificationService  
- Supabase/local media storage  
- `INTEGRATIONS_MODE` + health detail checks  
- Phase 23 Automation → Notification / Reports  
- Phase 21 Reporting exports (first-party)  
- Internal Vendor Calendar  

### Missing (Phase 24 candidates)

| Gap | Priority |
|-----|----------|
| API-backed Integrations Hub (retire mock registry) | **P0** |
| Outbound signed webhooks + retry/DLQ (activate `043` or thin replacement) | **P0** |
| SMS provider admin + secrets (mirror email) | **P0** |
| Unified delivery failure visibility for Super-admin | **P0** |
| WhatsApp Business adapter under NotificationService | **P1** |
| Tenant-scoped provider overrides (optional) | **P1** |
| Real push (FCM/APNs) | **P1–P2** |
| Second PSP (Paystack) only if approved | **P2 / decision** |
| Google Calendar sync | **P2** |
| External CRM/accounting | **Defer** |
| GA/Mixpanel | **Defer** |

---

## 7. Integration architecture recommendation

```
┌─────────────────────────────────────────────────────────┐
│  Domain Services (frozen) + Automation Engine           │
│  Payments · Invites · CRM · Finance · Reports · Team    │
└───────────────────────────┬─────────────────────────────┘
                            │ emit / call
┌───────────────────────────▼─────────────────────────────┐
│  Integration Layer (Phase 24)                           │
│  • Provider Registry (type, enabled, health)            │
│  • Adapter interface (send / verifyWebhook / health)    │
│  • Secrets vault (encrypt at rest)                      │
│  • Outbound dispatcher (retry, backoff, DLQ)            │
│  • Inbound webhook router (signature verify → domain)   │
└───────────────┬─────────────────────────┬───────────────┘
                │                         │
     External Providers              Audit / Logs
     Email · SMS · WhatsApp          email_provider_audit
     Quaser · Storage                notification_deliveries
     Partner webhooks                platform_webhook_logs
```

### Provider Adapter Pattern

| Concern | Recommendation |
|---------|----------------|
| Interface | `send(command)`, `health()`, optional `verifyWebhook(req)` |
| Precedent | Email `deliverViaProvider` by `provider_type` |
| Payments | Keep Quaser as dedicated adapter; do **not** force Quaser into generic notify interface |
| Messaging | Email / SMS / WhatsApp adapters behind `NotificationService` |
| Config | DB registry + encrypted secrets (email model) |
| Retries | Provider-level (email today) + outbound webhook worker |
| Failures | Status on delivery/webhook log; **never** roll back domain truth |
| Logs / Audit | Reuse `email_provider_audit`, `notification_deliveries`; add webhook logs |
| Webhooks inbound | Quaser pattern: verify signature → idempotent domain apply |
| Webhooks outbound | Sign body (HMAC), retry with backoff, DLQ after N |

### Authentication & secrets

| Kind | Approach |
|------|----------|
| Provider API keys / SMTP passwords | Encrypt with platform key (`EmailSecretsCrypto` pattern) |
| Quaser | Keep env for MVP **or** migrate to vault in same phase if approved |
| OAuth for Google Calendar | Separate connector tokens; do not overload user login OAuth |
| Tenant isolation | Prefer platform providers first; tenant overrides only with explicit RLS/ownership checks |
| Organization access | Organizer sees connection **status**, not raw secrets |

---

## 8. Security audit

| Area | Current | Phase 24 requirement |
|------|---------|----------------------|
| API keys | Env + email ciphertext | No plaintext in logs/UI; rotate support |
| OAuth tokens | Supabase user login only | Calendar connectors isolated |
| Secrets | Email vault good; SMS/Quaser env | Extend vault; restrict admin roles |
| Permissions | Super-admin email admin | Same matrix for Integrations Hub APIs |
| Tenant isolation | Email mostly platform (`tenant_id IS NULL`) | Document platform-first; tenant overrides gated |
| Organization access | N/A for secrets | Members never read provider secrets |
| Audit logging | Email + notification deliveries | Mandatory for secret changes & webhook deliveries |
| Webhook authenticity | Quaser signature | Require signature on all inbound; HMAC on outbound |

**STOP if** Phase 24 would require redesigning Quaser settlement rules or Notification business templates as a second stack — document and wait for approval.

---

## 9. Reuse analysis

| Module | Reuse | Do not |
|--------|-------|--------|
| **Automation Engine** | Emit events; schedule delivery jobs | Put HTTP provider code inside Automation |
| **NotificationService** | Single outbound messaging facade | Parallel mailer/SMS in Hub |
| **Finance / Quaser** | Existing capture + inbound webhook | Second ledger |
| **Reporting** | First-party exports | External BI as source of truth |
| **Vendor CRM** | Internal CRM events for outbound webhooks | Salesforce as CRM truth |
| **Analytics** | First-party | Invent GA metrics inside Owambe |
| **Payment Services** | Quaser router | Fake Paystack cards as live |
| **Webhook systems** | Quaser controller pattern; `043` tables if fit | Flutter-only simulator as production |
| **Background jobs** | Automation due-jobs / finance timeout pattern | Bull by default |
| **Email infra** | Transport + secrets + audit | Rebuild email from scratch |
| **IntegrationsModeService** | Environment gate | Remove production safeguards |

---

## 10. Dependencies

| Dependency | Relationship |
|------------|--------------|
| **Automation (23)** | Soft–Hard — outbound actions already call notify/report |
| **NotificationService** | **Hard** |
| **Finance / Quaser** | **Hard** for payment webhooks |
| **Reporting** | Soft |
| **Vendor CRM / Invitations** | Soft — event sources for outbound webhooks |
| **Organization** | Soft — who may see connection status |
| **Workspace / Event** | Soft |
| **Secrets encryption key** | **Hard** — env already required for email |
| **Frozen domains 14–22** | Consume only |

---

## 11. Risks

| Risk | Mitigation |
|------|------------|
| Scope expands to every SaaS in the mock hub | Prioritize messaging + webhooks + Quaser harden |
| Treating Flutter Integration Hub as live | Replace with Nest-backed status |
| Second PSP without settlement design | Quaser-only unless approved |
| Secrets in logs | Audit + redaction tests |
| Outbound webhooks mutating partners into source of truth | Webhooks are notifications of Owambe facts |
| WhatsApp compliance / templates | P1 with explicit template governance |
| Redesigning Automation | Integrations sit **under** Notification actions |

---

## 12. Implementation effort

| Module | Effort | Notes |
|--------|--------|-------|
| Nest Integrations Hub API + retire mocks | **Medium** | |
| Outbound webhooks + retry/DLQ | **Medium–Large** | |
| SMS admin + secrets (email pattern) | **Medium** | |
| Quaser webhook/docs harden | **Small–Medium** | |
| WhatsApp adapter | **Large** | Compliance heavy |
| Second PSP | **Large** | Defer |
| Google Calendar | **Medium–Large** | Defer |
| Push FCM/APNs | **Medium–Large** | |

**Overall Phase 24 (P0–P1):** **Medium–Large**  
**With multi-PSP + WhatsApp + Calendar + Hub cosmetics:** **Large** — do not default into scope  

---

## 13. Completion Sprint roadmap (proposed)

### Sprint A — Truth over mocks (P0)

1. Nest Integrations registry/health API (email, SMS, Quaser, storage status).  
2. Super-admin Hub reads Nest — mark unavailable cards Unavailable.  
3. Document Quaser inbound webhook as canonical payment callback.

### Sprint B — Messaging & secrets (P0)

4. SMS provider admin + encrypted secrets (mirror email).  
5. Unified delivery failure view (`notification_deliveries` + email audit).  
6. Ensure Automation notify actions use configured providers only.

### Sprint C — Outbound webhooks (P0–P1)

7. Activate outbound webhook subscriptions (reuse `043` if fit).  
8. Sign + retry + DLQ; subscribe to Automation/domain events.  
9. Audit trail for deliveries.

### Sprint D — Optional P1

10. WhatsApp Business adapter behind NotificationService.  
11. Tenant provider overrides (if approved).  
12. Explicit defer: Paystack/Stripe, GA, Salesforce, Drive, visual marketplace.

---

## 14. Architecture question — canonical Integration lifecycle

```
Internal Business Event
        ↓
Automation / Integration Layer
        ↓
External Provider
        ↓
Response / Webhook
        ↓
Internal Business System
        ↓
Audit Log
```

### Modules reused at each step

| Step | Reused modules |
|------|----------------|
| **Internal Business Event** | Domain emits from Tickets, Invitations, CRM, Refunds, Reports (Phase 23); Finance Quaser callbacks |
| **Automation / Integration Layer** | `AutomationEngineService` actions → `NotificationService`; Phase 24 adapters + outbound dispatcher |
| **External Provider** | Email transports, Twilio SMS, Quaser HTTP, Supabase Storage; future WhatsApp adapter |
| **Response / Webhook** | Quaser inbound webhook controller; outbound partner acknowledgements |
| **Internal Business System** | Existing capture / payout / invite / CRM services — **unchanged rules** |
| **Audit Log** | `AuditLogService`, `email_provider_audit`, `notification_deliveries`, webhook logs |

**Invariant:** External systems never become the ledger, guest list, or CRM stage authority. Owambe remains system of record; providers deliver or confirm.

---

## 15. Out of scope (explicit)

- Building provider-specific implementations in this **scope** document (audit only)  
- Replacing Quaser with Paystack/Stripe without approval  
- Redesigning Finance, Automation, Notification facades  
- Treating Integration Hub Flutter mocks as production  
- External analytics/CRM/accounting as primary truth  
- Inventing business metrics from provider dashboards  

---

## 16. Final result

**✅ Phase 24 Scope Defined**
