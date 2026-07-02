# Phase 43.8 — Accessibility Certification

**Date:** 2026-06-04  
**Standard:** WCAG 2.1 AA target (pragmatic audit)

---

## Executive summary

Event OS scaffold (Phase 42.6) improved structure: breadcrumbs, tooltips on icon actions, consistent padding via `EosSpacing`. EOS design tokens support contrast on primary surfaces. Full screen-reader certification requires device testing with TalkBack/VoiceOver — this report is a static audit.

**Accessibility grade:** 7/10 — **CONDITIONAL PASS** with P1 gaps on marketplace filters and guest search semantics.

---

## Verification matrix

| Criterion | Status | Notes |
|-----------|--------|-------|
| Touch targets | PASS | IconButtons default 48dp; EOS buttons meet min |
| Font scaling | PARTIAL | `MediaQuery.textScaler` respected in EOS text styles; some fixed `height:` on images |
| Keyboard navigation | PARTIAL | Web/desktop: focus order mostly linear; modals need trap audit |
| Screen readers | PARTIAL | Tooltips present; missing `Semantics` on guest list tiles |
| Contrast | PASS | EOS palette — plum/canvas tokens |
| Focus order | PARTIAL | Drawers/endDrawer — verify announce on open |
| Large screens | PASS | `LayoutBuilder` KPI grid ≥720px on guests |
| Tablet layouts | PASS | Workspace modules use scroll body |
| Desktop layouts | PASS | Customer portal responsive columns |

---

## Per-area notes

### Customer Home

- Hero and cards: tappable with ink well — OK.
- Carousel: horizontal scroll — add semantic "carousel" label P2.

### Event modules

- `EventModuleScaffold` AppBar back + actions have tooltips.
- `EventEmptyState` — readable headlines.
- `EventLoadingSkeleton` — no accessibility loading live region — P2.

### Guests

- Search field has hint text — OK.
- `GuestListTile` — should wrap with `Semantics(button: true, label: ...)` P1.

### Marketplace

- Filter chips — small touch on dense rows P2.
- Vendor cards — business name visible.

### Forms (add guest, request vendor)

- Labels on `TextField` / `EosSelectField` — OK.

---

## Recommendations

| ID | Action | Priority |
|----|--------|----------|
| A11Y-1 | Semantics on `GuestListTile` and `PremiumVendorCard` | P1 |
| A11Y-2 | `MergeSemantics` on KPI row | P2 |
| A11Y-3 | Loading announcement via `SemanticsService` | P2 |
| A11Y-4 | Manual VoiceOver pass on Command Center | P0 before GA |

---

## Testing performed

- Static widget audit
- EOS token contrast review (design system)
- No automated `flutter test` accessibility goldens

---

## Sign-off

**CONDITIONAL PASS** — Product usable with assistive tech for core flows; formal device certification pending.
