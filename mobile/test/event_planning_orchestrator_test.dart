import 'package:flutter_test/flutter_test.dart';
import 'package:owambe/features/operations/models/operations_models.dart';
import 'package:owambe/portals/customer/models/ai_planner_models.dart';
import 'package:owambe/portals/customer/models/command_center_models.dart';
import 'package:owambe/portals/customer/models/customer_event_models.dart';
import 'package:owambe/portals/customer/models/customer_guest_models.dart';
import 'package:owambe/portals/customer/models/vendor_crm_models.dart';
import 'package:owambe/portals/customer/planning/event_planning_models.dart';
import 'package:owambe/shared/models/event_access_mode.dart';

CustomerEvent _event({EventAccessMode mode = EventAccessMode.privateInvitation}) => CustomerEvent(
      id: 'evt_p3',
      title: 'Phase 3 Test',
      tagline: '',
      description: 'Details set',
      city: 'Lagos',
      venue: 'Landmark',
      startsAt: DateTime.now().add(const Duration(days: 45)),
      endsAt: DateTime.now().add(const Duration(days: 45, hours: 6)),
      category: 'Wedding',
      status: CustomerEventStatus.draft,
      coverGradientStart: 0xFF4B2C6F,
      coverGradientEnd: 0xFFD4A853,
      ticketTiers: const [],
      vendors: const [],
      attendees: const [],
      eventAccessMode: mode,
      expectedGuests: 120,
    );

EventCommandCenterSnapshot _snapshot(CustomerEvent event) => buildCommandCenterSnapshot(
      event: event,
      opsGuests: const [],
      feed: const [],
    );

AiPlannerPlan _plan(CustomerEvent event) => buildAiPlannerPlan(
      inputs: defaultInputsFromEvent(event),
      event: event,
      vendors: const [],
    );

void main() {
  test('lifecycle advances from draft to planning when event has details', () {
    final event = _event();
    final stage = deriveEventLifecycleStage(
      event: event,
      snapshot: _snapshot(event),
      crm: null,
      guests: const [],
    );
    expect(stage, EventLifecycleStage.planning);
  });

  test('lifecycle reaches vendorsSecured when vendors accepted', () {
    final event = _event().copyWith(
      vendors: [
        const CustomerVendorSlot(
          id: 'v1',
          businessName: 'Catering Co',
          category: 'Catering',
          tier: 'standard',
          status: CustomerVendorSlotStatus.approved,
        ),
      ],
    );
    final snap = _snapshot(event);
    final stage = deriveEventLifecycleStage(
      event: event,
      snapshot: snap,
      crm: null,
      guests: const [],
    );
    expect(stage, EventLifecycleStage.vendorsSecured);
  });

  test('checklist derives from AI planner without duplicate storage', () {
    final event = _event();
    final plan = _plan(event);
    final checklist = buildEventChecklist(plan);
    expect(checklist, isNotEmpty);
    expect(checklist.any((c) => c.label.toLowerCase().contains('venue')), isTrue);
    expect(checklist.where((c) => !c.done).isNotEmpty, isTrue);
  });

  test('vendor status maps from CRM snapshot', () {
    const crm = VendorCrmSnapshot(
      items: [],
      stats: VendorPipelineStats(
        newCount: 2,
        negotiating: 1,
        accepted: 3,
        scheduled: 1,
        arrived: 1,
        completed: 2,
        total: 10,
      ),
    );
    final status = buildVendorStatusSummary(crm, _event());
    expect(status.waitingForQuotes, 2);
    expect(status.quoteReceived, 1);
    expect(status.accepted, 3);
    expect(status.completed, 2);
  });

  test('guest status derives from guest views', () {
    const guests = [
      CustomerGuestView(
        id: 'g1',
        name: 'Ada',
        email: 'a@x.com',
        ticketId: 't1',
        tierName: 'GA',
        tier: GuestTier.general,
        checkedIn: true,
        rsvpStatus: GuestRsvpStatus.confirmed,
      ),
      CustomerGuestView(
        id: 'g2',
        name: 'Bob',
        email: 'b@x.com',
        ticketId: '',
        tierName: 'GA',
        tier: GuestTier.general,
        checkedIn: false,
        rsvpStatus: GuestRsvpStatus.pending,
      ),
    ];
    final status = buildGuestStatusSummary(guests);
    expect(status.invited, 2);
    expect(status.accepted, 1);
    expect(status.pending, 1);
    expect(status.checkedIn, 1);
  });

  test('readiness score increases as checklist items complete', () {
    final empty = _event();
    final planEmpty = _plan(empty);
    final dimsEmpty = computeReadinessDimensions(
      event: empty,
      snapshot: _snapshot(empty),
      plan: planEmpty,
      vendorStatus: buildVendorStatusSummary(null, empty),
      guestStatus: buildGuestStatusSummary(const []),
      ticketStatus: buildTicketStatusSummary(empty),
      financeStatus: buildFinanceStatusSummary(snapshot: _snapshot(empty)),
    );
    final scoreEmpty = computeEventReadinessScore(dimsEmpty);

    final progressed = empty.copyWith(
      attendees: [
        const CustomerAttendee(
          id: 'a1',
          name: 'Guest',
          email: 'g@x.com',
          ticketId: 't1',
          tierName: 'GA',
        ),
      ],
      vendors: [
        const CustomerVendorSlot(
          id: 'v1',
          businessName: 'DJ',
          category: 'DJ',
          tier: 'standard',
          status: CustomerVendorSlotStatus.approved,
          ordersCount: 1,
        ),
      ],
      ticketTiers: [
        const CustomerTicketTier(
          id: 'tier1',
          name: 'GA',
          description: '',
          priceMinor: 500000,
          currency: 'NGN',
          capacity: 100,
          remaining: 90,
        ),
      ],
      status: CustomerEventStatus.published,
    );
    final planDone = _plan(progressed);
    final dimsDone = computeReadinessDimensions(
      event: progressed,
      snapshot: _snapshot(progressed),
      plan: planDone,
      vendorStatus: buildVendorStatusSummary(null, progressed),
      guestStatus: buildGuestStatusSummary(const []),
      ticketStatus: buildTicketStatusSummary(progressed),
      financeStatus: buildFinanceStatusSummary(snapshot: _snapshot(progressed)),
    );
    final scoreDone = computeEventReadinessScore(dimsDone);

    expect(scoreDone, greaterThan(scoreEmpty));
  });

  test('AI recommendation links map to planning modules', () {
    expect(moduleLinkForAiAction('guests'), PlanningModuleLink.guests);
    expect(moduleLinkForAiAction('vendors'), PlanningModuleLink.marketplace);
    expect(moduleLinkForAiAction('budget'), PlanningModuleLink.budget);
  });

  test('planning workspace builder wires next action from incomplete checklist', () {
    final event = _event();
    final workspace = buildEventPlanningWorkspace(
      snapshot: _snapshot(event),
      plan: _plan(event),
      crm: null,
      guests: const [],
    );
    expect(workspace.nextActionLabel, isNotNull);
    expect(workspace.readinessScore, greaterThanOrEqualTo(0));
    expect(workspace.readinessScore, lessThanOrEqualTo(100));
  });
}
