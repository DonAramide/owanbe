# Portfolio Analytics Model

**Phase:** 6 — Enterprise Intelligence  
**Builder:** `buildPortfolioAnalytics()`

---

## Purpose

Compare events and surface trends across the organizer portfolio without duplicating per-event analytics modules.

---

## Model Structure

```dart
class PortfolioAnalyticsSnapshot {
  List<PortfolioTrendPoint> revenueTrend;
  List<PortfolioTrendPoint> guestGrowth;
  List<PortfolioTrendPoint> attendanceTrend;
  List<PortfolioTrendPoint> vendorCostTrend;
  List<PortfolioTrendPoint> ticketPerformance;
  List<PortfolioTrendPoint> profitTrend;
  List<PortfolioTrendPoint> completionQuality;
  List<PortfolioTrendPoint> budgetEfficiency;
  List<PortfolioEventRow> eventComparisons;
}

class PortfolioTrendPoint {
  String label;   // YYYY-MM month bucket
  double value;
}
```

---

## Aggregation Method

All trends use `_monthlyRollup()`:

```
For each event:
  bucket = event.startsAt → "YYYY-MM"
  buckets[bucket] += valueFor(event)

Output: sorted month keys → PortfolioTrendPoint list (max 6 months)
```

---

## Metric Definitions

| Trend | Formula (per event) |
|-------|---------------------|
| Revenue | `event.revenueMinor` |
| Guest growth | `expectedGuests` or `attendees.length` |
| Attendance | `ticketsSold / capacity × 100` |
| Vendor costs | Sum of `vendor.revenueMinor` |
| Ticket performance | `event.ticketsSold` |
| Profit | `revenueMinor - budgetMinor × 0.7` |
| Completion quality | `computeEventSuccessScore(event)` (completed only) |
| Budget efficiency | `revenueMinor / budgetMinor × 100` (budget > 0) |

---

## Event Comparisons

`eventComparisons` = top 8 events sorted by `revenueMinor` descending.

Each row includes: title, category, status, revenue, tickets sold, success score, guest count.

Deep-links to `/events/:eventId` on tap.

---

## Data Sources

| Field | Source |
|-------|--------|
| Revenue / tickets | `CustomerEvent.ticketTiers` computed getters |
| Guests | `CustomerEvent.expectedGuests`, `attendees` |
| Vendors | `CustomerEvent.vendors` |
| Budget | `CustomerEvent.budgetMinor` |
| Success score | `computeEventSuccessScore()` (shared with portfolio KPIs) |

**No separate analytics API or storage.**

---

## UI Presentation

`_AnalyticsPanel` in `OrganizerPortfolioWorkspaceScreen`:
- Trend rows show latest month value
- Event comparison list with revenue formatting via `formatRevenue()`

---

## Historical Comparisons

Organizers can compare:
- Month-over-month revenue and profit
- Guest growth trajectory
- Attendance rate changes
- Vendor cost escalation
- Budget efficiency across event types

Drill-down to single-event Closing workspace for completed event historical dimensions.
