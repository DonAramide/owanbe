# Owambe — Full Project State Audit

**Date of audit:** 2026-10-07  
**Mode:** Read-only discovery. No code, database, migration, seed, or git mutation was performed by this audit.  
**Repo:** `C:\Users\HorizonPay\IIPS\owambe`  
**Branch inspected:** `rv_code` at `72f2eab` (up to date with `origin/rv_code`)  
**Database inspected:** Docker `owanbe-postgres`, database `owanbe`, host port `5436` (read-only `SELECT` / counts only)  
**API observed already running:** `GET http://127.0.0.1:8080/health` returned `status=ok` (this audit did not start it)

This document reconstructs state from repository files, git history, the live local database, and Cursor agent transcripts on this machine. It does not treat the newest phase number as the stopping point.

---

## 1. Executive summary

Development stopped on **2026-09-03**, when commit `72f2eab` was pushed to `origin/rv_code`. That commit ships Vendor Services/Rentals phases 1–4, legacy taxonomy edit, marketplace refinement, vendor availability calendar UI, CRM Server-Sent Events, and related docs/tests. Nothing product-meaningful is uncommitted.

The product phase ladder **1–30 is implemented in code and, for the API harness, certified on 2026-08-03** (`docs/PHASE30_FINAL_CERTIFICATION_REPORT.md`: 39 PASS / 0 FAIL). The **manual Live QA checklist was never signed**. Phases 14–18 completion reports still say Live QA is pending. A later operator track (Cursor, 27–29 Aug 2026) started a **separate Vendor Services & Rentals QA** and stopped **inside Pack 5 — Create Service**, after a UX refinement and before that pack was recorded as passed.

**Do not start a new phase. Do not continue by re-implementing taxonomy, marketplace, or CRM. Resume at Pack 5 on the existing vendor `invify638@gmail.com`.**

That vendor still has **legacy** category/services and **zero** new capability assignments and **zero** offering-category selections. Super Admin taxonomy definitions exist. Rental catalogue and rental bookings are empty.

---

## 2. How to read the phase numbers

The repository contains several numbering systems. They are not one sequence.

| Track | When | What it is | Do not confuse with |
|-------|------|------------|---------------------|
| Launch / RC / Event OS (`docs/phase6-platform-admin-report.md`, `docs/phase41/`, `docs/phase42/`, `docs/phase43/`, `docs/RC_PHASE_*`) | May–Jun 2026 | Early platform, treasury, admin, launch | Attendee phases 2–10 |
| Attendee workspace phases 2–10 | 24–25 Jul 2026 | Discover through post-event | Vendor “Phase 2” availability work |
| Organizer phases 11–18 | 27 Jul–1 Aug 2026 | Dashboard through analytics | Frozen by `docs/ARCHITECTURE_FREEZE_PHASES_14_18.md` |
| Business-ops phases 19–25, then 26–30 | 1–3 Aug 2026 | CRM, reporting, org, automation, integrations, hardening, marketing, compliance, control plane, identity, certification | Vendor Services/Rentals phases 1–4 |
| Vendor availability + intermediary (called Phase 2, 2B, 3A–3D in chats) | 17–21 Aug 2026 | Capabilities, calendar, CRM SSE, change requests | Attendee Phase 2 or Services/Rentals Phase 2 |
| Vendor Services & Rentals phases 1–4 | 25–29 Aug 2026 | Taxonomy `071`–`073`, marketplace, vendor-as-buyer | Platform phases 1–4 |

Phase 20 was **scoped and then skipped**. Marketing shipped later as **Phase 26**. There is a Phase 20 scope document and a Phase 26 completion report. There is no Phase 20 completion report.

---

## 3. Exact stopping points

| Question | Evidence-based answer |
|----------|------------------------|
| Where did implementation stop? | Commit `72f2eab` (2026-09-03): vendor taxonomy, offerings, marketplace buyer mode, legacy edit UX, calendar, CRM SSE. Working tree after that is only a one-line `package-lock.json` name case change plus untracked APKs and secret env files. |
| Where did platform Live QA stop? | API harness: **FULL PLATFORM CERTIFIED** on 2026-08-03. Manual checklist `docs/PHASE30_MANUAL_LIVE_QA_CHECKLIST.md` sign-off table is **blank**. Dedicated Live QA reports exist only for Phases **10, 11, and 12**. |
| Where did Vendor Services QA stop? | Cursor transcript `a69ad1b7-11ea-4207-a91d-21b6b2f9f7eb`, user message **2026-08-29 00:09**: active QA, **Pack 5 — Create Service**, Vendor Seller workspace. A UX-only stepped Business Type & Offerings flow was then implemented and later committed. No repository document marks Pack 5 PASS. |
| Current phase to resume | Not a new platform phase. **Vendor Services & Rentals QA, Pack 5.** Platform phases 1–30 stay closed unless a regression appears. |
| Current pack | **Pack 5 (Create Service)** is the incomplete pack. Packs 3 and 4 were explicitly skipped in chat on 2026-08-27. |

---

## 4. Git state

| Item | Value |
|------|--------|
| Current branch | `rv_code` tracking `origin/rv_code` |
| HEAD | `72f2eab` — `feat: ship vendor taxonomy, availability calendar UI, CRM realtime, and platform stability` |
| Commit date | 2026-09-03 |
| Remote | In sync with `origin/rv_code` (not ahead, not behind) |
| Other local branches | `main` at `70129b4` (2026-06-21, Phase 10 launch). `test_state` at `118a41e` (2026-07-02). This audit did not check them out. |
| Last commit size | 239 files, +29915 / −973 |

Recent history on `rv_code`:

| Commit | Date | Subject |
|--------|------|---------|
| `72f2eab` | 2026-09-03 | Vendor taxonomy, calendar UI, CRM realtime, platform stability |
| `80a0633` | 2026-08-13 | Vendor commerce E2E, pricing admin, platform phases 11–30 |
| `c239e85` | 2026-07-25 | Unified identity, attendee Event OS, workspace experience |
| `118a41e` | 2026-07-02 | MFA enrollment for unseeded users (`test_state` tip) |

Uncommitted:

| Path | Meaning |
|------|---------|
| `package-lock.json` | One-line rename of the root package name `Owanbe` → `owambe`. Not a feature. |
| `mobile/apks/*.apk` | Untracked release APKs. Prior commit intentionally left them out (large binaries). |
| `mobile/assets/env/owanbe_config` | Untracked local env. Prior commit stated it contains keys. **Do not commit. This audit did not print those values.** |
| `mobile/assets/env/owanbe_config.admin` | Same. |

