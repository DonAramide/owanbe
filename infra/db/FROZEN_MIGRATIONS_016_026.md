# Frozen Schema Migrations (016–026)

**Release:** `v1.0.0-production-ready`  
**Frozen:** 2026-06-21  
**Purpose:** Production baseline schema — immutable forward-only from this release

## Policy

Migrations **016 through 026** are **immutable** as of this release. Do not edit these files.

- Post-v1.0 schema changes must use **027+** with new numbered files.
- To fix a bug in frozen migrations, create a forward-only corrective migration (e.g. `027_v1_fix_*.sql`).
- Apply frozen migrations in numeric order on fresh databases.

## Frozen manifest

| # | File | Phase | Summary |
|---|------|-------|---------|
| 016 | `016_phase5_ticket_commerce_foundation.sql` | 5.1 | Ticket orders, entitlements, refunds, organizer payouts |
| 017 | `017_phase5_ledger_enum_organizer_payable.sql` | 5.1 | Ledger enum: organizer_payable |
| 018 | `018_phase5_ledger_enum_organizer_payout_clearing.sql` | 5.1 | Ledger enum: organizer_payout_clearing |
| 019 | `019_phase5_organizer_ledger_constraints.sql` | 5.1 | Organizer ledger constraints |
| 020 | `020_phase5_ticket_tiers_and_capture.sql` | 5.1 | Event ticket tiers, capture flow |
| 021 | `021_phase5_dev_commerce_seed.sql` | 5.1 | Dev tenant, organizer, vendor, event seed |
| 022 | `022_phase54_persistence.sql` | 5.4 | Vendor participations, check-ins, incidents, feed |
| 023 | `023_phase6_admin_seed.sql` | 6 | Platform admin user (`admin_super`) |
| 024 | `024_phase7_super_admin.sql` | 7 | `super_admin` role, feature flags, security events |
| 025 | `025_phase8_security.sql` | 8 | Permissions, role_permissions, compliance tables, security event types |
| 026 | `026_phase9_integrations.sql` | 9 | `notification_deliveries`, `media_objects` |

## Apply scripts

```bash
node scripts/apply-phase8-migration.js   # 025
node scripts/apply-phase9-migration.js   # 026
```

Prior migrations (001–015) remain the foundation; see `owanbe_core.sql` and numbered files through `015_qfe_treasury_dual_write.sql`.

## Supersedes

- `FROZEN_MIGRATIONS_016_024.md` (v0.8.0-super-admin-complete baseline)

## Verification gates (this release)

| Script | Phase | Result |
|--------|-------|--------|
| `verify-phase8-identity-security.js` | 8 | PASS 5/5 |
| `verify-phase9-production-integrations.js` | 9 | PASS 5/5 |
| `verify-phase10-launch-readiness.js` | 10 | PASS 6/6 |
