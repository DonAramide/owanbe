# Template System Architecture

**Phase:** 6 — Enterprise Intelligence  
**Elevates:** Phase 5 Duplicate Event flow

---

## Design Principle

Event Templates reuse the **Event Wizard V2** and **duplicate seed provider** — no duplicate wizard, no new event creation flow.

---

## Flow

```
OrganizerPortfolioWorkspaceScreen
  └── Template chip (Wedding, Birthday, etc.)
        └── buildTemplateDraft(EventTemplateKind)
              └── seedDuplicateEvent(ref, draft)
                    └── context.push('/events/create')
                          └── EventCreateWizardV2Screen._applyDuplicateSeed()
                                └── createEventFromV2Draft()
```

Identical pipeline to Phase 5 "Duplicate Event" from Closing Center.

---

## Template Catalog

**File:** `portfolio/event_template_catalog.dart`

| Template | Category | Typical Guests | Access Mode |
|----------|----------|----------------|-------------|
| Wedding | wedding | 250 | Private invitation |
| Birthday | birthday | 150 | Private invitation |
| Conference | conference | 300 | Public ticketed |
| Church Event | church | 400 | Private invitation |
| Corporate Event | corporate | 200 | Public ticketed |
| Family Event | family | 100 | Private invitation |

---

## Template Contents

Each `EventTemplateDefinition` includes:

| Field | Purpose |
|-------|---------|
| `requiredServices` | Pre-selected vendor service categories |
| `budgetMinor` | Default budget baseline |
| `expectedGuests` | Guest count default |
| `ticketTiers` | Pre-configured tiers (public templates) |
| `tags` | Template metadata tags |
| `eventAccessMode` | Private vs public ticketed |

---

## AI Planning Baseline

```dart
templatePlannerBaseline(EventTemplateKind kind)
  → AiPlannerInputs(eventType, budgetMinor, guestCount, location)
```

Maps template kind to `AiPlannerEventType` for consistent AI Planner behavior when the event is created and opened.

---

## Template vs Duplicate vs Similar

| Action | Source | Suffix | Date offset |
|--------|--------|--------|-------------|
| Duplicate (Phase 5) | Completed event | "(Copy)" | +1 year |
| Similar (Phase 5) | Completed event | "(Similar)" | +1 year |
| Template (Phase 6) | Catalog definition | "Template YYYY" | +90 days |

All converge on `EventWizardV2Draft` → Wizard V2.

---

## Extension (Non-Core)

- Save custom templates from completed events
- Share templates across organizer team
- Backend template library API