No stash, reset, checkout, or commit was performed.

---

## 5. Runtime / startup (verified from config, not restarted)

| Piece | Current procedure |
|-------|-------------------|
| Postgres | `docker-compose.yml` service `postgres`, container `owanbe-postgres`, image `postgres:14`, host **5436** → container 5432, database `owanbe`. **Running and healthy** at audit time. |
| API | `services/api`, `npm run start:dev` (`nest start --watch`). Port `process.env.PORT ?? 8080`. Global prefix is `/v1` for product routes. Health: `http://127.0.0.1:8080/health`. **Already listening** (PID 17416). Health: database ok, Quaser webhook secret configured, payments `http://localhost:4000`, enterprise email enabled, automation ok (23 completed runs, 1 running), messaging providers **none** (0 enabled), storage local fallback, integrations mode **development**. |
| Flutter customer | `mobile/`, `flutter run -d chrome --web-port=3000`. API base for local mode is `http://127.0.0.1:8080/v1` via `mobile/assets/env/owanbe_config` (see `docs/DEV_TUNNEL_SETUP.md`). **Ports 3000 and 59158 were not listening.** |
| Flutter admin | `lib/main_admin.dart`, local admin env `owanbe_config.admin`, documented admin web port **59158**. |
| Identity | Supabase auth in front of local `users` / `user_roles`. One customer, many workspaces (attendee, organizer, vendor). |
| Tunnel | Optional Cloudflare tunnel (`docs/DEV_TUNNEL_SETUP.md`). Not required for everyday local `flutter run`. |

Quasar containers (`quasar-api` on port 4000, `quasar-postgres` on 5435) were up. They are the payment rail the health check calls. This audit did not inspect Quasar data.

---

## 6. Architecture (as implemented, not a proposal)

```
Person (Supabase auth subject)
        ↓
users  +  user_roles  +  roles / permissions
        ↓
tenants (lab: 1 tenant)
        ↓
Workspaces activated on the same user
   Attendee profile | Organizer + organizer_profiles | Vendor + vendor_profiles
        ↓
Core business systems
   Events → ticket tiers → ticket_orders / entitlements
   Invitations / guests → door check-ins
   Organizer finance (reads orders + ledger)
   Analytics (read-only; monetary source = organizer finance)
   Vendor CRM: vendor_event_requests
   Rentals: rental_catalog_items → rental_bookings
        ↓
Automation (automation_runs / jobs)
        ↓
Integrations (webhooks, email, messaging providers, Quaser)
        ↓
Reporting (consumes operational data)
        ↓
Compliance (retention, export, deletion requests)
        ↓
Control plane (MDM dictionaries, tenant governance)
        ↓
Identity & security (MFA, sessions, suspend, security events)
        ↓
Audit (audit_log, platform_security_events)
```

**One vendor identity.** `users` → `vendors.id`. A vendor may hold both capability keys `SERVICE_PROVIDER` and `RENTAL_PROVIDER`. Those keys are not a second account.

| Engine | Seller path | Buyer path |
|--------|-------------|------------|
| Services | `vendor_services` → organizer or vendor-buyer creates `vendor_event_requests` | Organizer: existing CRM. Vendor buyer: `POST …/vendor-requests/vendor-buyer` (`buyer_kind`, `buyer_vendor_id`) |
| Rentals | `rental_catalog_items` (+ `is_package`, `rental_package_components`) | `rental_bookings`, including vendor-buyer bookings |
| Marketplace | One screen: `/vendors`. Vendor buyer uses `/vendors?vendorBuyer=1`. Legacy `/vendor/marketplace` redirects there. Seller sees Manage, not Request, on own offerings. |

Super Admin owns taxonomy: `tenant_vendor_business_capabilities`, `tenant_vendor_categories.offering_kind`, `tenant_vendor_resource_catalog`.

Phases **14–18** remain architecture-frozen (`docs/ARCHITECTURE_FREEZE_PHASES_14_18.md` and `.cursor/rules/architecture-freeze-phases-14-18.mdc`). Later commits added event editing, marketplace, and vendor CRM on top of those systems. That is existing history, not permission to redesign them.

**Realtime intermediary:** implemented as **SSE**, not WebSocket and not vendor-to-vendor chat.

| Item | Status |
|------|--------|
| `GET /v1/me/crm/stream` | Implemented. `services/api/src/integrations/realtime/crm-realtime-sse.controller.ts`. Room is `crm:{tenant}:user:{userId}` from the JWT. |
| Client | `mobile/lib/core/api/crm_sse_client.dart` |
| Flag | Env can reject the stream (`env.schema.ts` comment). Health did not report the stream as down. |
| Change requests | `vendor_request_change_requests` (12 rows). Types include capability, date, time, venue, special requirement. |
| Chat tables | `chat_threads`, `chat_participants`, `chat_messages` exist and are **empty**. |
| Vendor-to-vendor direct chat | Not implemented. Phase 3D instructions in Cursor explicitly said not to build chat and not to add WebSockets. |
| Negotiation tables | Present, **0 rows**. Separate from CRM SSE. |

---

## 7. QA structures (do not invent a third)

Two different “pack” languages exist. Both must be kept.

### 7.1 Committed platform Live QA

**File (do not replace):** `docs/PHASE30_MANUAL_LIVE_QA_CHECKLIST.md` (2026-08-03).

Cursor summary on 2026-08-03 called the two sign-off blocks Pack 1 and Pack 2:

| Block in the file | Cases | Sign-off in repo |
|-------------------|-------|------------------|
| §1 Phases 14–18 operational loop | L14-01 … L18-02 (publish, discover, purchase, RSVP, door, finance, analytics) | Blank |
| §2 Phases 19–29 | L19 … L29 | Blank |
| §3 Ownership OWN-1 … OWN-5 | Finance owns money; analytics/reporting consume | Blank |

§4 lists explicit exclusions (scheduled publish job, Maybe RSVP, camera QR, walk-in sales, promo codes, Bull/Redis, SSO, device MDM enrollment, and others).

**API harness (not a substitute for the manual checklist):**

| Report | Date | Result |
|--------|------|--------|
| `docs/PHASE30_PLATFORM_CERTIFICATION_REPORT.md` | 2026-08-03 | CERTIFIED WITH LIMITATIONS (10 PASS / 25 PARTIAL / 0 FAIL / 6 SKIP). Cause: migrations 055–062 not applied yet, missing webhook secret, no admin principal, no EVENT_ID. |
| `docs/PHASE30_FINAL_CERTIFICATION_REPORT.md` | 2026-08-03 | **FULL PLATFORM CERTIFIED** (39 / 0 / 0 / 0). Evidence: `docs/evidence/phase30_final_certification_run.json`. Harness: `scripts/phase30_platform_certification_qa.mjs`. |
| `docs/PHASE25_BUSINESS_OPS_INTEGRATED_QA_CHECKLIST.md` | 2026-08-02 | Prepared, **not executed** in that sprint. Later superseded as a gate by the Phase 30 harness, not by a signed manual sheet. |

