# Adaptive Multi-Platform UI Architecture Report

**Sprint:** Adaptive Multi-Platform Experience (Responsive UI Architecture)  
**Scope:** Presentation layer only — no business logic, APIs, routing, RBAC, or workflow changes  
**Date:** 2026-08-05

---

## 1. Adaptive architecture

Owanbe remains **one application**. Presentation adapts by viewport width through a centralized EOS Adaptive Layout System.

```
Business Logic → Services → Repositories → APIs → State → Presentation (ADAPTIVE)
```

### Central primitives (`mobile/lib/eos/`)

| Primitive | Role |
|-----------|------|
| `EosBreakpoints` | Canonical width thresholds |
| `EosResponsive` | Window class resolver + column/padding helpers |
| `EosAdaptive` | Presentation helpers (`isCompact` / `isMedium` / `isExpanded`) |
| `EosAdaptiveTextScale` | Subtle typography scale by window |
| `EosAdaptiveActionBar` | Stack title/actions on phone; row on wider |
| `EosAdaptiveTopBarChrome` | Shared workspace top-bar rearrange |
| `EosAdaptiveGrid` / `EosAdaptiveFormLayout` / `EosAdaptiveKpiGrid` | Layout rearrangements |
| `EosAdaptiveButtonBar` | Full-width buttons on phone |
| `EosAppShell` | Rail vs bottom nav + More overflow |
| `EosPageScaffold` / `EosSection` / `EosDataTable` | Inherit adaptivity automatically |

**Rule:** Screens must compose these primitives. Do not hardcode screen-specific widths.

---

## 2. Breakpoint strategy

| Window | Width | Layout class |
|--------|-------|--------------|
| Phone (compact) | 0–599 | Bottom nav, stacked headers, card tables, 1-col forms |
| Tablet (medium) | 600–1023 | Compact rail / sidebar, 2-col grids |
| Desktop (expanded) | 1024–1439 | Extended rail, multi-column, rich tables |
| Wide | 1440+ | Same as desktop + denser grid columns |

Legacy aliases preserved: `EosBreakpoints.mobile` → phone; `EosResponsive.isMobile` → compact.

---

## 3. Components converted

| Component | Adaptive behavior |
|-----------|-------------------|
| `EosPageScaffold` | Title stacked above actions on compact; adaptive page padding; text scale |
| `EosSection` | Trailing actions wrap/stack via `EosAdaptiveActionBar` |
| `EosAppShell` | Phone bottom nav (4 primary + More); tablet compact rail; desktop extended rail |
| `EosDataTable` | Compact → card/list rows; medium/expanded → horizontal table; adaptive toolbar/pagination |
| `EosAdaptiveKpiGrid` | Full-width cards on phone; 2-col tablet; wrapping ~200px cards on desktop |
| `EosAdaptiveTopBarChrome` | Search/actions rearrange; labeled actions → overflow menu on phone |
| `WorkspaceContextActions` | Icon-only home + switcher on compact |
| `EosPublicShell` | Already width-aware header (uses `EosResponsive.isMobile`) |

---

## 4. Navigation adaptations

**Routes and destination indices are unchanged.**

| Workspace | Shell | Compact nav |
|-----------|-------|-------------|
| Organizer | `EosAppShell` | Dashboard/Events/Tickets/Vendors + **More** (Attendees…Marketing) |
| Vendor | `EosAppShell` | Primary 4 + More |
| Customer / Attendee | `EosAppShell` | Existing destinations (≤4, no overflow needed for attendee) |
| Admin | `AdminShell` → EOS breakpoints | Primary 4 + More sheet |
| Super Admin | Migrated to `EosAppShell` | Primary 4 + More |
| Public / Marketplace | `EosPublicShell` | Compact header |

Overflow destinations open a modal sheet; selecting still calls the same `onSelected(index)`.

---

## 5. Forms adapted

- `EosAdaptiveFormLayout` — 1 column (phone), 2 columns (tablet/desktop)
- Touch-friendly min heights on compact action bars / button bars
- Future forms should wrap fields in `EosAdaptiveFormLayout` instead of fixed `Row`s

---

## 6. Tables adapted

