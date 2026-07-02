# Phase 42.4 — EOS Product Polish & Design System Consolidation

**Status:** Complete  
**Scope:** UI, UX, consistency, and usability only — no new features, no DB migrations, no API changes, no navigation restructuring.

---

## Objective

Transform Event OS into a premium, cohesive product by standardizing on the EOS Design System across the Event Workspace and all event module screens.

---

## 1. Event Workspace Visual Audit

### Sections reviewed

| Section | Location | Findings (before) | Resolution |
|--------|----------|-------------------|------------|
| Hero | `CelebrationHero` | Inconsistent padding vs modules | `EosSpacing.pagePadding` + `EventResponsiveCanvas` |
| Countdown | Inside hero | OK | Preserved |
| Planning Ring | `PlanningProgressRing` | Duplicate V3 ring removed in 42.3 | Single ring under `EosSection` |
| Summary Grid | `CommandSummaryGrid` | Mixed card styles | Wrapped in `EosSection` |
| Activity Feed | `CommandActivityFeed` | Section header ad-hoc | `EosSection` with consistent rhythm |
| Module Sections | `EventWorkspaceModuleSections` | `ActionChip` quick tiles, fixed grid | `OutlinedButton.icon`, responsive grid, semantics |
| Quick Actions | Registry chips | Inconsistent with EOS buttons | `OutlinedButton.icon` via registry |
| Reminder Widgets | `EventWorkspaceReminders` | Bridge only | Preserved workflow |
| Celebration Suite | Registry category | Hidden gallery/memories | `visible: false` for unfinished modules |

### Hierarchy (applied)

```
Current task / hero
    ↓
Primary KPIs (summary grid, planning ring)
    ↓
Actions (lifecycle, AI planner, module tiles)
    ↓
History (activity feed)
    ↓
Advanced (registry categories)
```

### Remaining workspace notes

- Workspace app bar remains a lightweight shell bar (not `EventModuleScaffold`) — intentional: it is the root, not a sub-module.
- Analytics and Settings registry entries hidden (`visible: false`) — no “Coming Soon” snackbars on flagship workspace.

---

## 2. EOS Component Standardization

### New shared widgets (Phase 42.4)

| Widget | Path | Purpose |
|--------|------|---------|
| `EventModuleScaffold` | `workspace/event_module_scaffold.dart` | Unified app bar + responsive canvas |
| `EventModuleScrollBody` | same | Hero → KPI → content → activity → actions rhythm |
| `EventResponsiveCanvas` | same | Max width 1120px on tablet/desktop |
| `EventErrorView` | `workspace/widgets/event_error_view.dart` | Human-friendly errors + retry |
| `EventFriendlyErrors` | `workspace/widgets/event_friendly_errors.dart` | Copy constants (no raw exceptions) |
| `EventLoadingSkeleton` | `workspace/widgets/event_loading_skeleton.dart` | Workspace / module / list variants |
| `EventEmptyStates` | `workspace/event_empty_states.dart` | Preset empty states per module |

### Standardized EOS primitives used

- `EosSection` — section headers (replacing ad-hoc `SectionHeader` in migrated modules)
- `EosSurfaceCard` — elevated surfaces
- `EosSpacing.pagePadding` — consistent page insets
- `EosResponsive` — grid columns in module tiles
- `EmptyStateCard` — extended with `secondaryActionLabel` / `onSecondaryAction`

### Intentional exceptions

| Surface | Why |
|---------|-----|
| `CustomerEventAttireScreen` | Tabbed app bar (`TabBar` in `AppBar.bottom`) — custom scaffold retained; errors/loading polished |
| `CustomerEventWallDisplayScreen` | Full-screen venue display (dark theme) — not a standard module layout |
| `CustomerEventSeatingScreen` | Canvas + horizontal guest strip — column body, not scroll scaffold |
| Inline `CircularProgressIndicator` (18–20px) | Button / app-bar save indicators only |

---

## 3. Unified Page Scaffold

Every event module now follows:

```
Hero (optional)
    ↓
Primary KPI (optional)
    ↓
Content
    ↓
Timeline / Activity (optional)
    ↓
Quick Actions (optional)
    ↓
Bottom safe spacing (EosSpacing.xxxl)
```

### Modules on `EventModuleScaffold`