Dedicated human/API Live QA reports that exist:

| Phase | Report | Verdict in that report |
|-------|--------|------------------------|
| 10 | `docs/PHASE10_LIVE_QA_REPORT.md` | PHASE 10 CERTIFIED (2026-07-25). Attendee post-event. Account cited: `akwajadaniel875@gmail.com`. |
| 11 | `docs/PHASE11_LIVE_QA_REPORT.md` + `docs/PHASE11_QA_CLOSURE_REPORT.md` | PHASE 11 CERTIFIED, then closure sprint marked production complete. |
| 12 | `docs/PHASE12_LIVE_QA_REPORT.md` + `docs/PHASE12_CERTIFICATION_CLOSURE_REPORT.md` | Live QA mixed PASS / PARTIAL. Closure: **Ready for Certification**. Operator UI walkthrough still called out. No later document says “Phase 12 CERTIFIED” in the same style as Phase 10/11. |
| 13–29 | Completion reports | Implementation complete. Most still say Live QA pending. Phase 30 API harness later probed many of the same APIs. |

### 7.2 Vendor Services & Rentals QA Packs 1–25

**There is no Pack 1–25 checklist file in the repository.** Searches of `docs/` and the rest of the repo find no “Pack 5” or “CREATE SERVICE” QA document. References exist only in Cursor transcripts and in reports that say “QA Packs 1–25 were not modified.”

Recovered from Cursor transcript `a69ad1b7` (not from ChatGPT):

| Fact | Evidence |
|------|----------|
| Packs 1–25 already existed and must not be renumbered | User instruction 2026-08-27 |
| Packs 3 and 4 temporarily skipped | Same message: a second Vendor account could not be created |
| Continued using existing vendor | `invify638@gmail.com` |
| Active pack when work paused for UX | **Pack 5 — Create Service**, workspace **Vendor — Seller**, 2026-08-29 |
| After that | UX refinement of Business Type & Offerings (stepped flow). Explicitly not a new pack and not a new phase. |
| Pack 5 result | **Not recorded as complete** |

Operator statements in the 2026-10-07 resume request (public event, private event, zero-fee tickets, purchase without live checkout, check-in, finance after purchase, deep Phase 16/17, analytics not deep) are **not written as case results** in `PHASE30_MANUAL_LIVE_QA_CHECKLIST.md` (all sign-off cells empty). Database evidence that is consistent with partial exercise of that loop:

| Claim area | Database now |
|------------|----------------|
| Events | 30 total: draft 17, published 10, live 1, completed 1, cancelled 1 |
| Tickets | 11 orders (8 fulfilled, 3 cancelled), 11 lines, 9 entitlements, 25 tiers |
| Zero-fee | 7 of 8 fulfilled orders have `total_minor = 0`. 1 fulfilled order has `total_minor = 4500000`. 3 cancelled orders sum `15802500`. |
| Check-in | `event_check_ins` = **1** |
| Invitations | `event_invitations` = 10, tokens = 10, guests = 17 |
| Finance ledger | `ledger_transactions` = **0**, `ledger_lines` = 0, `financial_transactions` = 0, `ticket_payments` = 0, `ticket_refund_cases` = 0, `payouts` = 0 |
| Analytics depth | No separate analytics fact table with rows beyond operational sources. Portfolio/event analytics are computed. Manual L18 cases are unsigned. |

Finance **code** reads `ticket_orders` and `ledger_transactions` (`organizer-finance.service.ts`). Orders exist. The ledger rail has no rows. A UI that “showed a transaction” during August QA is not proven by current ledger rows.

---

## 8. Vendor Services & Rentals history

All of the named reports **exist** and were read.

| Document | Date | What it actually concludes |
|----------|------|----------------------------|
| `docs/VENDOR_SERVICES_RENTALS_GAP_ANALYSIS.md` | 2026-08-24/25 | Discovery. One vendor identity already existed. Engines were already separate. |
| `docs/VENDOR_BUSINESS_TYPES_SERVICES_RENTALS_SCOPE_AND_GAP_ANALYSIS.md` | 2026-08-25 | Locks the product model. Scope only at that moment. |
| `docs/VENDOR_BUSINESS_TYPES_SERVICES_RENTALS_PHASE1_COMPLETION_REPORT.md` | 2026-08-25 | **PASS.** Super Admin definitions only. Migration `071`. No vendor assignment yet. |
| `…PHASE2_COMPLETION_REPORT.md` | 2026-08-25 | **PASS** (build/unit). Onboarding + offerings. Migration `072`. |
| `…PHASE3_COMPLETION_REPORT.md` | 2026-08-25 | Marketplace tabs + vendor-as-buyer **rentals**. Services buyer deferred here, done in Phase 4. Build + unit, **not Live QA**. Later note points at marketplace refinement. |
| `…PHASE4_COMPLETION_REPORT.md` | 2026-08-25 | **PASS.** Vendor-buyer service CRM on the same `vendor_event_requests`. Migration `073`. |
| `docs/VENDOR_SERVICES_RENTALS_PHASE1_4_INTEGRATION_REVIEW.md` | 2026-08-25 | Phases 1–2 PASS. Phase 3 **PARTIAL** until marketplace refinement (separate vendor marketplace entry). |
| `docs/VENDOR_SERVICES_RENTALS_MARKETPLACE_REFINEMENT_COMPLETION_REPORT.md` | 2026-08-25 | **PASS.** One marketplace route `/vendors`. |
| `docs/VENDOR_LEGACY_SERVICE_SELECTION_COMPATIBILITY_REVIEW.md` | 2026-08-27 | Review only. Legacy data preserved. New assignment tables empty. **PARTIAL** preservation, **FAIL** unified runtime authority until vendor confirms mapping. |
| `docs/VENDOR_LEGACY_TAXONOMY_EDIT_COMPLETION_REPORT.md` | 2026-08-27 | Edit Vendor Profile → Business Type & Offerings. Save uses capability and category PUT APIs. Does not overwrite legacy fields. |

