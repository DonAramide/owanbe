# ARCHITECTURE FREEZE — Phases 14–18

**Effective:** 2026-08-01  
**Status:** Feature-complete and **architecture-frozen** pending Live QA  
**Applies to:** Phases 14, 15, 16, 17, 18 (and any later work that touches them)

---

## Frozen domains

| Phase | Domain | Canonical surfaces (do not redesign) |
|-------|--------|--------------------------------------|
| **14** | Event Publishing & Discovery | Publish readiness, discovery listings, public event path |
| **15** | Invitations & RSVP | Guests, invitations, RSVP statuses, entitlement linkage |
| **16** | Door / Live Event Operations | Entitlements → check-ins → `event_check_ins` / ops feed |
| **17** | Organizer Finance | Orders → ledger/refunds → settlement/payout → Finance workspace |
| **18** | Analytics & Event Intelligence | Read-only composition over 13–17; AnalyticsTabV3 / portfolio |

---

## Allowed for Phases 19–25 (and beyond)

Future phases **may**:

- **Read** their data (tables, snapshots, exports)
- **Reuse** their services and providers
- **Deep-link** into their UI (workspace tabs, finance, ops, analytics)
- **Consume** their APIs as published

---

## Forbidden without explicit approval

Future phases **may not**:

- **Replace** business rules established in 14–18
- **Change** canonical workflows (publish → sell → invite → door → finance → analytics)
- **Duplicate** modules (second check-in path, second finance truth, second analytics store, etc.)
- **Introduce parallel implementations** of the same capability
- **Break backward compatibility** of APIs, routes, or data contracts used by frozen phases

---

## Change-control rule

If a Phase **19–25** feature **requires** changes to Phases 14–18:

1. **Document the dependency** (what must change, why, blast radius)
2. **Stop for approval** before modifying frozen code
3. Do **not** silently patch earlier phases mid-sprint

Bug fixes that restore the documented Phase 14–18 behavior (regressions) are allowed without redesign. Behavioral expansions that alter canonical rules require approval.

---

## Single sources of truth (reminders)

| Concern | Canonical owner |
|---------|-----------------|
| Ticket purchase / orders | Ticket Commerce |
| Invitations / RSVP | Guests + Invitations |
| Door admission | Entitlements + `event_check_ins` |
| Money / refunds / payouts | Finance + ledger rails |
| Performance intelligence | Analytics (read-only only) |

Analytics and later CRM/marketing layers **never invent** business metrics when operational data exists; show unavailable instead of estimating.

---

## Related docs

- `docs/PHASE14_EVENT_PUBLISHING_DISCOVERY_COMPLETION_REPORT.md`
- `docs/PHASE15_INVITATIONS_RSVP_COMPLETION_REPORT.md`
- `docs/PHASE16_DOOR_LIVE_OPERATIONS_COMPLETION_REPORT.md`
- `docs/PHASE17_FINANCIAL_OPERATIONS_COMPLETION_REPORT.md`
- `docs/PHASE18_ANALYTICS_INTELLIGENCE_COMPLETION_REPORT.md`

**Do not begin Phase 19 until Phase 18 Live QA & Certification (or explicit waiver).**
