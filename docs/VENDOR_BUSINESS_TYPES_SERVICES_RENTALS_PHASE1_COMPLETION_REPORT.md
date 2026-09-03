# Vendor Business Types / Services / Rentals — Phase 1 Completion Report

**Date:** 2026-08-25  
**Mode:** Stabilization — additive Super Admin configuration only.  
**Did not implement:** vendor onboarding, service blueprints, rental packages, marketplace unification, vendor-as-buyer, CRM changes, rental payments.

---

## 1. Implementation summary

**PASS**

Phase 1 adds Super Admin–owned **definitions** for:

- `SERVICE_PROVIDER` / `RENTAL_PROVIDER` (not vendor assignment, not a second identity)
- Service vs rental **category kind** on existing `tenant_vendor_categories`
- Master **resource catalogue** (kinds only — not inventory)

Existing commercial stacks remain separate (`vendor_services` → `vendor_event_requests`; `rental_catalog_items` → `rental_bookings`). Vendor CRM, identity, finance, and rental booking APIs were not redesigned.

**UI:** Control Tower → Commerce Configuration → **Vendor Configuration** (hub + four screens).  
**API:** `admin/settings/vendor-*` under existing `VENDOR_CATEGORY_ADMIN_ROLES`.  
**Audit:** mutations write to existing `audit_log` via `AuditLogService`.

---

## 2. Database changes

**PASS**

**File:** `infra/db/071_vendor_taxonomy_configuration.sql` (one additive migration).

| Change | Detail |
|---|---|
| `tenant_vendor_categories.offering_kind` | `service` \| `rental` \| `unclassified` (default `unclassified`) |
| `tenant_vendor_categories.parent_id` | Optional self-FK, `ON DELETE SET NULL` |
| Backfill | Known rental slugs → `rental`; known service/fashion slugs → `service`. Other slugs stay `unclassified` (no silent reinterpret of `rental_catalog_items`) |
| `tenant_vendor_business_capabilities` | New; unique `(tenant_id, capability_key)`; keys only `SERVICE_PROVIDER`, `RENTAL_PROVIDER` |
| `tenant_vendor_resource_catalog` | New; unique `(tenant_id, slug)`; seed kinds (microphone, speaker, mixer, …) |

**Not changed:** `vendors`, `vendor_profiles`, `vendor_services`, `vendor_event_requests`, `rental_catalog_items`, `rental_bookings`. No hard-delete of categories.

**Seed-path fix (additive):** `ensureFashionAttireCategories` / `ensureRentalCategories` no longer force `is_active = true` on conflict, so Super Admin deactivate persists.

---

## 3. API changes

**PASS**

Existing:

- `GET event-config/vendor-categories` — still lists **active** categories; **additive** `offeringKind` on items
- `GET/POST admin/settings/vendor-categories` — capability catalogue patch **unchanged** (still requires `id`)

New (admin-only, same roles):

| Method | Path | Purpose |
|---|---|---|
| GET | `admin/settings/vendor-business-capabilities` | List capability definitions |
| POST | `admin/settings/vendor-business-capabilities` | Enable/disable / edit label (no new keys) |
| GET | `admin/settings/vendor-offering-categories?kind=` | List by `service` / `rental` / all |
| POST | `admin/settings/vendor-offering-categories` | Create or update (no delete) |
| GET | `admin/settings/vendor-resource-catalog` | List resource kinds |
| POST | `admin/settings/vendor-resource-catalog` | Create or update (no delete) |

No public mutation APIs. No vendor-facing assignment APIs this phase.

---

## 4. Flutter changes

**PASS**

| File | Role |
|---|---|
| `commerce_configuration_screen.dart` | Hub card → Vendor Configuration |
| `vendor_configuration_hub_screen.dart` | Four destinations |
| `vendor_business_capabilities_screen.dart` | Toggle definitions (live API) |
| `vendor_offering_categories_screen.dart` | Service or rental CRUD-lite (create/edit/activate) |
| `vendor_resource_catalogue_screen.dart` | Resource kinds |
| `event_config_api.dart` | Client for new endpoints |
| `app_router.dart` | `/super-admin/commerce/vendor-configuration/*` |
| `admin_framework.dart` / `admin_settings_screen.dart` | Navigation |

Existing capability-flag screens (`AdminVendorCategoriesScreen`) remain at `/super-admin/commerce/vendor-capabilities`.

---

## 5. Super Admin capabilities

**PASS**

- Super Admin can **view** `SERVICE_PROVIDER` and `RENTAL_PROVIDER`.
- Super Admin can **enable/disable** those **definitions** (`is_active`).
- Existing vendors are **not assigned** and **not broken**.
- A vendor **can ultimately** hold one or both (data model is independent flags). Assignment is **deferred** to onboarding (Phase 2).
- No second vendor identity.

---

## 6. Service categories

**PASS**

Super Admin can create, edit, activate, and deactivate categories with `offeringKind: service`. No hard delete. Existing DJ/catering/etc. rows classified as `service` where slugs matched the known list.

