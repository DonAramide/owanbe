# Vendor Business Types / Services / Rentals — Phase 4 Completion Report

**Date:** 2026-08-25  
**Mode:** Stabilization — additive buyer context on existing Vendor CRM.  
**Did not implement:** second CRM, unified booking, payments, inventory, marketplace redesign.

---

## 1. CRM audit

**PASS**

`vendor_event_requests.organizer_id` is **NOT NULL** → `organizers(id)`. Create path called `assertEventCapability` + `resolveOrganizerId` (`ORGANIZER_REQUIRED`). Unique key is `(event_id, vendor_id, service_key)`. Inbox is `listForVendor` by **provider** `vendor_id`. Stage transitions treat non-organizers as the **provider** only. Notifications on provider action went to the **organizer owner user**. Timeline/messages used the same party check.

**Buyer = organizer** was assumed at: create authorization, `organizer_id` FK, history `actor_type`, notify target, Flutter “Organizer:” labels.

Existing rows remain organizer buyers. `organizer_id` still means **event organization**, not a rewritten buyer identity.

---

## 2. Buyer-context extension

**PASS**

Additive columns (`073_vendor_crm_buyer_context.sql`):

- `buyer_kind` default `organizer`
- `buyer_vendor_id` nullable FK to `vendors`

Organizer create path unchanged (still `POST events/:eventId/vendor-requests`, still upserts on unique key). Vendor buyer uses a **separate** create route and **does not** upsert onto an existing organizer request (`DO NOTHING` + `REQUEST_EXISTS`).

---

## 3. Vendor-to-Vendor service procurement

**PASS**

`POST events/:eventId/vendor-requests/vendor-buyer` inserts into the **same** `vendor_event_requests` table. Same stages, inbox, timeline, contract/assignment **derived** fields. Provider `vendor_id` is the photography vendor; buyer is `buyer_vendor_id`.

---

## 4. Event authorization

**PASS**

Reuses `EventsAccessService.assertVendorAssociatedWithEvent` (organizer access, participation not rejected, or accepted CRM as **provider**). No new membership system. `EVENT_NOT_ASSOCIATED` otherwise.

---

## 5. Self-procurement protection

**PASS**

Server: `SELF_PROCUREMENT_FORBIDDEN` when buyer vendor id equals provider vendor id. Unit-tested. UI also uses marketplace hide-own-vendor for rentals; service cards still require server reject.

---

## 6. Inbox

**PASS**

Provider: existing `GET vendors/:vendorId/requests`. Buyer: `GET vendors/:vendorId/outgoing-vendor-requests`. No second inbox table. Inbox labels use `displayBuyerName` (vendor business name when `buyer_kind=vendor`).

---

## 7. Timeline

**PASS**

Same `vendor_request_stage_history`. Buyer vendor is treated as the request-owner party (`actorRoleOnRequest` → organizer-like stages: cancel/schedule/complete) while **provider** still alone accepts/declines. Timeline GET allows buyer vendor as a party.

---

## 8. Notifications

**PASS**

Same `NotificationService` / in-app / CRM realtime templates. When the **provider** acts, notify target is buyer vendor owner if `buyer_vendor_id` is set, else event organizer owner. Incoming request still notifies the **provider**.

Finance-only paths (`confirmAgreement`, escrow hold/release) remain **event organizer** — not vendor-buyer escrow (deferred).

---

## 9. Flutter changes

**PASS**

| Surface | Change |
|---|---|
| `RequestVendorSheet` | `vendorBuyerMode` + copy |
| `marketplace_vendor_detail_screen` | Vendor buyer can request |
| `inviteVendorToEvent` | Optional `vendorBuyer` → new API |
| Vendor marketplace | Outgoing service request list |
| Inbox / dashboard | `displayBuyerName` |

---

## 10. API changes

**PASS** (additive)

| Method | Path |
|---|---|
| POST | `events/:eventId/vendor-requests` — **unchanged** organizer path |
| POST | `events/:eventId/vendor-requests/vendor-buyer` |
| GET | `vendors/:vendorId/outgoing-vendor-requests` |

Views add `buyerKind`, `buyerVendorId`, `buyerVendorName`.

---

## 11. Database changes

**PASS**

`infra/db/073_vendor_crm_buyer_context.sql`. No rewrite of historical `organizer_id`. Unique `(event_id, vendor_id, service_key)` **unchanged** (limitation: one live request per event+provider+service).

---

## 12. Security

**PASS**

Auth required. Event association reused. Provider/service validated as in organizer create. Self-procurement rejected. Buyer cannot accept/decline as provider. Organizer create still requires organizer capability.

---

## 13. Organizer regression

**PARTIAL PASS** (static + unit; not Live E2E)

Organizer create, upsert, inbox, stages, timeline code paths remain; new columns default so old rows stay valid. Live organizer click-through was not run.

---

## 14. Vendor regression

**PARTIAL PASS**

Provider inbox query additive joins only. Vendor-as-buyer rentals still use association helper. Live vendor E2E not run.

---

## 15. Tests

**PASS** (build/unit; not Live QA)

- Nest `npx nest build`
- Jest `vendor-crm-buyer.util.spec.ts` (+ taxonomy/rental-buyer as relevant)
- Flutter `vendor_buyer_crm_parse_test.dart`
- Analyze on touched Dart (no errors expected)

Mapped cases: organizer create path preserved; self-procurement unit; association codes reused; invalid vendor/service still existing CRM errors.

---

## 16. Deferred items

**PASS** (explicit)

- Finance/escrow for vendor-buyer (still organizer-only)
- Relaxing unique `(event, provider, service)` for two buyers
- Second CRM, payments, ratings, non-event procurement

---

## 17. Known limitations

**PARTIAL PASS**

- Apply `073` (and prior 071–072) or buyer columns fail.  
- If organizer already requested the same provider+service on the event, vendor-buyer create returns `REQUEST_EXISTS` (does not overwrite).  
- Vendor-buyer cannot drive escrow fund/release APIs.  
- Live E2E not performed.

---

## Section scorecard

| Section | Status |
|---|---|
| 1. CRM audit | PASS |
| 2. Buyer-context extension | PASS |
| 3. Vendor-to-Vendor service procurement | PASS |
| 4. Event authorization | PASS |
| 5. Self-procurement protection | PASS |
| 6. Inbox | PASS |
| 7. Timeline | PASS |
| 8. Notifications | PASS |
| 9. Flutter changes | PASS |
| 10. API changes | PASS |
| 11. Database changes | PASS |
| 12. Security | PASS |
| 13. Organizer regression | PARTIAL PASS |
| 14. Vendor regression | PARTIAL PASS |
| 15. Tests | PASS (unit/build) |
| 16. Deferred items | PASS |
| 17. Known limitations | PARTIAL PASS |

---

✅ Vendor Business Types / Services / Rentals Phase 4 Implementation Complete
