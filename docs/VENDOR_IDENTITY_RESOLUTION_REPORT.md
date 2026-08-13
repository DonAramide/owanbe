# Vendor Identity Resolution Report

**Sprint:** Vendor Identity Resolution Architecture  
**Status:** Complete for identity path (Marketplace → CRM → Inbox → Notifications)  
**Date:** 2026-07-28  

**Scope boundary:** Identity only. No Vendor CRM redesign, OMS integration, Contracts, or Negotiation Engine refactor. Auth / RBAC / Workspace Activation / Profile infrastructure unchanged.

---

## Decision (Marketplace)

Marketplace listings **must** correspond 1:1 with a real `vendors` row owned by an authenticated user (`vendors.owner_user_id`).  

Demo listings are allowed **only** when seeded as proper Vendor Profiles (e.g. `vendor@owanbe.dev` → `55555555-…`). Orphan marketplace string IDs (`v1`…`v11`) are forbidden.

---

## 1. Canonical Vendor Identity Model

```
User (users.id = auth subject)
  ↓
Vendor Profile (vendor_profiles.user_id)
  ↓
Vendor business (vendors.id)
     via vendor_profiles.vendor_id
     OR vendors.owner_user_id (+ status active / not suspended)
```

**Canonical Vendor ID** = `vendors.id` (UUID).

Every identity-sensitive module must resolve through:

| Direction | Mechanism |
|-----------|-----------|
| Authenticated vendor → ID | `GET /me/vendor-id` → `IdentityService.resolveVendorId` |
| CRM / access checks | `EventsAccessService.resolveVendorId` / `VendorAccessService.resolveVendorIdForUser` (same COALESCE chain) |
| Marketplace listing ID | `vendors.id` from `GET /vendors` (catalog) |
| Create request | `POST …/vendor-requests` body `vendorId` = that UUID |
| Notifications | `vendors.owner_user_id` for that `vendorId` |

No alternate resolution paths for CRM / Marketplace / Inbox / Notifications.

---

## 2. Every identity source audited

| Source | Location | Pre-sprint behaviour | Classification after sprint |
|--------|----------|----------------------|-----------------------------|
| Seed vendor UUID | `VendorIdentity.seedDemoVendorId` / `029_identity_dev_seed.sql` | Shared as fake “canonical” for any mock fallback | **Seed fixture only** (`vendor@owanbe.dev`) |
| Legacy aliases `v12`, `vendor_jollof` | `VendorIdentity._legacyIdToCanonical` | Remapped to seed | Kept as **legacy remap only** |
| Orphan mocks `v1`…`v11` | `customer_home_providers._mockVendors` | Emitted as marketplace IDs; CRM create failed or mismatched | **Removed** from marketplace |
| API catalog | `VendorsService.listCatalog` / `VendorsApi.listCatalog` | Real `vendors` rows | **Canonical listing source** |
| `GET /me/vendor-id` | `IdentityService.resolveVendorId` | `owner_user_id` only, no status / profile prefer | **Aligned** to profile → owned active vendor |
| `EventsAccessService.resolveVendorId` | vendor CRM actor checks | `owner_user_id` + `active` | **Aligned** to same COALESCE chain |
| `VendorAccessService.resolveVendorIdForUser` | packages / bookings | owner or staff | **Aligned** to prefer `vendor_profiles.vendor_id` |
| `canonicalVendorIdProvider` | Vendor inbox | Fell back to seed UUID for any user when resolve failed | **Removed seed fallback** |
| `vendorProfileProvider` | Dashboard header | Used seed id when loading | **No longer substitutes seed** |
| `VendorStore` / `demoVendorId` | In-memory branding | Hardcoded Jollof & Co | **B** — display mock only |
| `VendorIntelligenceEngine` | Dashboard fallback | Hardcoded negotiations | **B** |
| `_mockOmsOrders` | OMS Incoming | Hardcoded orders | **C / B** — independent mock |
| `ContractProposal` | Organizer Manage Contract | In-memory | **C** |
| `negotiation_sessions` | AI negotiation API | Parallel stack | **C** |
| `OnboardingApi.devVendorId` | Legacy constant | Seed id | Documented seed-only |
| Notifications | `resolveVendorOwnerUserId` | From `vendors.owner_user_id` | **A** (correct when `vendorId` is canonical) |
| CRM tables | `vendor_event_requests.vendor_id` FK | Already UUID FK to `vendors` | **A** |

---

## 3. Every identity source migrated

| Change | What |
|--------|------|
| Marketplace mock | Only seed-backed `VendorIdentity.seedDemoVendorId` listing |
| `VendorIdentity` | Rejects non-UUID orphan IDs; documents chain; `seedDemoVendorId` |
| `canonicalVendorIdProvider` | No seed substitution for other users |
| `vendorProfileProvider` | Loading placeholder without seed remapping |
| `IdentityService.resolveVendorId` | `COALESCE(vendor_profiles.vendor_id, active owned vendors.id)` |
| `EventsAccessService.resolveVendorId` | Same COALESCE chain |
| `VendorAccessService.resolveVendorIdForUser` | Prefer `vendor_profiles.vendor_id` |
| `VendorsService.listCatalog` | Join `vendor_profiles` for display name; require `owner_user_id` |
| `VendorCrmService.createRequest` | Reject non-UUID `vendorId`; require owned vendor row |

