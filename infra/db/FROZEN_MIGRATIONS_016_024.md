# Frozen Schema Migrations (016–024)

**Release:** `v0.8.0-super-admin-complete`  
**Frozen:** 2026-06-20  
**Purpose:** Rollback baseline before Phase 8 (Identity & Security Hardening)

## Policy

Migrations **016 through 024** are **immutable** as of this release. Do not edit these files.

- Phase 8+ schema changes must use **025+** with new numbered files.
- To fix a bug in frozen migrations, create a forward-only corrective migration (e.g. `025_phase8_fix_*.sql`).
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

## Apply scripts

```bash
# Individual phase seeds (after core schema 001–015)
node scripts/apply-phase54-migration.js   # 022
node scripts/apply-phase6-migration.js    # 023
node scripts/apply-phase7-migration.js    # 024
```

Prior migrations (001–015) remain the foundation; see `owanbe_core.sql` and numbered files through `015_qfe_treasury_dual_write.sql`.

## Verification gates (this release)

| Script | Phase | Result |
|--------|-------|--------|
| `verify-phase5-4-persistence.js` | 5.4 | PASS 19/19 |
| `verify-phase6-platform-admin.js` | 6 | PASS 14/14 |
| `verify-phase7-super-admin.js` | 7 | PASS 8/8 |
