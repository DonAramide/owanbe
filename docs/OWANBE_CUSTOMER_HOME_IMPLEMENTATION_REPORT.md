# OWANBE CUSTOMER HOME IMPLEMENTATION REPORT

**Date:** 2026-07-20  
**Scope:** Customer Home (post-login) UI only — pixel-faithful approved concept implementation  
**Verdict:** Implemented per approved UI contract (concept image + specification)

---

## Summary

Customer Home has been replaced with the approved premium landing experience. Users discover Owanbe first; role selection appears only after **Explore Owanbe** or the **three-dot menu** — both open the identical **Join Owanbe As** screen.

Nothing after role selection was rewritten. Cards call the same activate / onboard / enter paths used before via `openHomeWorkspace()`.

---

## Screen hierarchy

| Screen | Widget | Entry |
|---|---|---|
| Screen 1 — Welcome | `CustomerHomeWelcomeTab` | Home tab of `OwanbeHomeScreen` |
| Screen 2 — Join Owanbe As | `JoinOwanbeAsScreen` | `Explore Owanbe` **or** three-dot button → `JoinOwanbeAsScreen.open` |
| Activity / Profile | Unchanged | Bottom nav tabs 1 / 2 |

`JoinOwanbeAsScreen` is pushed with a local `PageRouteBuilder` (fade + slide). **go_router routes were not added or changed.**

---

## Widget hierarchy

```
OwanbeHomeScreen
├── AppBar (Activity / Profile only)
│   └── WorkspaceSwitcher
├── IndexedStack
│   ├── [0] CustomerHomeWelcomeTab
│   │   ├── CustomerHomeBackground (owambe_splash.jpg + purple gradient + parallax)
│   │   ├── _FloatingParticlesPainter (subtle champagne/white particles)
│   │   ├── Top: CustomerHomeLogo | CustomerHomeThreeDotButton (⋮)
│   │   ├── RichText headline (white + gold two-tone)
│   │   ├── CustomerHomeGoldDivider
│   │   ├── Intro copy (approved wording)
│   │   ├── CustomerHomeExploreButton → JoinOwanbeAsScreen
│   │   └── CustomerHomeSeeHowItWorks → glass modal sheet
│   ├── [1] HomeActivityTab
│   └── [2] HomeProfileTab
└── NavigationBar (Home / Activity / Profile — gold active state)
```

```
JoinOwanbeAsScreen
├── CustomerHomeBackground (blurBackground: true)
├── Back chevron | CustomerHomeThreeDotButton (decorative on this screen)
├── Title: Join Owanbe As
├── Subtitle: Choose how you want to get started
└── _JoinAsCard ×3 (glassmorphism, colored icon squares, chevron)
    └── onTap → openHomeWorkspace(...)  // existing semantics
```

**Shared design system:** `customer_home_design.dart`