`EosDataTable`:

- **Desktop/tablet:** DataTable inside horizontal scroll (no compression)
- **Phone:** Per-row cards with column label → value pairs
- Toolbar stacks search above tools on compact
- Bulk actions wrap on compact

---

## 7. Dashboard adaptations

- Organizer KPI strip → `EosAdaptiveKpiGrid`
- Executive KPI strip → `EosAdaptiveKpiGrid`
- Organizer dashboard: duplicate header actions hidden on compact (available in top bar overflow)
- Nested scroll removed from organizer dashboard body (scaffold already scrolls)
- Page titles no longer crush into one-character columns

---

## 8. Files changed

### Framework (new / core)

- `mobile/lib/eos/tokens/eos_breakpoints.dart`
- `mobile/lib/eos/layout/eos_responsive.dart`
- `mobile/lib/eos/layout/eos_adaptive.dart` **(new)**
- `mobile/lib/eos/layout/eos_page_scaffold.dart`
- `mobile/lib/eos/layout/eos_section.dart`
- `mobile/lib/eos/navigation/eos_app_shell.dart`
- `mobile/lib/eos/widgets/tables/eos_data_table.dart`
- `mobile/lib/eos/tokens/eos_tokens.dart`
- `mobile/lib/eos/eos.dart`

### Workspace chrome

- `mobile/lib/features/workspace/widgets/workspace_experience_shell.dart`
- `mobile/lib/features/organizer/screens/organizer_home_screen.dart`
- `mobile/lib/features/organizer/screens/organizer_dashboard_screen.dart`
- `mobile/lib/features/organizer/widgets/organizer_dashboard_kpi_strip.dart`
- `mobile/lib/features/vendor/vendor_home_screen.dart`
- `mobile/lib/portals/customer/shell/customer_shell.dart`
- `mobile/lib/portals/attendee/widgets/attendee_top_bar.dart`
- `mobile/lib/features/admin/shell/admin_shell.dart`
- `mobile/lib/features/admin/shell/admin_top_bar.dart`
- `mobile/lib/features/admin/shell/admin_nav.dart`
- `mobile/lib/features/super_admin/super_admin_home_screen.dart`
- `mobile/lib/features/super_admin/executive/widgets/executive_kpi_strip.dart`

### Docs

- `docs/ADAPTIVE_UI_ARCHITECTURE_REPORT.md` (this file)

---

## 9. Remaining screens

Architecture covers **all screens that compose EOS shells / page scaffold / data table / adaptive grids**. Remaining presentation debt is screens still using ad-hoc fixed-width `Row`s outside EOS:

| Area | Remaining work |
|------|----------------|
| Event create wizard (`wizard_v2`) | Prefer `EosAdaptiveFormLayout` for multi-field steps |
| Operations dense panels | Audit fixed-width toolbars inside Live Ops |
| Marketplace / customer celebration widgets | Some carousels still use local width constants — migrate to `EosAdaptive` |
| Auth / onboarding shells | Spot-check compact stacking of CTAs |
| Finance / analytics custom charts | Ensure parent constraints use adaptive grids, not fixed pixel strips |
| Vendor secondary screens | Inherit shell/table adaptivity; spot-check custom toolbars |

These do **not** require business/API changes — only continued migration onto EOS adaptive primitives.

---

## 10. Regression summary

| Check | Result |
|-------|--------|
| Business workflows / APIs / RBAC / routing indices | Unchanged |
| Phase 14–18 frozen flows | Presentation-only; destinations still map to same screens |
| Organizer phone chrome (title crush / 10-item nav) | Fixed via scaffold + More overflow |
| Desktop/web rich rail experience | Preserved (`extended: true` ≥ 1024) |
| `dart analyze` on changed adaptive surface | No errors introduced |

### Manual validation checklist

- [ ] Android phone APK — Organizer home readable; bottom nav ≤5 slots + More
- [ ] Android tablet — compact rail, usable tables
- [ ] Small browser width — compact layout
- [ ] Large browser / desktop — extended rail + tables
- [ ] Vendor / Admin / Super Admin / Attendee shells — same rules

---

## Final result

⚠ Additional Adaptive UI Work Required