Alongside that, August 17–21 (transcripts `a69ad1b7`, `da437786`, `86dcce4c`) built availability (`068`), custom extras (`069`), capability tiers (`070_admin_capability_tier.sql`), change requests (`070_vendor_request_change_requests.sql`), and CRM SSE phases 3A–3D. Human two-browser UI QA for that intermediary layer was described in-chat as deferred even after API batteries.

### Legacy vs new taxonomy (live data)

| Store | invify638@gmail.com (`vendor_id` `f277e734-a036-4d96-9eb5-de3df8c259e5`) | Global |
|-------|------------------------------------------------------------------------|--------|
| `vendors` | business name `invify638`, status `active` | 5 vendors |
| `vendor_profiles.category` | `Catering, Photography, DJ` | 6 profile rows (one profile has a user and no vendor) |
| `vendor_profiles.services_offered` | `["DJ","CATERING","PHOTPGRAPHY"]` (typo kept) | — |
| `vendor_services` | 3 active: `VS-000007` DJ, `VS-000008` CATERING, `VS-000009` PHOTPGRAPHY / key `photpgraphy`. `custom_extras` `[]` | 8 |
| `vendor_packages` | 3 | 6 |
| `vendor_business_capability_assignments` | **0** | **0** |
| `vendor_offering_category_selections` | **0** | **0** |
| Super Admin capabilities | — | `SERVICE_PROVIDER` and `RENTAL_PROVIDER`, both `is_active` |
| Categories | — | 23 `service`, 20 `rental` |
| Resource catalogue | — | 8 kinds |
| `vendor_event_requests` | not filtered to this vendor in the count query | 22, all `buyer_kind=organizer` (accepted 10, new 3, declined 3, completed 2, others 4) |
| Rentals | — | catalogue 0, bookings 0, package components 0 |

**Coexistence rule in code (from the completion and compatibility reports):** offerings save does not PATCH `category` or `services_offered` and does not delete `vendor_services`. Marketplace and CRM still read legacy/`vendor_services`. “My Services & Rentals” gates on the new assignment tables, which are empty, so the workspace can still say capabilities must be selected even though legacy services exist.

Aug 27 read-only integrity snapshot in the same Cursor chat: users 8, roles assignments 21, vendors 5, profiles 5, services 8, packages 6, requests 22, capability assignments 0, events 30. **Now:** users **9**, user_roles **24**, vendor_profiles **6**, everything else in that list unchanged. The extra user is `akwajadaniel785@gmail.com` (roles client, organizer, vendor), provisioned in Cursor on 2026-08-29 because the API user row was missing. This audit did not change that.

Repair scripts exist and were **not** run: `scripts/supabase/repair-invify638-identity.sql`, `scripts/supabase/correct-invify638-onboarding-incomplete.sql`.

---

## 9. Migrations

Runner: `scripts/apply-all-migrations.js`. It records `schema_migrations.id`. Unique numeric prefixes use the three-digit id. Duplicate prefixes (`028`, `029`, and now `070`) use the filename without `.sql`.

**Latest id applied:** `073` (`073_vendor_crm_buyer_context.sql`) at `2026-08-26 02:33:45Z`, same timestamp as `072`.

**Latest file in repo:** `infra/db/073_vendor_crm_buyer_context.sql`. No `074`.

**70 rows** in `schema_migrations`. Repo SQL files through 073 are present, including two `070_*` files.

### 055–062

All eight are recorded and were applied 2026-08-02 during Phase 30 certification closure (see final certification report). Objects checked then (organizer members, automation, webhooks, marketing, compliance, control plane, identity columns) still exist. `organizer_members` row count is 0. `marketing_campaigns` is 0. `automation_runs` is 24.

### 063–067 recorded vs present

These files are in git. **None of 063, 064, 065, 066, 067 appear in `schema_migrations`.** Their effects are present in the database anyway:

| File | Recorded? | Schema evidence |
|------|-----------|-----------------|
| `063_multi_service_vendor_commerce.sql` | No | `vendor_event_requests.service_key`, `funding_status` exist |
| `064_vendor_pricing_overrides.sql` | No | `platform_vendor_pricing_rules` has 3 rows |
| `065_vendor_services.sql` | No | `vendor_services` has 8 rows |
| `066_vendor_service_base_price.sql` | No | `vendor_services.base_payout_minor` and `currency` exist |
| `067_vendor_service_codes_and_conversation_reads.sql` | No | `service_code` populated (`VS-000007`…); `vendor_request_conversation_reads` has 1 row |

Re-running `apply-all-migrations.js` would try to apply 063–067 because they are unrecorded. Several statements are `IF NOT EXISTS`, but 063 and 066 also contain data `UPDATE`s. **Do not apply them to “catch up” without a dedicated review.**

### 068–073

Recorded: `068` (2026-08-17), `069` (2026-08-21), `070` (2026-08-21), `071` (2026-08-26), `072` and `073` (2026-08-26).

**Duplicate 070 hazard:** `schema_migrations` id `070` points at `070_vendor_request_change_requests.sql` only. `070_admin_capability_tier.sql` is a second file with the same prefix. Category metadata already has `tier` values (`core` / `optional`), so that SQL’s effect is present. A future `apply-all` sees two `070` files and will look up ids `070_admin_capability_tier` and `070_vendor_request_change_requests`, **neither of which is the stored id `070`**, so it may try to run both again. The change-request file must be checked for idempotence before any apply. This audit did not apply it.

`028` and `029` are already stored as full filenames (`028_event_website`, `028_identity_v101`, `029_celebration_wall`, `029_identity_dev_seed`). That duplicate-prefix case is consistent.

Phase 30 report says migration `061` had a trailing-quote defect fixed on the apply path (`'{}'::JSONB'` → `'{}'::JSONB`). The repo file should be treated as the copy that was corrected in that closure; this audit did not re-diff that history line by line.

---

## 10. Database inventory

Lab tenant count: **1**. Users: **9** (all `active`). Roles: `admin_super`, `client`, `vendor`, `guest`, `vendor_pending`, `admin_ops`, `admin_support`, `super_admin`, `organizer`, `platform_admin`.

Accounts (email + roles only; no secrets):

| Email | Roles |
|-------|--------|
| `admin@owanbe.dev` | admin_super, platform_admin, vendor |
| `akwajadaniel785@gmail.com` | client, organizer, vendor |
| `akwajadaniel875@gmail.com` | admin_super, client, organizer, vendor |
| `attendee@owanbe.dev` | client, organizer, vendor |
| `invify638@gmail.com` | client, organizer, vendor |
| `organizer@owanbe.dev` | organizer, vendor |
| `prospersimon159@gmail.com` | client, vendor |
| `superadmin@owanbe.dev` | super_admin, vendor |
| `vendor@owanbe.dev` | client, vendor |

