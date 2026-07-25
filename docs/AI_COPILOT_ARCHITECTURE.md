# AI Copilot Architecture

**Phase:** 6 — Enterprise Intelligence  
**Builder:** `buildPortfolioCopilotInsights()`

---

## Design Principle

The AI Organizer Copilot is an **elevation of AI Planner infrastructure** — not a new AI engine. It generates **proactive recommendations** from portfolio patterns rather than reactive per-event reports.

---

## Architecture

```
customerEventsProvider (all events)
        │
        ▼
buildPortfolioCopilotInsights(events)
        │
        ├── Budget pattern analysis (catering share)
        ├── Category attendance patterns (weddings)
        ├── Vendor reliability patterns (repeat vendors)
        ├── Ticket price band analysis (median sold tier)
        ├── Proactive gap detection (missing security on next event)
        ├── Seasonal performance (December weddings)
        └── Budget risk by category (birthday overrun rate)
        │
        ▼
List<CopilotInsight> (priority-sorted)
        │
        ▼
OrganizerPortfolioWorkspaceScreen → _CopilotPanel
        │
        └── Deep-link → /events/:id (when eventId set)
```

---

## CopilotInsight Model

```dart
class CopilotInsight {
  final String message;      // Human-readable recommendation
  final String category;     // Budget pattern, Guest pattern, Proactive, etc.
  final String? eventId;     // Optional event deep-link
  final int priority;        // Higher = shown first
}
```

---

## Per-Event AI Planner Relationship

| Layer | Scope | Provider / Builder |
|-------|-------|-------------------|
| Event AI Planner | Single event | `buildAiPlannerPlan()` |
| Closing AI Debrief | Completed event | `buildEventAiDebrief()` |
| Portfolio Copilot | All events | `buildPortfolioCopilotInsights()` |

All three reuse `AiPlannerEventType`, `AiPlannerInputs`, and event model signals.

---

## Example Insights

| Insight | Trigger |
|---------|---------|
| "You consistently allocate a high share of budget to catering" | Catering > 28% of total budget across completed events |
| "Your weddings average 95% attendance" | Wedding category sell-through average |
| "Vendor X has completed N events successfully" | Top vendor by orders across portfolio |
| "Your best-performing ticket price band centers around ₦X" | Median sold tier price |
| "Your next event is missing Security" | Upcoming event with no security vendor |
| "Wedding events perform better in December" | December wedding success scores ≥ 80 |
| "Birthday events usually exceed budget by 12%" | Birthday overrun rate ≥ 10% |

---

## Weekly Briefing

`buildWeeklyOrganizerBriefing()` composes:
- Portfolio summary line
- Next upcoming event
- Top automation alert
- Top copilot insight

Exported via Clipboard from portfolio UI.

---

## Future Roadmap (Non-Core)

- Backend LLM integration for natural language copilot
- Push notifications for automation alerts
- Copilot actions that pre-fill planning modules