---

## 7. Rental categories

**PASS**

Same for `offeringKind: rental`. Known equipment slugs classified as `rental`. `rental_catalog_items.category_slug` text is unchanged.

---

## 8. Resource catalogue

**PASS**

Master kinds (microphone, speaker, mixer, DJ controller, keyboard, drum set, lighting, cable kit) plus admin create/edit/deactivate. **Not** inventory, bookings, or finance.

---

## 9. Authorization

**PASS**

Mutations and lists use `VENDOR_CATEGORY_ADMIN_ROLES` (`super_admin`, `admin_super`, `admin_ops`, `admin_support`) — same as existing vendor-category admin APIs. JWT `Roles` guard; `CurrentUser` for audit actor. Organizer/vendor/attendee cannot mutate these without those roles.

---

## 10. Audit logging

**PASS**

Writes to existing `audit_log`:

- `vendor_taxonomy.business_capability.update`
- `vendor_taxonomy.offering_category.create` / `.update`
- `vendor_taxonomy.resource.create` / `.update`

No second audit table.

---

## 11. Migration instructions

**PASS** (instructions; apply on target DB before using the UI)

```sql
-- After 068–070 are present:
\i infra/db/071_vendor_taxonomy_configuration.sql
```

Idempotent `IF NOT EXISTS` / `ON CONFLICT DO NOTHING` for new tables and seeds. Restart API after apply. If `offering_kind` is missing, `GET vendor-categories` will fail until 071 is applied.

---

## 12. Regression results

| Check | Result | Evidence |
|---|---|---|
| Nest build | **PASS** | `npx nest build` exit 0 |
| Targeted API tests | **PASS** | `vendor-taxonomy.util.spec.ts`, `vendor-availability-capabilities.spec.ts` (16 tests) |
| Flutter analyze (touched files) | **PASS** | No errors (pre-existing warnings in `admin_framework.dart`) |
| Flutter taxonomy parse tests | **PASS** | `vendor_taxonomy_config_test.dart` (3 tests) |
| Vendor CRM code paths | **PASS** (static) | `vendor-crm.service.ts` not modified |
| Vendor / rental marketplace APIs | **PASS** (static) | `vendors.service` / `rentals.service` not modified; public category list additive field only |
| Rental bookings | **PASS** (static) | Schema and rentals module untouched |
| Organizer vendor requests | **PASS** (static) | Create-request path untouched |
| Control Plane / RBAC | **PASS** (static) | Existing roles reused; Control Plane not redesigned |
| Audit infrastructure | **PASS** (static) | Same `AuditLogService` |
| Live browser CRM / marketplace / rental E2E | **PARTIAL PASS** | Not executed in this session (no Super Admin live login against migrated DB in-run) |

Live E2E of CRM/marketplace/rentals is **PARTIAL PASS** because it was verified by **non-touch** of those modules plus compile/tests, not a logged-in organizer/vendor click-through after 071.

---

## 13. Deferred work

**PASS** (explicitly not built)

- Vendor onboarding capability selection  
- Service Blueprints / default requirements wiring  
- Rental packages/sets  
- Marketplace unification  
- Vendor-as-buyer  
- Vendor → Vendor CRM  
- Rental payment/ledger  
- Vendor inventory  
- Delivery/logistics  
- Contracts / CRM redesign  

---

## 14. Known limitations

**PARTIAL PASS** (acceptable for Phase 1)

- Capability **definitions** exist; vendors are **not** yet flagged as Service/Rental Provider.  
- `offering_kind = unclassified` remains for unknown custom slugs until Super Admin edits them.  
- Public marketplace still returns **all active** categories (service + rental + unclassified) so filters do not silently drop rental slugs.  
- No hard-delete; deactivate only. Slug edits are allowed (no FK from `rental_catalog_items`).  
- Resource catalogue is **not** consumed by CRM or rentals yet.  
- Parent category grouping is in schema/API; Flutter editor does not expose parent picker in v1 UI.  
- Live Super Admin UI against a migrated database was not exercised in this session.

---

## Section scorecard

| Section | Status |
|---|---|
| 1. Implementation summary | PASS |
| 2. Database changes | PASS |
| 3. API changes | PASS |
| 4. Flutter changes | PASS |
| 5. Super Admin capabilities | PASS |
| 6. Service categories | PASS |
| 7. Rental categories | PASS |
| 8. Resource catalogue | PASS |
| 9. Authorization | PASS |
| 10. Audit logging | PASS |
| 11. Migration instructions | PASS |
| 12. Regression results | PARTIAL PASS (no live CRM/rental E2E) |
| 13. Deferred work | PASS |
| 14. Known limitations | PARTIAL PASS |

**Overall:** Phase 1 configuration foundation is implemented. Apply `071` before using the new screens.

---

✅ Vendor Business Types / Services / Rentals Phase 1 Implementation Complete