`platform_security_events` has **33049** rows. That is audit volume, not a business backlog. Counts below are exact `count(*)` at audit time. Empty tables are omitted from the long list except where emptiness is itself the finding.

| Table | Rows | Purpose | Introduced / relevance |
|-------|------|---------|------------------------|
| users | 9 | Customer identity | Ongoing. Current. |
| user_roles | 24 | Role grants | Ongoing. |
| roles | 10 | Role catalogue | Ongoing. |
| permissions | 10 | Permission catalogue | Ongoing. |
| role_permissions | 62 | Role-permission map | Ongoing. |
| tenants | 1 | Tenant | Ongoing. |
| organizers | 4 | Organizer orgs | Phases 11+. |
| organizer_profiles | 4 | Organizer workspace profile | 051. |
| organizer_members | 0 | Team membership | 055. **Empty — L22 not evidenced by data.** |
| attendee_profiles | 5 | Attendee workspace | 050. |
| vendors | 5 | Vendor identity | Vendor OS. |
| vendor_profiles | 6 | Legacy category + services_offered | One row has user and no vendor. |
| vendor_services | 8 | Bookable services | 065 effect, unrecorded. |
| vendor_packages | 6 | Legacy/commercial packages | Still present. |
| vendor_business_capability_assignments | 0 | SERVICE/RENTAL assignment | 072. **Empty. Blocks Pack 5 seller setup.** |
| vendor_offering_category_selections | 0 | Taxonomy picks | 072. **Empty.** |
| vendor_service_blueprint_resources | 0 | Blueprint links to resource kinds | 072. Empty. |
| tenant_vendor_business_capabilities | 2 | Super Admin capability defs | 071. Active. |
| tenant_vendor_categories | 43 | Service/rental taxonomy | 071 offering_kind. |
| tenant_vendor_resource_catalog | 8 | Resource kinds, not inventory | 071. |
| vendor_availability_settings | 4 | Availability prefs | 068. |
| vendor_calendar_blocks | 6 | Blocked dates | 068 / calendar UI. |
| vendor_event_requests | 22 | Service CRM | All organizer buyers. |
| vendor_request_stage_history | 64 | CRM history | Current. |
| vendor_request_change_requests | 12 | Structured change requests | 070. |
| vendor_request_conversation_reads | 1 | Read receipts | 067 effect. |
| vendor_event_participations | 12 | Event participation | Current. |
| rental_catalog_items | 0 | Rental catalogue | **Empty. Rental QA has no stock.** |
| rental_bookings | 0 | Rental engine | Empty. |
| rental_package_components | 0 | Package BOM | Empty. |
| events | 30 | Events | See status split above. |
| event_ticket_tiers | 25 | Tiers | Phase 13. |
| ticket_orders | 11 | Ticket commerce | Phase 13/14. |
| ticket_order_lines | 11 | Order lines | Current. |
| ticket_entitlements | 9 | Door rights | Phase 15/16. |
| ticket_payments | 0 | Payment rows | Empty. Checkout not stored here. |
| event_check_ins | 1 | Door | Phase 16. Only one check-in. |
| event_invitations | 10 | Invites | Phase 15. |
| event_invitation_tokens | 10 | Tokens | Phase 15. |
| event_guests | 17 | Guest list | Phase 15. |
| event_attendee_feedback | 1 | Post-event | Phase 10 / 054. |
| ledger_transactions | 0 | Finance ledger | Phase 17 rail **empty**. |
| ledger_lines | 0 | Ledger lines | Empty. |
| ledger_accounts | 0 | Ledger accounts | Empty. |
| financial_transactions | 0 | Older finance rail | Empty. |
| financial_transaction_postings | 0 | Postings | Empty. |
| finance_system_state_control | 1 | Finance control row | Present. |
| tenant_finance_settings | 1 | Tenant finance settings | Present. |
| organizer_payouts | 0 | Payouts | Empty. |
| payouts | 0 | Payouts | Empty. |
| automation_runs | 24 | Automation | 056. Health also reported 23 completed + 1 running (timing). |
| automation_run_actions | 24 | Automation actions | 056. |
| automation_jobs | 0 | Job queue table | Empty. |
| marketing_campaigns | 0 | Phase 26 | Schema applied, **no campaigns**. |
| marketing_campaign_recipients | 0 | Recipients | Empty. |
| compliance_retention_policies | 1 | Phase 27 | Seeded policy. |
| compliance_export_requests | 0 | Exports | Empty. |
| data_deletion_requests | 0 | Deletion cases | Empty. |
| mdm_domains | 10 | Control plane dictionary | 061. |
| mdm_entities | 0 | MDM entities | Empty. |
| platform_registry | 10 | Registry | Present. |
| platform_webhooks | 1 | Webhook config | Present. |
| platform_webhook_deliveries | 0 | Deliveries | Empty. |
| platform_api_keys | 0 | Partner keys | Deferred stub. Empty. |
| platform_vendor_pricing_rules | 3 | Pricing rules | 064 effect. |
| email_providers | 1 | Enterprise email | Enabled (health). |
| messaging_providers | 0 | SMS/WhatsApp | Health: none. |
| notifications | 57 | In-app/outbound records | Present. |
| notification_deliveries | 85 | Delivery log | sent/failed/delivered per health. |
| workflow_definitions | 8 | Enterprise workflows | Present. |
| workflow_instances | 24 | Instances | Present. |
| workflow_history | 23 | History | Present. |
| audit_log | 30 | Product audit | Present. |
| platform_security_events | 33049 | Security event log | Large. Do not truncate. |
| chat_threads / messages / participants | 0 | Generic chat | Unused. |
| negotiation_* | 0 | AI negotiation | Schema only. |
| ai_anomalies / predictions / recommendations | 2 / 2 / 3 | Early AI tables | Not the certification path. |
| media_objects | 14 | Media | Present. |
| event_feed_items | 79 | Live/feed | Present. |
| event_websites | 1 | Event site | Present. |
| event_program_items | 1 | Program | Present. |
| tenant_event_categories | 7 | Event categories | Present. |
| tenant_event_tags | 6 | Tags | Present. |
| tenant_feature_flags | 5 | Flags | Present. |

Other business tables exist at 0 rows (aso-ebi, seating assignments, celebration wall posts, disputes, KYC, bookings, vendor applications, bank accounts). They are schema, not active lab data.

---

## 11. Phase matrix

Status words: implementation vs QA are separate. **COMPLETE** here means the completion report says the sprint finished and the code is on `rv_code`. It does **not** mean Live QA was signed.

