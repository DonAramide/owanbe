# Vendor Services / Rentals — Phases 1–4 Integration Review

**Date:** 2026-08-25  
**Mode:** Review only. No code, API, Flutter, or migration changes.  
**Sources:** Phases 1–4 completion reports plus current implementation (`071`–`073`, taxonomy/offerings/rentals/CRM modules, Flutter marketplace and vendor workspace).

**Connected-system picture**

```
Super Admin taxonomy (071)
        ↓
Vendor capabilities / blueprints / packages (072)
        ↓
Marketplace UI composes:
  Services  ← vendors catalogue / vendor_services
  Rentals   ← rentals/catalog / rental_catalog_items (+ is_package)
        ↓
Buyer context
  Organizer → vendor_event_requests | rental_bookings
  Vendor    → vendor-buyer CRM (073) | rental vendor-buyer bookings
```

Commercial engines remain separate. Marketplace is not a catalogue of record.

---

## 1. Phase 1 review

**PASS**

| Check | Evidence |
|---|---|
| Super Admin capabilities | `tenant_vendor_business_capabilities`; Control Tower → Commerce Configuration → Vendor Configuration |
| Service / rental categories | `tenant_vendor_categories.offering_kind`; admin + public `event-config` lists |
| Master resource catalogue | `tenant_vendor_resource_catalog` (kinds, not inventory) |
| Audit | `AuditLogService` on taxonomy mutations |
| Control Plane | Existing `VENDOR_CATEGORY_ADMIN_ROLES`; no new RBAC |
| No duplicate config | Extends `tenant_vendor_categories`; no second taxonomy |

Definitions only. Vendors are not assigned capabilities in Phase 1 (assignment is Phase 2).

---

## 2. Phase 2 review

**PASS**

| Check | Evidence |
|---|---|
| Capability selection | Onboarding loads Phase 1 public APIs; PUT `business-capabilities` (not mutually exclusive) |
| Service / rental / both | Independent `SERVICE_PROVIDER` / `RENTAL_PROVIDER` assignments |
| Service blueprints | `vendor_service_blueprint_resources` → master catalogue; not inventory |
| Rental packages | `rental_catalog_items.is_package` + `rental_package_components` with definition quantities |
| Vendor ownership | Offerings APIs `assertOwns` / `resolveVendorId` |
| CRM / rental engine | `vendor_event_requests` and `rental_bookings` not replaced |

Workspace **My Services / My Rental Packages** is `/vendor/offerings` (seller management), separate from Marketplace.

---

## 3. Phase 3 review

**PARTIAL PASS**

| Check | Result |
|---|---|
| Organizer Marketplace Services / Rentals tabs | **PASS** — `/vendors` → `MarketplaceScreen` TabBar |
| Rental package display / honest Unavailable | **PASS** — catalogue `isPackage` + `components`; stock from `available_quantity` |
| Vendor Workspace Marketplace access | **PASS** (exists) — `/vendor/marketplace` |
| Vendor rental buyer, event, `requester_user_id` | **PASS** — `POST …/vendor-buyer-bookings`; `requester_user_id`; association helper |
| Provider validation / event auth / self-rental | **PASS** — active item, `EVENT_NOT_ASSOCIATED`, `SELF_RENTAL_FORBIDDEN` |
| Phase 3 report §8 (services deferred) | **Stale** after Phase 4 |

### CRITICAL — Vendor Marketplace: A or B?

**Classification: Hybrid. Catalogue = A. Workspace entry = B.**

**A (reuse):** After the vendor picks an event, Flutter pushes the **same** `MarketplaceScreen` widget used at `/vendors`, with `vendorBuyerMode` / `buyerVendorId`. Services still come from `marketplaceVendorsProvider` / vendors catalogue. Rentals still come from `GET rentals/catalog`. No second search engine and no second offering source of truth.

**B (separate):** Vendor Workspace does **not** open `/vendors`. It opens a **vendor-only hub** (`VendorMarketplaceScreen` at `/vendor/marketplace`): event dropdown, outgoing CRM list, rental request list, then “Open marketplace”. That hub is a second Marketplace **entry experience**, even though it later embeds the organizer widget via `Navigator.push` (not the canonical `/vendors` route).