| Module | Screen | Scaffold |
|--------|--------|----------|
| Budget | `customer_event_budget_screen.dart` | ✅ |
| Guests | `customer_event_guests_screen.dart` | ✅ (+ `scaffoldKey` for end drawer) |
| Rentals | `customer_event_rentals_screen.dart` | ✅ |
| Invitations | `customer_event_invitations_screen.dart` | ✅ |
| Program | `customer_event_program_screen.dart` | ✅ |
| Vendor pipeline | `customer_event_vendor_pipeline_screen.dart` | ✅ |
| Seating | `customer_event_seating_screen.dart` | ✅ |
| Event day | `customer_event_day_screen.dart` | ✅ |
| AI Planner | `customer_event_ai_planner_screen.dart` | ✅ |
| Website | `customer_event_website_screen.dart` | ✅ |
| Wall | `customer_event_wall_screen.dart` | ✅ |
| Attire | `customer_event_attire_screen.dart` | Partial (tabbed) |

---

## 4. Empty States

`EventEmptyStates` presets:

| Preset | Icon | Primary action |
|--------|------|----------------|
| `guests` | groups | Add guest (+ optional import) |
| `guestsFiltered` | search_off | Add guest |
| `vendors` | handshake | Browse marketplace |
| `invitations` | mail | Create invitation |
| `program` | schedule | Add program item |
| `budget` | wallet | — |
| `rentals` | inventory | Browse rentals |
| `website` | language | Open builder |
| `wall` | forum | Add message |
| `seating` | table | Add table |
| `activity` | timeline | — |

Wired in: guests, vendors pipeline, program, rentals (prior session + this pass).

---

## 5. Human-Friendly Errors

### Removed

- `error.toString()` in all `customer_event_*.dart` screens
- `'$e'` in snackbars and `EmptyStateCard.message` across event modules

### `EventErrorView` factories

- `.workspace()` — workspace load failure
- `.module(moduleLabel:)` — per-module load failure with retry + back

### Snackbar actions

`EventFriendlyErrors.actionFailedMessage` — generic action failure copy.

---

## 6. Loading Experience

| Pattern | Replacement |
|---------|-------------|
| `Center(CircularProgressIndicator())` on full pages | `EventLoadingSkeleton()` |
| Workspace initial load | `EventLoadingSkeleton(variant: workspace)` |
| Route ownership check | `EventLoadingSkeleton` in `CustomerEventRouteScreen` |
| Button / app-bar busy | Small inline spinner (preserved) |

No blank screens on event module entry.

---

## 7. Information Hierarchy

Applied per module via `EventModuleScrollBody`:

- **Program:** day widget → timeline → activity log
- **Event day:** hero → program day → check-in KPIs → vendor/wall/emergency → live feed
- **AI planner:** hero banner → inputs → generated sections in `EosSection` blocks
- **Budget:** health card KPI → breakdown sections (prior pass)

---

## 8. Accessibility Pass

### Improvements made

| Area | Change |
|------|--------|
| Error surfaces | `Semantics` label on `EventErrorView` |
| Module tiles | `semanticLabel` on registry section tiles |
| App bars | Back button `tooltip: 'Back to workspace'` |
| Touch targets | `OutlinedButton.icon` for module quick actions (≥48dp) |
| Color | Errors use `onSurfaceVariant` for body copy (readable secondary text) |

### Documented gaps (Phase 42.5+)

| Area | Note |
|------|------|
| Seating canvas | Drag targets lack explicit semantics — complex interaction |
| Wall display | High-contrast dark mode OK; no screen-reader audit on ticker animation |
| Font scaling | EOS text styles scale; seating canvas labels are fixed-size |
| Keyboard (web) | Tab order not audited on seating drag-and-drop |
| Landscape tablet | `EventResponsiveCanvas` constrains width; seating canvas untested wide |

---

## 9. Responsive Layout Pass

| Breakpoint helper | Usage |
|-------------------|-------|
| `EventResponsiveCanvas` (1120px) | All `EventModuleScaffold` bodies |
| `EosSpacing.pagePadding` | Workspace + modules |
| `EosResponsive.isMobile` | Module tile grid columns, attire dashboard |
| Invitation QR row | `LayoutBuilder` at 640px (preserved) |

No module-specific breakpoint constants added.

---

## 10. Component Inventory

### Event module screens (polish status)