Confidence: **High** = report + schema or code path checked this audit. **Medium** = report only. **Low** = chat memory without a file.

### Attendee phases 2–10

| Phase | Name | Scope | Implementation | Completion | Live QA | Certification | Migration | Docs | Blockers | Deferred | Confidence |
|-------|------|-------|----------------|------------|---------|---------------|-----------|------|----------|----------|------------|
| 2 | Event discovery | Done | Done | Complete with partial ranking | Notes in completion doc | Not a formal cert stamp | — | `ATTENDEE_PHASE2_*` | — | Stronger geo/ranking | High |
| 3 | Event details | Done | Done | Complete | Notes only | Not stamped | — | `PHASE3_*` | — | — | Medium |
| 4 | Ticket purchase | Done | Done | Complete | Notes only | Not stamped | commerce foundation earlier | `PHASE4_*` | Live PSP | — | Medium |
| 5 | Attendee dashboard | Done | Done | Complete | Gap doc from Live QA input | Not stamped like 10 | — | `PHASE5_*` | — | — | Medium |
| 6 / 6A | Pass & check-in UX | Done | Done | 6A complete | Gap then build | Not stamped | — | `PHASE6_*`, `PHASE6A_*` | Camera QR deferred | Hardware scan | Medium |
| 7 | Live event experience | Done | Done | Complete | Was absent, then built | Not stamped | — | `PHASE7_*` | — | — | Medium |
| 8 | Networking | Done | Done | Complete | — | Not stamped | `053` | `PHASE8_*` | — | — | Medium |
| 9 | Event services hub | Done | Done | Complete | — | Not stamped | — | `PHASE9_*` | — | — | Medium |
| 10 | Post-event | Done | Done | Complete | **CERTIFIED** 2026-07-25 | Yes, that report | `054` | `PHASE10_*`, `ATTENDEE_WORKSPACE_CERTIFICATION_REPORT.md` | Hot restart called out then | Sessions partial by design | High |

### Organizer 11–13

| Phase | Name | Scope | Impl | Completion | Live QA | Cert | Migration | Blockers / deferred | Confidence |
|-------|------|-------|------|------------|---------|------|-----------|---------------------|------------|
| 11 | Organizer dashboard | Done | Done | Complete | Certified + closure | Yes (`PHASE11_LIVE_QA_REPORT`, `PHASE11_QA_CLOSURE_REPORT`) | — | — | High |
| 12 | Event creation | Done | Done | Complete | Live QA then closure “Ready for Certification” | Operator walkthrough not filed as final CERTIFIED | — | Discard/autosave issues were the closure target | High |
| 13 | Ticketing & commerce | Done | Done | Report says pending Live QA | No dedicated Live QA report | Not stamped | tiers in `020` / commerce | Paid checkout without live PSP | High |

### Frozen 14–18

| Phase | Name | Scope | Impl | Completion report status | Live QA in repo | Cert | Migration | Deferred / notes | Confidence |
|-------|------|-------|------|--------------------------|-----------------|------|-----------|------------------|------------|
| 14 | Publishing & discovery | Done | Done | Pending Live QA | Checklist L14 unsigned. API harness later PASS on events list | Not a phase cert stamp | — | Scheduled publish job excluded | High |
| 15 | Invitations & RSVP | Done | Done | Pending Live QA | L15 unsigned. 10 invitations exist | Not stamped | guests `038` | CSV/SMS guest CRM deferred | High |
| 16 | Door / live ops | Done | Done | **Awaiting Live QA** | L16 unsigned. **1** check-in row | Not stamped | `event_check_ins` | Camera, multi-gate, walk-in deferred. Operator “deep test” is **not** in the report | High |
| 17 | Finance | Done | Done | **Awaiting Live QA** | L17 unsigned. Orders exist, **ledger empty** | Not stamped | ledger earlier + finance services | Promo/tax/multi-currency deferred | High |
| 18 | Analytics | Done | Done | **Awaiting Live QA** | L18 unsigned | Not stamped | read-only over 13–17 | Page views/UTM/ML excluded. Matches “not deeply tested” | High |

Freeze doc still says do not begin Phase 19 until Phase 18 Live QA or a waiver. Phase 19+ **was built anyway** (Aug 1–3) and API-certified. The freeze rule remains in force for **redesign**, not as a statement that 19–30 are absent.

### 19–30

| Phase | Name | Scope | Impl | Completion | Live QA | Cert | Migration | Deferred | Confidence |
|-------|------|-------|------|------------|---------|------|-----------|----------|------------|
| 19 | Vendor CRM | Done | Done | Awaiting Live QA in its own report | L19 unsigned. 22 requests exist | API harness PASS on CRM surfaces | `036` plus later 063–070 | Human SSE UI QA was deferred in Aug 21 chat | High |
| 20 | Marketing (first number) | **Scope only** | **Skipped** | No completion report | — | — | — | Product moved to Phase 26 | High |
| 21 | Reporting & exports | Done | Done | Complete | L21 unsigned | API harness | — | PDF/history/scheduler deferred | Medium |
| 22 | Organization & team | Done | Done | Complete | L22 unsigned | API harness | `055` | **0 members in DB** | High |
| 23 | Automation | Done | Done | Complete | L23 unsigned | API harness | `056` | Visual builder, Bull/Redis | High |
| 24 | Integrations | Done | Done | Complete, awaiting review at the time | L24 unsigned | API harness | `057` | Salesforce/Drive/GA/multi-PSP | Medium |
| 25 | Hardening | Done | Done | Complete; integrated QA checklist not executed that day | L25 spot-check unsigned | Folded into Phase 30 harness | `058` | — | High |
| 26 | Marketing & growth | Done (replaces 20) | Done | Complete for review | L26 unsigned | API harness | `059` applied, **0 campaigns** | Promo codes, AI, social, pixels | High |
| 27 | Compliance | Done | Done | Complete | L27 unsigned | API harness | `060` | — | Medium |
| 28 | Control plane | Done | Done | Complete | L28 unsigned | API harness | `061` | Device MDM enrollment stays Unavailable | Medium |
| 29 | Identity & security | Done | Done | Complete | L29 unsigned | API harness | `062` | SSO, partner API keys | Medium |
| 30 | Platform certification | Done | Harness + checklist written | Final report issued | **Manual checklist unsigned** | **API: FULL PLATFORM CERTIFIED** | Applied 055–062 in that closure | See §13 | High |

### Vendor tracks after Phase 30 (this is the real resume work)