**Architectural gap (do not fix in this review):** The stated rule is one canonical Marketplace (`Organizer Workspace → Marketplace` and `Vendor Workspace → Marketplace` as the **same** experience). Current vendor path is a **wrapper + embed**, not a first-class navigation to `/vendors?eventId=…`.

Own rental packages are **hidden** in the rentals tab when `buyerVendorId` matches. They are not shown as seller “Manage offering.”

---

## 4. Phase 4 review

**PASS** (with documented uniqueness / finance limits)

| Check | Evidence |
|---|---|
| Buyer context | `buyer_kind`, `buyer_vendor_id` on `vendor_event_requests` (`073`) |
| Vendor → Vendor service | `POST events/:eventId/vendor-requests/vendor-buyer` |
| Same CRM table / lifecycle / inbox | Same `vendor_event_requests`; provider `GET vendors/:id/requests` |
| `organizer_id` | Still event organization; not rewritten as buyer |
| Organizer create path | `POST …/vendor-requests` still `assertEventCapability` + `resolveOrganizerId` |
| Self-procurement | `SELF_PROCUREMENT_FORBIDDEN` |
| Event association | `assertVendorAssociatedWithEvent` |

Unique `(event_id, vendor_id, service_key)` still means a vendor buyer cannot create a second request if the organizer already requested that provider+service on the event (`REQUEST_EXISTS`, no overwrite).

---

## 5. Marketplace architecture review

**PARTIAL PASS**

**Safe to treat as one discovery layer:** Yes. One vendor list API, one rental catalogue API, one `MarketplaceScreen` for browse/request/book.

**Not yet the mandated UX:** Vendor Workspace does not land on `/vendors`. A vendor-specific shell sits in front. `/vendors/rentals` remains a nested route; the unified tabs also embed rentals.

There is **no** Vendor Marketplace v2 catalogue, **no** vendor-specific search index, **no** parallel offering tables for discovery.

**Can Organizer and Vendor both open the same experience?** Yes, **if** Vendor Workspace navigated to `/vendors` with event + buyer query flags. That is a product/routing decision, not a missing commercial engine.

---

## 6. Buyer/seller context review

**PARTIAL PASS** (data yes; marketplace UX incomplete)

Ownership is already on canonical rows:

- Services: marketplace vendor `id` = `vendors.id`
- Rentals: `rental_catalog_items.vendor_id`
- Current vendor: `canonicalVendorIdProvider` / `resolveVendorId`

| Intended UX | Current |
|---|---|
| Other vendor → Request / Rent | **Present** when `vendorBuyerMode` + event (Phase 4 request; Phase 3 rental book) |
| Own offering → no buy; Manage/View | **Not in Marketplace** |
| Own rentals | **Hidden** (filter), not Manage |
| Own services | **Still listed**; Request still offered in vendor-buyer mode; **server** rejects self-procurement |

Seller management exists **outside** Marketplace: `/vendor/offerings` (own services/packages only; `assertOwns`). Marketplace does not deep-link “Manage” for `offering.vendor_id == current_vendor.id`.

This distinction **can** be implemented from existing IDs without a new identity. It is **not** implemented in the Marketplace UI.

---

## 7. Organizer regression

**PASS** (static; Live E2E not in this review)

Organizer `/vendors` still: service discovery (`listCatalog`), `RequestVendorSheet` → organizer CRM create, rentals tab → `POST events/:eventId/rentals/bookings`, vendor detail, package components, Unavailable when `availableQuantity < 1`. No fake paid flag on those paths.

---

## 8. Vendor regression

**PARTIAL PASS**

| Check | Result |
|---|---|
| Access Marketplace | Hub then canonical widget |
| Browse Services / Rentals | Same tabs/APIs |
| Purchase from another vendor | Services (Phase 4) and rentals (Phase 3) |
| Cannot purchase own | Server yes; UI hides own **rentals** only |
| Manage own offering | `/vendor/offerings`, not Marketplace seller mode |
| Cannot manage another vendor’s offering | Offerings mutations ownership-checked |

