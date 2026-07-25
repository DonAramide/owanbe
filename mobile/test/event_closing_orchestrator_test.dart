import 'package:flutter_test/flutter_test.dart';
import 'package:owambe/portals/customer/closing/event_closing_actions.dart';
import 'package:owambe/portals/customer/closing/event_closing_models.dart';
import 'package:owambe/portals/customer/models/ai_planner_models.dart';
import 'package:owambe/portals/customer/models/command_center_models.dart';
import 'package:owambe/portals/customer/models/customer_event_models.dart';
import 'package:owambe/portals/customer/models/program_models.dart';
import 'package:owambe/portals/customer/operations/event_operations_models.dart';
import 'package:owambe/portals/customer/planning/event_planning_models.dart';
import 'package:owambe/shared/models/event_access_mode.dart';

CustomerEvent _completedEvent() => CustomerEvent(
      id: 'evt_close',
      title: 'Wedding 2026',
      tagline: 'Forever',
      description: 'Done',
      city: 'Lagos',
      venue: 'Eko Hotel',
      venueName: 'Grand Ballroom',
      startsAt: DateTime(2026, 3, 1, 14),
      endsAt: DateTime(2026, 3, 1, 22),
      category: 'Wedding',
      status: CustomerEventStatus.completed,
      coverGradientStart: 0xFF4B2C6F,
      coverGradientEnd: 0xFFD4A853,
      ticketTiers: const [
        CustomerTicketTier(
          id: 'tier_1',
          name: 'Regular',
          description: '',
          priceMinor: 50000,
          currency: 'NGN',
          capacity: 150,
          remaining: 30,
        ),
      ],
      vendors: const [],
      attendees: const [],
      expectedGuests: 150,
      budgetMinor: 1000000,
      eventAccessMode: EventAccessMode.publicTicketed,
    );

EventCommandCenterSnapshot _snapshot(CustomerEvent event) => buildCommandCenterSnapshot(
      event: event,
      opsGuests: const [],
      feed: const [],
    );

ProgramSnapshot _program() => ProgramSnapshot(
      items: const [],
      day: ProgramDaySnapshot(),
      recentActivity: const [],
    );

AiPlannerPlan _plan() => buildAiPlannerPlan(
      inputs: defaultInputsFromEvent(_completedEvent(), budgetMinor: 1000000),
      event: _completedEvent(),
      vendors: const [],
    );

void main() {
  test('closing mode when event is completed', () {
    final mode = resolveEventDesktopMode(
      event: _completedEvent(),
      lifecycleStage: EventLifecycleStage.completed,
    );
    expect(mode, EventDesktopMode.closing);
  });

  test('archived mode overrides completed', () {
    final mode = resolveEventDesktopMode(
      event: _completedEvent(),
      lifecycleStage: EventLifecycleStage.completed,
      isArchived: true,
    );
    expect(mode, EventDesktopMode.archived);
  });

  test('closing workspace aggregates summary without duplicate finance logic', () {
    final event = _completedEvent();
    final snapshot = _snapshot(event);
    final workspace = buildEventClosingWorkspace(
      event: event,
      snapshot: snapshot,
      plan: _plan(),
      program: _program(),
      guests: const [],
      opsGuests: const [],
    );

    expect(workspace.summary.eventName, 'Wedding 2026');
    expect(workspace.summary.ticketsSold, 120);
    expect(workspace.financial.ticketRevenueMinor, 6000000);
    expect(workspace.historicalScore, greaterThanOrEqualTo(0));
    expect(workspace.debrief.wentWell, isNotEmpty);
    expect(workspace.lifecycleStage, EventLifecycleStage.closing);
  });

  test('duplicate draft carries event structure forward', () {
    final event = _completedEvent();
    final workspace = buildEventClosingWorkspace(
      event: event,
      snapshot: _snapshot(event),
      plan: _plan(),
      program: _program(),
      guests: const [],
      opsGuests: const [],
    );

    final draft = buildDuplicateEventDraft(event: event, workspace: workspace);
    expect(draft.title, contains('Copy'));
    expect(draft.city, 'Lagos');
    expect(draft.expectedGuests, 150);
    expect(draft.budgetMinor, greaterThan(0));
  });

  test('export reports produce clipboard-ready text', () {
    final event = _completedEvent();
    final workspace = buildEventClosingWorkspace(
      event: event,
      snapshot: _snapshot(event),
      plan: _plan(),
      program: _program(),
      guests: const [],
      opsGuests: const [],
    );

    final finance = buildClosingReport(kind: ClosingReportKind.finance, workspace: workspace);
    expect(finance, contains('FINANCE REPORT'));
    expect(finance, contains('Wedding 2026'));

    final guest = buildClosingReport(kind: ClosingReportKind.guest, workspace: workspace);
    expect(guest, contains('GUEST REPORT'));
  });

  test('archived phase marks workspace read-only', () {
    final event = _completedEvent();
    final workspace = buildEventClosingWorkspace(
      event: event,
      snapshot: _snapshot(event),
      plan: _plan(),
      program: _program(),
      guests: const [],
      opsGuests: const [],
      phase: EventClosingPhase.archived,
    );

    expect(workspace.isReadOnly, isTrue);
    expect(workspace.lifecycleStage, EventLifecycleStage.archived);
  });
}