| Track | Scope | Impl | QA | Cert | Migrations | Confidence |
|-------|-------|------|----|------|------------|------------|
| Availability + capabilities | Done in chats/reports | On `rv_code` | API scripts under `services/api/scripts/qa-*`. Flutter UI QA not closed | No | `068` recorded | High |
| CRM SSE 3A–3D | Done | SSE + change requests | API batteries written. Human UI QA deferred in the 2026-08-21 prompt | No | `069`, `070` | High |
| Services/Rentals 1–4 | Done | On `rv_code` | **Pack 5 not finished.** Packs 3–4 skipped | No | `071`–`073` recorded | High |
| Legacy taxonomy edit + stepped UX | Done | On `rv_code` | Done so Pack 5 could continue. Pack 5 itself not passed | No | None (no mass backfill) | High |

---

## 12. What is finished vs not

| Area | Status | Evidence | Last known state |
|------|--------|----------|------------------|
| Platform phases 1–29 code | ✅ COMPLETE | Completion reports + `80a0633` / `72f2eab` | On `rv_code` |
| Phase 30 API certification | ✅ COMPLETE | Final certification report, 39 PASS | 2026-08-03 lab |
| Phase 30 manual Live QA | 🔵 UNTESTED as a signed sheet | Checklist sign-off empty | Cases exist; results were never written into the file |
| Phases 10–11 Live QA | ✅ COMPLETE | Their Live QA reports | Jul 2026 |
| Phase 12 Live QA | 🟡 PARTIAL | Closure says ready; no final CERTIFIED banner | Jul 2026 |
| Phases 14–18 manual cases | 🟡 PARTIAL | Data shows publish/orders/one check-in; reports still say awaiting QA; checklist unsigned | Aug 2026 operator testing not filed |
| Phase 16 / 17 “deep test” | 🔵 UNTESTED in repo | Completion reports still pending | Chat claim only |
| Phase 18 analytics manual QA | 🔵 UNTESTED | L18 unsigned; report pending | Consistent with “not deeply tested” |
| Phases 19–29 manual packs | 🔵 UNTESTED | Checklist unsigned; some tables empty (members, campaigns) | API harness passed 2026-08-03 |
| Phase 20 as its own build | ⚪ DEFERRED | Scope doc; shipped as Phase 26 | Closed |
| Vendor Services phases 1–4 | ✅ COMPLETE as implementation | Four completion reports | Not Live-QA certified |
| Marketplace canonical route | ✅ COMPLETE | Refinement report | `/vendors` |
| Legacy field preservation | ✅ COMPLETE | Legacy edit report + live invify row | Typo `PHOTPGRAPHY` still stored |
| New capability assignment for existing vendors | 🔴 BLOCKED for QA | 0 assignment rows | Pack 5 cannot be “already done” |
| Vendor QA packs 3 and 4 | ⏭ SKIPPED | Cursor 2026-08-27 | Second vendor account unavailable then |
| Vendor QA Pack 5 | 🟡 PARTIAL | UX prep committed; no pass record; assignments still 0 | **Resume here** |
| Vendor QA packs 6–25 | 🔵 UNTESTED | Names are not in the repo | Need the external checklist |
| Rental catalogue / bookings | 🔴 BLOCKED for buyer QA | 0 items, 0 bookings | Nothing to rent |
| CRM SSE | 🟡 PARTIAL | Code + API scripts; human UI QA deferred | Do not rebuild |
| WebSocket / vendor-vendor chat | ⚪ DEFERRED | Explicitly not built | SSE is the intermediary |
| Ledger-backed finance history | 🟡 PARTIAL | Orders exist; ledger 0 | Do not invent ledger rows |
| Live card checkout | ⚪ DEFERRED / environment | `ticket_payments` 0; Quaser process is up | Do not treat as certified |
| Bull/Redis, SSO, device MDM, AI Studio, promo codes | ⚪ DEFERRED | Phase 30 §7 and checklist §4 | Out of resume scope |

---

## 13. What remains

### A. Implementation remaining

- No new platform phase is waiting in a completion report.
- Pack 5 is a **test**, not a build, unless the test finds a defect.
- Rental seller catalogue has no rows, so rental packs cannot pass until a vendor creates offerings through the existing UI. That is QA data, not a new engine.
- `organizer_members` and `marketing_campaigns` are empty, so those manual cases have no fixture.

### B. Bug fixes remaining

None are recorded as an open defect at the pause. Known product gaps that are already documented, not new bugs:

- Legacy labels and new taxonomy are not auto-merged (`VENDOR_LEGACY_SERVICE_SELECTION_COMPATIBILITY_REVIEW.md`).
- `PHOTPGRAPHY` typo is stored on purpose (no silent rewrite).
- Migration bookkeeping for 063–067 and duplicate `070` is unsafe to “just apply.”
- Finance ledger has no rows while ticket orders do.

### C. Live QA remaining

1. Finish **Vendor Pack 5** (Create Service) on `invify638@gmail.com` after the vendor saves Service Provider and categories. Do not restart packs 1–2. Do not renumber.
2. Packs 3 and 4 stay skipped until a second vendor exists.
3. Packs 6–25: continue only from the original checklist (not in this repo).
4. Platform manual checklist §1–§3 remains unsigned. Do not start it by rewriting it.
5. Phase 18 analytics still needs a deliberate pass after vendor/door activity, which is still thin (1 check-in, 0 rental bookings, 0 new capability rows).

### D. Certification remaining

- Phase 30 **API** certification is filed. Manual sign-off is not.
- Phases 13–19 and 21–29 have no phase-level CERTIFIED report comparable to Phase 10/11.
- Vendor Services/Rentals 1–4 are not certified.

### E. Deferred features

From `PHASE30_FINAL_CERTIFICATION_REPORT.md` §7 and the manual checklist §4: partner API keys/SDK, SSO, device MDM expansion, i18n/multi-region, Bull/Redis, AI Studio, enabled SMS/WhatsApp providers, full Flutter replay of the API cert, promo codes, tax engine, multi-currency redesign, legal e-sign, DAM, report PDF scheduler, visual automation builder, Salesforce/Drive/GA, walk-in sales, multi-gate, emergency broadcast, camera QR package, invitation CSV.

Also deferred by the vendor track: vendor-to-vendor chat, WebSockets, mass backfill of legacy categories, a second marketplace, a second CRM, a unified booking table.

### F. Environment

- Postgres and API were up. Flutter web was not listening.
- Untracked env files and APKs must stay untracked.
- `package-lock.json` name case change is noise.
- Quaser is on port 4000; this audit did not verify a live card payment.
- Messaging providers: 0 enabled.

### G. Unknowns that require ChatGPT history

**External ChatGPT conversation history is not accessible from the current coding environment.**

