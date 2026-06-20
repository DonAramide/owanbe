# Owanbe Platform Readiness — v0.8.0

**Release tag:** `v0.8.0-super-admin-complete`  
**Date:** 2026-06-20  
**Scope:** Phases 1–7 stabilization  
**Next phase:** Phase 8 — Identity & Security Hardening

This document is the **rollback point** before Phase 8 begins.

---

## Release summary

| Phase | Name | Gate |
|-------|------|------|
| 1–4 | EOS foundation, marketplace, bookings, treasury | Baseline |
| 5.1 | Ticket commerce rail | PASS |
| 5.2 | Organizer finance center | PASS |
| 5.3 | Finance consolidation | PASS |
| 5.4 | Postgres persistence migration | PASS 19/19 |
| 6 | Platform administration | PASS 14/14 |
| 7 | Super Admin Control Tower | PASS 8/8 |

**Stack:** Flutter (EOS) mobile + NestJS API + Postgres. All production screens API-backed; mock stores retired for core flows (Phase 5.4+).

---

## Architecture snapshot

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        SUPER ADMIN (Control Tower)                       │
│  Cross-tenant · super_admin role · /super-admin/* · @SkipTenant()       │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
┌─────────────────────────────────────────────────────────────────────────┐
│                     PLATFORM ADMIN (Operational team)                    │
│  Single-tenant · admin_super/ops/support · /admin/*                     │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
        ┌───────────────────────────┼───────────────────────────┐
        ▼                           ▼                           ▼
┌───────────────┐         ┌───────────────┐         ┌───────────────┐
│   ORGANIZER   │         │    VENDOR     │         │    PUBLIC     │
│  Event ops    │         │  Marketplace  │         │  Attendee     │
│  /organizers  │         │  /vendors     │         │  /events      │
└───────────────┘         └───────────────┘         └───────────────┘
        │                           │                           │
        └───────────────────────────┼───────────────────────────┘
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│              OPERATIONS (Live event) + FINANCE (Dual rail)               │
│  Check-ins, incidents, feed · Ticket rail + Booking rail · Ledger       │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
                          Postgres (tenant-scoped)
```

---

## 1. Public (Attendee / Marketplace)

**Mobile:** `mobile/lib/features/public/`  
**Route:** `/`, `/events`, `/checkout`, `/attendee`  
**Auth:** Public catalog + optional attendee session

| Capability | API | Persistence |
|------------|-----|-------------|
| Event discovery | `GET /events`, `GET /events/:ref` | `events`, `event_ticket_tiers` |
| Ticket purchase | `POST /events/:ref/ticket-orders` | `ticket_orders`, `ticket_entitlements` |
| Checkout / payment | Ticket commerce + Quaser | `ticket_payments` |

**Key modules:** `events`, `commerce/ticket-commerce`  
**Mobile API:** `events_api.dart`, `ticket_commerce_api.dart`

---

## 2. Organizer

**Mobile:** `mobile/lib/features/organizer/`  
**Route:** `/organizer`  
**Auth:** Organizer session (dev) / JWT + organizer entity

| Capability | API | Persistence |
|------------|-----|-------------|
| Dashboard & events | `GET /organizers/me`, `/organizers/me/events` | `organizers`, `events` |
| Ticket tiers | `POST /events/:ref/tiers` | `event_ticket_tiers` |
| Finance center | `GET /events/:ref/finance/summary` | ticket orders, organizer payouts |
| Attendees / vendors | Organizer portal endpoints | participations, entitlements |
| Live ops | Operations API per event | check-ins, incidents, feed |

**Key modules:** `events/organizer-portal`, `commerce/organizer-finance`  
**Mobile API:** `events_api.dart`, `organizer_finance_api.dart`, `operations_api.dart`

---

## 3. Vendor

**Mobile:** `mobile/lib/features/vendor/`  
**Route:** `/vendor`  
**Auth:** Vendor session / JWT + vendor role

| Capability | API | Persistence |
|------------|-----|-------------|
| Event participation | `GET /vendor/events` | `vendor_event_participations` |
| Bookings & orders | Bookings module | `bookings`, `payments` |
| Wallet & payouts | `GET /vendor/finance/*` | ledger, `payouts` |
| Catalog | Vendor onboarding | `vendors`, services |

**Key modules:** `vendors`, `bookings`, `payments/vendor-finance`  
**Mobile API:** `vendor_events_api.dart`, `vendor_finance_api.dart`

---

## 4. Operations (Live event)

**Mobile:** `mobile/lib/features/operations/` (organizer shell tab + dedicated screens)  
**Platform admin:** `GET /admin/operations/*`  
**Auth:** Tenant-scoped, organizer or admin tiers

| Capability | API | Persistence |
|------------|-----|-------------|
| Check-ins | `GET/POST /events/:ref/check-ins` | `event_check_ins` |
| Incidents | `GET/POST /events/:ref/incidents` | `event_incidents` |
| Live feed | `GET /events/:ref/feed` | `event_feed_items` |
| Cross-event (admin) | `GET /admin/operations/overview` | aggregated |

**Key modules:** `events/event-operations`, `platform-admin/admin-operations-center`  
**Mobile API:** `operations_api.dart`

---

## 5. Finance (Dual rail)

**Rails:**

| Rail | Commerce | Ledger accounts | Admin surface |
|------|----------|-----------------|---------------|
| **Ticket** | `ticket_orders`, `ticket_payments` | organizer_payable, platform fee | Platform admin finance supervision |
| **Booking** | `bookings`, `payments` | vendor escrow, payouts | Admin finance dashboard |

**Mobile surfaces:**
- Organizer: `organizer/finance/`
- Vendor: `vendor/finance/`
- Platform admin: `admin/finance/` + `admin/platform/finance_supervision`
- Super admin: `super_admin/screens/platform_finance_screen.dart`

**Key modules:** `commerce`, `payments`, `qfe` (treasury dual-write)  
**Global control:** `finance_system_state_control` (normal/restricted/frozen)

**Gate evidence (dev tenant):** Ticket revenue ₦15,000 · Booking ₦0 · Platform fees ₦750

---

## 6. Platform Admin (Operational team)

**Mobile:** `mobile/lib/features/admin/` — 7-tab EOS shell  
**Route:** `/admin`  
**Role:** `admin_super`, `admin_ops`, `admin_support`  
**Scope:** Single tenant (`X-Tenant-Id` + JWT)

| Tab | Module | API prefix |
|-----|--------|------------|
| Dashboard | KPIs + health | `GET /admin/platform/dashboard` |
| Organizers | Oversight, suspend | `GET/POST /admin/organizers` |
| Events | Force-close, health | `GET/POST /admin/events` |
| Vendors | Approve, suspend | `GET/POST /admin/vendors` |
| Operations | Cross-event ops | `GET /admin/operations/*` |
| Finance | Ticket + booking rails | `GET /admin/finance/supervision` |
| Compliance | Audit timeline | `GET /admin/audit/timeline` |

**Dev user:** `77777777-7777-4777-8777-777777777777` (`admin_super`)  
**Gate:** PASS 14/14 — `scripts/verify-phase6-platform-admin.js`

---

## 7. Super Admin (Control Tower)

**Mobile:** `mobile/lib/features/super_admin/` — 8-tab EOS shell  
**Route:** `/super-admin`  
**Role:** `super_admin`  
**Scope:** Cross-tenant (`@SkipTenant()`)

| Tab | Module | API prefix |
|-----|--------|------------|
| Overview | Executive KPIs | `GET /super-admin/platform/overview` |
| Tenants | CRUD lifecycle | `GET/POST /super-admin/tenants` |
| Finance | Platform-wide rails | `GET /super-admin/finance/platform` |
| Health | System components | `GET /super-admin/system/health` |
| Flags | Tenant rollout | `GET/POST /super-admin/feature-flags/:id` |
| Audit | Platform timeline | `GET /super-admin/audit/timeline` |
| Analytics | Growth 7d–365d | `GET /super-admin/analytics/platform` |
| Security | Events & exceptions | `GET /super-admin/security/center` |

**Dev user:** `88888888-8888-4888-8888-888888888888`  
**Gate:** PASS 8/8 — `scripts/verify-phase7-super-admin.js`

---

## Schema freeze (016–024)

Migrations **016–024** are frozen at this release. See `infra/db/FROZEN_MIGRATIONS_016_024.md`.

Phase 8+ must use **025+** for new schema changes.

---

## Dev environment quick-start

```bash
docker compose up -d postgres
# Apply migrations 001–024 (core + phase scripts)
node scripts/apply-phase54-migration.js
node scripts/apply-phase6-migration.js
node scripts/apply-phase7-migration.js

cd services/api && npm run build && npm run start:prod
# Env: ALLOW_DEV_COMMERCE_AUTH, ALLOW_DEV_ADMIN_AUTH, ALLOW_DEV_SUPER_ADMIN_AUTH=true

# Verify gates
node scripts/verify-phase5-4-persistence.js
node scripts/verify-phase6-platform-admin.js
node scripts/verify-phase7-super-admin.js
```

---

## Dev identity reference

| Entity | UUID |
|--------|------|
| Tenant | `11111111-1111-4111-8111-111111111111` |
| Dev attendee | `22222222-2222-4222-8222-222222222222` |
| Organizer | `33333333-3333-4333-8333-333333333333` |
| Event | `evt_lagos_owanbe_2026` |
| Vendor | `55555555-5555-4555-8555-555555555555` |
| Platform admin | `77777777-7777-4777-8777-777777777777` |
| Super admin | `88888888-8888-4888-8888-888888888888` |

---

## Rollback procedure

To return to this baseline:

```bash
git checkout v0.8.0-super-admin-complete
docker compose up -d postgres
# Re-apply migrations 001–024 on clean DB
node scripts/verify-phase7-super-admin.js  # confirm PASS
```

---

## Phase 8 entry criteria

- [x] Phases 1–7 committed and tagged
- [x] Schema 016–024 frozen
- [x] All verification gates PASS
- [ ] Phase 8 spec: Identity & Security Hardening

**Status:** Ready for Phase 8.