| Component | Purpose |
|---|---|
| `CustomerHomeDesign` | Palette (#E1B35B gold, #2D1635 plum), copy constants |
| `CustomerHomeThreeDotButton` | Circular gold-bordered ⋮ control |
| `CustomerHomeExploreButton` | Full-width gold stadium CTA with chevron |
| `CustomerHomeSeeHowItWorks` | Play-circle + gold label |
| `CustomerHomeLogo` | Owanbe wordmark asset |
| `CustomerHomeBackground` | Cinematic photo + gradient overlay (+ optional blur) |
| `CustomerHomeGoldDivider` | Gold accent line under headline |
| `CustomerHomeRoleStyle` | Attendee / Organizer / Vendor icon colors |

---

## Navigation mapping

| UI action | Behavior |
|---|---|
| Explore Owanbe | `JoinOwanbeAsScreen.open(context)` |
| Three-dot button (Welcome) | **Same** `JoinOwanbeAsScreen.open(context)` — no popup menu |
| See how it works | Modal glass sheet with intro copy; CTA re-opens Join As |
| Attendee / Organizer / Vendor card | `openHomeWorkspace(context, ref, ws, state)` |
| Back (Join As) | `Navigator.maybePop()` |

Shared helper: `lib/features/home/home_workspace_actions.dart`

Preserves prior status handling:

| `WorkspaceStatus` | Action |
|---|---|
| `active` | `switchTo` + `context.go(launcherTarget)` |
| `inProgress` | `context.push(onboarding)` |
| `notActivated` | `context.push(activate)` |
| `suspended` | SnackBar |

---

## Animation mapping

| Location | Motion |
|---|---|
| Welcome enter | Fade + slight upward slide (~850ms, `Curves.easeOutCubic`) |
| Ambient background | Slow parallax drift (20s loop, ±8px horizontal / ±5px vertical) |
| Particles | 24 soft floating dots via `CustomPaint` |
| Explore → Join | Fade + slide `PageRouteBuilder` (~400ms) |
| Join cards | Glass blur (`BackdropFilter` σ=16) + subtle shadow |
| See how it works | Blurred modal bottom sheet |

No video assets. Motion kept subtle for tablet performance.

---

## Assets used

| Asset | Use |
|---|---|
| `assets/branding/owambe_splash.jpg` | Primary celebration background (Welcome + Join As) |
| `assets/branding/owambe_logo.png` | Top-left wordmark on Welcome screen |
| `assets/branding/walkthrough2.jpg` | Fallback if splash unavailable (errorBuilder) |

**No new asset files shipped.** Existing bundled branding only.

---

## Approved copy (implemented verbatim)

**Headline**

> Bringing every event  
> to your doorstep.

(second line in gold)

**Introduction**

> Owanbe is your all-in-one platform to discover, plan and manage unforgettable events with ease.
>
> Whether you want to attend, organize, or offer services—we've got you covered.

**Role cards**

| Role | Description |
|---|---|
| Attendee | Discover and attend amazing events. |
| Organizer | Create and manage exceptional events. |
| Vendor | Offer your services and grow your business. |

---

## Performance review

- Two `AnimationController`s on Welcome tab only (ambient + enter); disposed on unmount
- Particles: 24 circles per frame via lightweight `CustomPaint`
- Single bundled JPEG background (scaled 1.06× for parallax bleed)
- Join route: local Navigator push only when user taps Explore or ⋮
- `BackdropFilter` used on Join cards and modal sheet only (not full-screen on Welcome)

Startup path / Auth / Supabase / providers unchanged.

---

## Accessibility review

| Item | Status |
|---|---|
| Text contrast | White / gold on dark purple gradient — high contrast |
| Primary CTA | Full-width button, 18px vertical padding, ≥44px tap target |
| Three-dot button | 44×44 circular target with gold border |
| Join cards | Icon + title + description + chevron; full-row tap |
| Back button | Standard `IconButton` with tooltip |
| SafeArea | Applied on Welcome and Join screens |
| Responsive type | Headline scales to 30px on narrow widths (<380dp) |
| Bottom nav | Labels preserved (Home / Activity / Profile); badge on Activity |

---

## Regression report

| Area | Status |
|---|---|
| Authentication | Untouched |
| Supabase | Untouched |
| Unified Identity | Untouched (`userIdentityProvider` read-only on Join screen) |
| Customer / Admin separation | Untouched |
| Admin app / `main_admin.dart` | Untouched |
| go_router / ExperienceRoutes | Untouched |
| Workspace activate / onboard / enter | Same `openHomeWorkspace` semantics |
| Activity / Profile tabs | Preserved |
| Bottom navigation structure | Preserved (Home / Activity / Profile) |
| Organizer / Vendor / Attendee OS | Untouched |
| APIs / DB / Riverpod providers | Untouched |

**Home-only UI change:** branded welcome + Join As gate before workspace entry.

---

## Files

**Added**

- `mobile/lib/features/home/widgets/customer_home_design.dart` — shared palette + components
- `mobile/lib/features/home/widgets/customer_home_welcome_tab.dart` — Screen 1
- `mobile/lib/features/home/screens/join_owanbe_as_screen.dart` — Screen 2
- `mobile/lib/features/home/home_workspace_actions.dart` — shared workspace navigation

**Updated**

- `mobile/lib/features/home/screens/owanbe_home_screen.dart` — Welcome tab + bottom nav gold active styling
- `mobile/lib/features/home/widgets/living_home_feed.dart` — shared open helper; no longer Home tab body

---

## Concept alignment notes

Implementation targets ≥95% visual fidelity to the approved concept image:

- Two-tone left-aligned headline with gold divider
- Circular gold-bordered three-dot button (direct navigation, not dropdown)
- Solid gold stadium **Explore Owanbe** button with chevron
- **See how it works** with play-circle icon (not underlined TextButton)
- Join As: heavily blurred background, glass cards, role-specific icon square colors (purple / orange / green)
- Dark purple bottom nav with gold active Home icon

If any element drifts from the concept during device QA, compare against the approved image and adjust spacing/colors in `customer_home_design.dart` only.