Cursor transcripts on this machine cover Jul–Sep 2026 engineering sessions. They do **not** include the ChatGPT threads titled in the resume request except where the same work was repeated in Cursor.

Still missing unless those chats are supplied:

- The actual **Pack 1–25 titles and expected results** (only Pack 5’s name and the skip of 3 and 4 were recovered).
- Pass/fail marks for packs 1 and 2.
- Any “Daily Progress” or “Vendor Workflow Issue” conclusions that were never written into `docs/`.
- Whether the operator marked specific L14–L18 cases PASS in a chat sheet after 2026-08-03.
- Whether Pack 5 was attempted on a device after the 2026-08-29 UX change and failed in a way that was not committed.

---

## 14. Cursor transcripts recovered (not ChatGPT)

Parent transcripts under the Cursor project history, first user timestamp where readable:

| Id | First seen | Topic recovered from the transcript |
|----|------------|-------------------------------------|
| `69b3fb83-1f47-4526-99ac-18d086b60f79` | 2026-07-22 | Attendee/organizer phases through Phase 30 certification and the manual checklist |
| `da437786-ae16-4766-afd4-23279c4edae5` | 2026-08-17 | Vendor availability and Phase 3D organizer↔vendor SSE intermediary |
| `a69ad1b7-11ea-4207-a91d-21b6b2f9f7eb` | 2026-08-17 | Capabilities, legacy taxonomy, Pack 5 UX pause |
| `86dcce4c-3f4a-4069-8518-cbd5aef01e3e` | 2026-08-18 | Calendar UI; later commit/push of `72f2eab` |
| `5b0dfd36-4cf5-4ef6-b212-58f563d73439` | 2026-08-24 | Vendor Services/Rentals scope and phases |
| `fa23eae6-2855-45a2-8710-647fe0b223f3` | 2026-08-10 | Account inventory |
| `bedf9952-2002-4fc2-9d98-8dabe080d716` | 2026-08-05 | APK / vendor pricing |

No Cursor transcript after 2026-09-03 contains product work except this audit (2026-10-07).

---

## 15. Docs index (groups)

Scope / gap: `PHASE14`–`PHASE30` scope files, `PHASE20_…` (scope only), `VENDOR_SERVICES_RENTALS_GAP_ANALYSIS.md`, `VENDOR_BUSINESS_TYPES_SERVICES_RENTALS_SCOPE_AND_GAP_ANALYSIS.md`.

Completion: `PHASE3`–`PHASE19`, `PHASE21`–`PHASE29` completion reports, vendor phase 1–4 completion reports, marketplace refinement, legacy taxonomy edit.

Certification: `PHASE10_LIVE_QA_REPORT.md`, `PHASE11_LIVE_QA_REPORT.md`, `PHASE11_QA_CLOSURE_REPORT.md`, `PHASE12_LIVE_QA_REPORT.md`, `PHASE12_CERTIFICATION_CLOSURE_REPORT.md`, `PHASE30_PLATFORM_CERTIFICATION_REPORT.md`, `PHASE30_FINAL_CERTIFICATION_REPORT.md`, `ATTENDEE_WORKSPACE_CERTIFICATION_REPORT.md`.

QA checklists: `PHASE30_MANUAL_LIVE_QA_CHECKLIST.md` (canonical manual cycle), `PHASE30_PLATFORM_CERTIFICATION_CHECKLIST.md`, `PHASE25_BUSINESS_OPS_INTEGRATED_QA_CHECKLIST.md` (prepared, not the thing to extend).

Architecture: `ARCHITECTURE_FREEZE_PHASES_14_18.md`, `UNIFIED_IDENTITY_PRODUCT_ARCHITECTURE.md`, `UNIFIED_IDENTITY_IMPLEMENTATION_REPORT.md`.

Operator / tunnel: `DEV_TUNNEL_SETUP.md`, email production docs.

---

## 16. OWAMBE RESUME POINT

1. **Last completed implementation:** `72f2eab` on 2026-09-03 — Vendor Services/Rentals phases 1–4, marketplace refinement, legacy taxonomy edit (including stepped offerings UX), availability calendar, CRM SSE. Platform phases 1–30 were already in `80a0633` and that later commit.
2. **Last completed QA:** Phase 30 **API** harness, FULL PLATFORM CERTIFIED, 2026-08-03. Older stamped Live QA: Phase 10 and Phase 11. Vendor pack completion is **not** filed.
3. **Last incomplete QA:** Vendor Services & Rentals **Pack 5 — Create Service** (Vendor Seller). Platform manual checklist `docs/PHASE30_MANUAL_LIVE_QA_CHECKLIST.md` is also unsigned and must not be replaced.
4. **Current phase:** No new build phase. Stay in Vendor Services & Rentals QA. Platform phase 30 remains the last certification phase.
5. **Current pack:** **Pack 5.** Packs 3 and 4 stay skipped. Do not invent packs 26+.
6. **Current workspace to open:** `C:\Users\HorizonPay\IIPS\owambe`, branch `rv_code`. API already on port 8080. Postgres `owanbe-postgres:5436`. Flutter customer is not running; start it only when testing (`flutter run -d chrome --web-port=3000` from `mobile/`).
7. **First thing to test/do:** Sign in as **`invify638@gmail.com`**, Vendor workspace, Edit Business Profile → Business Type & Offerings. Confirm Service Provider (and categories) **save**. Database currently has **zero** capability assignments. Then run Pack 5 Create Service against the existing `vendor_services` rows. Do not create a second vendor for this step.
8. **Things NOT to touch:** Phases 14–18 canonical workflows (publish → sell → invite → door → finance → analytics). Do not add a second CRM, second marketplace, second check-in, or WebSocket chat. Do not apply migrations. Do not run `repair-invify638` or onboarding-reset scripts. Do not commit `mobile/assets/env/*` or APKs. Do not renumber QA packs. Do not start Phase 31 or a Vendor phase 5 build.
9. **Known blockers:** New taxonomy assignments are empty for every vendor, including invify, so seller capability gates still look unset. Rental catalogue is empty. Ledger is empty. Migration runner will mis-handle unrecorded 063–067 and duplicate 070 if someone “catches up” the database. Pack 3/4 still need a second vendor that does not exist as a clean extra account. Flutter was not running.
10. **Deferred work:** Phase 20 as a separate phase (already absorbed by 26). Manual certification sign-off. Promo codes, SSO, Bull/Redis, device enrollment, AI Studio, SMS/WhatsApp providers, vendor-to-vendor chat, mass legacy backfill, live card checkout proof.

**STOP.** Audit only. No implementation follows from this document.