---

## 4. Module classification (Step 7 — audit only)

| Module | Class | Notes |
|--------|-------|-------|
| Marketplace catalog (API) | **A** | Uses `vendors.id` |
| Marketplace seed fallback | **A** | Seed UUID owned by `vendor@owanbe.dev` |
| Vendor CRM create/list/stage/counter/messages | **A** | FK + owner resolution |
| Vendor Inbox (`vendorInboxSnapshotProvider`) | **A** | Uses `canonicalVendorIdProvider` → `/me/vendor-id` |
| Organizer Vendor Pipeline | **A** | Lists by `event_id` on same CRM table |
| Notifications (CRM) | **A** | `owner_user_id` of request `vendor_id` |
| Vendor Dashboard (live inbox branch) | **A** | When CRM snapshot loads |
| `VendorIntelligenceProvider` / Engine | **B** | Future: stop masking empty inbox with demos |
| `VendorStore` Jollof branding | **B** | Future: bind header to workspace profile |
| Vendor OMS / `_mockOmsOrders` | **B** | Future OMS identity sprint |
| `ContractProposal` | **C** | UI-only; not CRM identity |
| `negotiation_sessions` stack | **C** | Separate engine; out of scope |

---

## 5. Files changed

### Mobile
- `mobile/lib/features/vendor/vendor_identity.dart`
- `mobile/lib/portals/customer/providers/customer_home_providers.dart`
- `mobile/lib/features/vendor/providers/vendor_providers.dart`
- `mobile/lib/features/vendor/data/vendor_store.dart` (comment / seed constant alias)
- `mobile/lib/core/api/onboarding_api.dart` (seed comment)
- `mobile/test/features/vendor/vendor_inbox_integration_test.dart`

### API
- `services/api/src/modules/identity/identity.service.ts`
- `services/api/src/modules/events/events-access.service.ts`
- `services/api/src/ownership/vendor-access.service.ts`
- `services/api/src/modules/vendors/vendors.service.ts`
- `services/api/src/modules/vendor-operations/vendor-crm.service.ts`

### Docs
- `docs/VENDOR_IDENTITY_RESOLUTION_REPORT.md` (this file)

---

## 6. Tables affected

| Table | Change |
|-------|--------|
| `vendors` | Read path: catalog filters `owner_user_id IS NOT NULL`; createRequest requires owned row |
| `vendor_profiles` | Read path: preferred `vendor_id` + display `business_name` in catalog |
| `vendor_event_requests` | Unchanged schema; `vendor_id` must be canonical UUID |
| `notifications` | Unchanged; recipient = owner of that `vendor_id` |

No schema migrations in this sprint.

---

## 7. APIs affected

| API | Change |
|-----|--------|
| `GET /vendors` | Catalog prefers profile business name; owned vendors only |
| `GET /me/vendor-id` | COALESCE profile → active owned vendor |
| `POST /events/:id/vendor-requests` | UUID validation; owned vendor required |
| `GET /vendors/:vendorId/requests` | Unchanged auth via aligned `resolveVendorId` |

---

## 8. Identity resolution strategy

1. **Write path (Organizer):** Marketplace card `id` = `vendors.id` → `resolveMarketplaceVendorId` (UUID pass-through / legacy alias only) → `createRequest(vendorId)`.
2. **Notify path:** `SELECT owner_user_id FROM vendors WHERE id = :vendorId`.
3. **Read path (Vendor):** Session user → `GET /me/vendor-id` → `GET /vendors/:thatId/requests`.
4. **Invariant:** Inbox Vendor ID == Marketplace Vendor ID == `vendor_event_requests.vendor_id` == `vendors.id` for the same business.

---

## 9. Regression summary

| Area | Result |
|------|--------|
| Authentication / RBAC / Workspace switching | Untouched |
| Profile infrastructure | Untouched |
| Vendor CRM stage graph | Untouched |
| Marketplace | Lists real catalog (+ single seed-backed demo if API empty) |
| Vendor Inbox | Resolves owned vendor only; no cross-user seed fallback |
| Organizer Pipeline | Still event-scoped CRM |
| Notifications | Still owner-based; correct when request targets real vendor |
| OMS / Contracts / Intelligence mocks | Unchanged (classified B/C) |

**Validation path (identity only):**  
Organizer selects a catalog vendor owned by the signed-in vendor user → Send request → that user’s Vendor Inbox (`new`/`negotiating`) → Accept / Decline / Counter → Organizer pipeline reflects stage.

---

## 10. Remaining architectural work (future sprints — do not start here)

- Bind Vendor Dashboard header / `VendorStore` to workspace `vendor_profiles` (class B)
- Replace or gate `VendorIntelligenceEngine` demo data (class B)
- OMS identity + `_mockOmsOrders` → real bookings (separate sprint)
- Contracts persistence (separate sprint)
- `negotiation_sessions` vs CRM negotiations unification (separate sprint)
- Phase 14 (blocked until product schedule)

---

## Final result

✅ Vendor Identity Resolution COMPLETE
