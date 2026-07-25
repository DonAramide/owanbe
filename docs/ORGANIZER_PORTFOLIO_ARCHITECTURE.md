# Organizer Portfolio Architecture

**Phase:** 6 — Enterprise Intelligence  
**Route:** `/portfolio`

---

## Overview

The Organizer Portfolio Workspace is a **dedicated intelligence surface** — not a replacement for Home (`/home`) or My Events (`/events/mine`). It aggregates data from all organizer events into a single scrollable workspace.

---

## Component Diagram

```
┌─────────────────────────────────────────────────────────┐
│           OrganizerPortfolioWorkspaceScreen             │
├─────────────────────────────────────────────────────────┤
│ Executive Strip │ KPI Grid │ Upcoming │ Timeline        │
│ Analytics Panel │ Copilot  │ Vendor   │ Guest           │
│ Financial Panel │ Templates│ Automation│ Briefing       │
└──────────────────────────┬──────────────────────────────┘
                           │
              organizerPortfolioWorkspaceProvider
                           │
              customerEventsProvider
                           │
                   GET organizers/me/events
                           │
              buildOrganizerPortfolioWorkspace()
```

---

## Builder Functions

| Builder | Output |
|---------|--------|
| `buildPortfolioKpiSnapshot` | Portfolio KPIs |
| `buildPortfolioEventRows` | Event comparison rows |
| `buildPortfolioTimeline` | Chronological timeline |
| `buildPortfolioAnalytics` | Trend + comparison analytics |
| `buildPortfolioCopilotInsights` | AI copilot messages |
| `buildPortfolioVendorRankings` | Vendor leaderboard |
| `buildPortfolioGuestInsight` | Cross-event guest stats |
| `buildPortfolioFinancialSnapshot` | Financial rollup |
| `buildPortfolioAutomationAlerts` | Risk alerts |
| `buildExecutiveDashboard` | Executive metrics |
| `buildWeeklyOrganizerBriefing` | Briefing text |
| `buildOrganizerPortfolioWorkspace` | Full workspace bundle |

---

## Navigation Graph

```
/home (OrganizerHomeHubScreen)
  ├── Open portfolio → /portfolio
  └── Open event → /events/:id (Event Desktop)

/portfolio (OrganizerPortfolioWorkspaceScreen)
  ├── Open event → /events/:id
  ├── Open guests hub → /guests
  ├── Template → seedDuplicateEvent → /events/create
  └── Copy briefing → Clipboard
```

---

## Refresh Strategy

```dart
refreshOrganizerPortfolio(ref)
  → invalidate organizerPortfolioWorkspaceProvider
  → invalidate customerEventsProvider
```

Watches `customerEventRevisionProvider` for automatic invalidation on event mutations.

---

## Extension Points (Future, Non-Core)

1. Server-side `GET organizers/me/portfolio` for heavy aggregations
2. Parallel fan-out to `eventClosingWorkspaceProvider` for completed-event scores
3. Real-time copilot via backend LLM (currently rule-based on portfolio patterns)
4. Portfolio-level finance API batch endpoint

---

## Constraints Honored

- Event Desktop unchanged
- Planning / Operations / Closing centers unchanged
- No duplicate event or vendor modules
- Templates reuse Wizard V2 + duplicate seed provider