---

## 9. Security review

**PASS** (for implemented paths)

- Organizer CRM create still organizer-capability gated.  
- Vendor-buyer CRM and rental-buyer require association + auth.  
- Self-rental and self-service procurement enforced server-side.  
- Offerings writes require matching vendor id.  
- Event “discover” published list is **not** treated as rental/service buyer authorization.

Residual: Marketplace may still **show** Request on the current vendor’s service card; reliance is on API reject.

---

## 10. Data ownership review

**PASS**

| Domain | Source of truth |
|---|---|
| Service definitions (admin) | `tenant_vendor_*` |
| Vendor services / blueprints | `vendor_services`, `vendor_service_blueprint_resources` |
| Service commerce | `vendor_event_requests` |
| Rental SKUs / packages | `rental_catalog_items`, `rental_package_components` |
| Rental commerce | `rental_bookings` (`requester_user_id`) |

Marketplace only composes lists and starts existing create APIs.

---

## 11. Finance limitation

**PASS** (honest deferral)

No fake payment-success or ledger write was added for rentals or vendor-buyer CRM. Catalogue fee/deposit and CRM price snapshots remain amounts, not paid. Vendor-buyer **escrow / confirmAgreement / hold-on-issue** still require **event organizer** identity. That is an accepted limitation, not a silent “paid” state.

---

## 12. Architectural gaps

**PARTIAL PASS** (gaps named; engines intact)

1. **Vendor Marketplace entry is a wrapper** (`/vendor/marketplace`) rather than the canonical `/vendors` route.  
2. **Seller vs buyer** is not a first-class Marketplace mode (hide vs Request vs Manage).  
3. **Service self-card** can still present buyer CTA; rental own-SKU is hidden instead of Manage.  
4. **Unique CRM key** blocks a second buyer for the same event+provider+service.  
5. **Vendor-buyer finance** deferred.  
6. Phase 3 completion report still describes services as deferred (superseded by Phase 4).  
7. Live E2E of the four phases as one flow was not part of this review.

---

## 13. Recommended changes

**PARTIAL PASS** (recommendations only — not implemented)

1. **Routing:** Vendor Workspace “Marketplace” should open `/vendors?eventId=…&vendorBuyer=1` (or equivalent), the same route Organizer uses. Keep event picking as a parameter, not a second marketplace product.  
2. **Shell:** Fold outgoing service/rental lists into existing CRM/inbox or a non-marketplace “My purchases” surface so Marketplace is not a vendor hub.  
3. **Seller mode:** If `vendor_id == current vendor`, show View / Manage → `/vendor/offerings` (and hide Request/Rent). Ownership fields already exist.  
4. **Services tab:** Apply the same own-offering policy as rentals (or seller CTAs), so UI matches server self-procurement rules.  
5. **Docs:** Mark Phase 3 §8 superseded by Phase 4.  
6. **Ops:** Ensure `071`–`073` are applied before treating the stack as live.  
7. **Product decision on unique key:** keep one request per event+provider+service, or later extend uniqueness to include buyer (would be a future migration — not this review).

---

## Section scorecard

| Section | Status |
|---|---|
| 1. Phase 1 review | PASS |
| 2. Phase 2 review | PASS |
| 3. Phase 3 review | PARTIAL PASS |
| 4. Phase 4 review | PASS |
| 5. Marketplace architecture review | PARTIAL PASS |
| 6. Buyer/seller context review | PARTIAL PASS |
| 7. Organizer regression | PASS |
| 8. Vendor regression | PARTIAL PASS |
| 9. Security review | PASS |
| 10. Data ownership review | PASS |
| 11. Finance limitation | PASS |
| 12. Architectural gaps | PARTIAL PASS |
| 13. Recommended changes | PARTIAL PASS |

**Decision required:** Treat Vendor Workspace Marketplace as (1) the canonical `/vendors` experience with buyer flags, or (2) keep the `/vendor/marketplace` hub as an accepted extra shell. Until that is chosen, the “one Marketplace experience” rule is only met at the **catalogue** layer, not the **workspace entry** layer.

---

⚠ Integration Review Requires Architectural Decision