| Screen | Scaffold | Errors | Loading | Empty states |
|--------|----------|--------|---------|--------------|
| `EventWorkspace` | Shell | ✅ | ✅ skeleton | N/A |
| Budget | ✅ | ✅ | ✅ | via widgets |
| Guests | ✅ | ✅ | ✅ | ✅ |
| Invitations | ✅ | ✅ | ✅ | partial |
| Program | ✅ | ✅ | ✅ | ✅ |
| Vendor pipeline | ✅ | ✅ | ✅ | ✅ |
| Seating | ✅ | ✅ | ✅ | inline |
| Rentals | ✅ | ✅ | ✅ | ✅ |
| Website | ✅ | ✅ | ✅ | inline |
| Wall | ✅ | ✅ | ✅ | inline |
| Wall display | venue | ✅ | spinner | N/A |
| Event day | ✅ | ✅ | ✅ | N/A |
| AI planner | ✅ | ✅ | ✅ | N/A |
| Attire | tabbed | ✅ | ✅ | inline |

### Shell screens (out of scope)

`customer_home_screen`, `customer_my_events_screen`, `marketplace_screen` may still show raw errors — not event modules.

---

## Remaining inconsistencies

1. **Attire** — tabbed scaffold not migrated to `EventModuleScaffold` (needs `bottom` tab support).
2. **SectionHeader vs EosSection** — invitations/website/wall content sections still use legacy `SectionHeader` inside scroll bodies (copy is consistent; component dualism remains).
3. **Program timeline tiles** — raw `Card` + `ListTile` (not `EosSurfaceCard`).
4. **Vendor pipeline request cards** — raw `Card` (functional; style drift).
5. **Shell / marketplace** — raw error patterns outside event module scope.

---

## Polish checklist

- [x] Every Event module follows EOS visual language (scaffold + spacing)
- [x] No duplicate loading patterns on module entry
- [x] No “Coming Soon” on flagship Event Workspace (analytics/settings hidden)
- [x] No raw exception messages in `customer_event_*.dart`
- [x] Consistent `EosSpacing.pagePadding` on workspace + modules
- [x] `EventErrorView` shared across modules
- [x] `EventLoadingSkeleton` shared across modules
- [x] Responsive canvas on module bodies
- [x] Accessibility notes documented
- [x] Legacy Organizer code preserved (Phase 42.5)
- [x] Compatibility adapters preserved (Phase 42.5)

---

## Verification

```bash
cd mobile && flutter analyze
cd mobile && dart analyze lib/portals/customer
cd services/api && npm run build
```

---

## Files added

```
mobile/lib/portals/customer/workspace/event_module_scaffold.dart
mobile/lib/portals/customer/workspace/event_empty_states.dart
mobile/lib/portals/customer/workspace/widgets/event_error_view.dart
mobile/lib/portals/customer/workspace/widgets/event_friendly_errors.dart
mobile/lib/portals/customer/workspace/widgets/event_loading_skeleton.dart
docs/phase42/PHASE42_4_EOS_PRODUCT_POLISH.md
```

## Files updated (representative)

- `workspace/event_workspace.dart` — EOS sections, error/loading
- `workspace/widgets/event_workspace_module_sections.dart` — responsive grid, buttons
- `workspace/event_module_registry.dart` — hide analytics/settings
- `widgets/empty_state_card.dart` — secondary action
- All `customer_event_*_screen.dart` modules — scaffold / errors / loading
- `customer_portal.dart` — export new widgets

---

## Before / after (conceptual)

### Before

- Mixed `Scaffold` + raw `AppBar` per module
- `error.toString()` and `'$e'` in UI
- `Center(CircularProgressIndicator())` blank waits
- Ad-hoc padding (`EdgeInsets.all(context.eos.spacing.lg)`)
- “Coming soon” snackbars for analytics/settings on workspace

### After

- `EventModuleScaffold` + `EventModuleScrollBody` rhythm
- `EventErrorView` with retry and plain-English copy
- `EventLoadingSkeleton` placeholders
- `EosSpacing.pagePadding` + `EventResponsiveCanvas`
- Unfinished modules hidden from registry (no false promises)

---

## Next phase (42.5)

- Remove legacy Organizer portal code
- Eliminate compatibility adapters
- Migrate remaining shell screens to `EventErrorView`
- Consolidate `SectionHeader` → `EosSection` everywhere
