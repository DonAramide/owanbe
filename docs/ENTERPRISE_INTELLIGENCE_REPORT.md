# Enterprise Intelligence Report

**Platform:** Owanbe Event OS — Phase 6  
**Scope:** Multi-event organizer intelligence layer

---

## Executive Summary

Phase 6 elevates Owanbe from managing **one event at a time** to managing an **entire event portfolio** with enterprise-grade intelligence. All capabilities build on the certified Event OS (Phases 1–5) without parallel systems.

---

## Intelligence Domains

### 1. Portfolio Intelligence
- Cross-event KPI rollup (events, revenue, profit, guests, tickets, vendors)
- Upcoming events and portfolio timeline
- Historical success score averaging

### 2. Analytics Intelligence
- Monthly revenue, guest growth, attendance, vendor cost trends
- Profit and completion quality trends
- Budget efficiency and event-to-event comparisons

### 3. AI Copilot Intelligence
- Pattern detection: catering spend, wedding attendance, vendor reliability
- Proactive alerts: missing security, seasonal performance, budget overrun patterns
- Ticket price band analysis

### 4. Vendor Intelligence
- Cross-event vendor ranking by reliability, completion, acceptance
- Repeat hire frequency and average cost
- Best event category per vendor

### 5. Guest Intelligence
- Repeat attendees across events
- VIP counts, no-show trends, RSVP behavior
- Most-invited guest identification

### 6. Financial Intelligence
- Monthly revenue and profit rollups
- Outstanding settlements and refund trends
- Budget accuracy and average ticket yield
- Top revenue events

### 7. Automation Intelligence
- Planning risk detection (unpublished drafts near date)
- Vendor gap detection
- Low ticket sales warnings
- Budget overrun risk
- Missing guest lists

### 8. Executive Intelligence
- Portfolio health index
- Vendor network size
- Operational risk level
- AI recommendation feed

---

## Data Philosophy

**Aggregate at portfolio layer; drill down to Event OS modules.**

No portfolio-specific business APIs were introduced. Intelligence is computed client-side from `CustomerEvent` list data, with optional drill-down to per-event providers when the organizer opens an event.

---

## Entry Points

| Surface | Route | Role |
|---------|-------|------|
| Home Hub card | `/home` → Open portfolio | Discovery |
| Portfolio Workspace | `/portfolio` | Primary intelligence |
| Event drill-down | `/events/:id` | Single-event OS |

---

## Competitive Positioning

The platform now combines:
- **Project management** — portfolio timeline + automation alerts
- **CRM** — guest repeat tracking + vendor rankings
- **Finance** — cross-event revenue and budget intelligence
- **AI assistant** — proactive copilot + weekly briefings
- **Event operations** — certified single-event OS underneath

Built specifically for event organizers — not a generic dashboard bolted on.
