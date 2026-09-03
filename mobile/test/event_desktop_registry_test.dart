import 'package:flutter_test/flutter_test.dart';
import 'package:owambe/portals/customer/models/command_center_models.dart';
import 'package:owambe/portals/customer/models/customer_event_models.dart';
import 'package:owambe/portals/customer/router/event_route_registry.dart';
import 'package:owambe/portals/customer/workspace/event_module_registry.dart';
import 'package:owambe/router/portal_routes.dart';
import 'package:owambe/shared/models/event_access_mode.dart';

CustomerEvent _privateEvent() => CustomerEvent(
      id: 'evt_test',
      title: 'Don Muuyh',
      tagline: '',
      description: '',
      city: 'Lagos',
      venue: 'Landmark',
      startsAt: DateTime.now().add(const Duration(days: 60)),
      endsAt: DateTime.now().add(const Duration(days: 60, hours: 6)),
      category: 'Wedding',
      status: CustomerEventStatus.draft,
      coverGradientStart: 0xFF4B2C6F,
      coverGradientEnd: 0xFFD4A853,
      ticketTiers: const [],
      vendors: const [],
      attendees: const [],
      eventAccessMode: EventAccessMode.privateInvitation,
    );

CustomerEvent _publicEvent() => CustomerEvent(
      id: 'evt_public',
      title: 'Public Gala',
      tagline: '',
      description: '',
      city: 'Lagos',
      venue: 'Hall',
      startsAt: DateTime.now().add(const Duration(days: 30)),
      endsAt: DateTime.now().add(const Duration(days: 30, hours: 4)),
      category: 'Festival',
      status: CustomerEventStatus.draft,
      coverGradientStart: 0xFF4B2C6F,
      coverGradientEnd: 0xFFD4A853,
      ticketTiers: const [],
      vendors: const [],
      attendees: const [],
      eventAccessMode: EventAccessMode.publicTicketed,
    );

EventCommandCenterSnapshot _snapshot(CustomerEvent event) => EventCommandCenterSnapshot(
      event: event,
      progress: 0.12,
      tasksCompleted: 1,
      tasksRemaining: 7,
      tasks: buildPlanningTasks(event),
      guestInvited: 0,
      guestRsvp: 0,
      guestCheckedIn: 0,
      vendorRequested: 0,
      vendorAccepted: 0,
      vendorCompleted: 0,
      budgetMinor: 0,
      committedMinor: 0,
      remainingMinor: 0,
      feed: const [],
    );

void main() {
  test('desktopSections exposes planning and commerce modules for private events', () {
    final event = _privateEvent();
    final sections = EventModuleRegistry.desktopSections(event, _snapshot(event));
    final titles = sections.map((s) => s.title).toList();

    expect(titles, contains('Planning'));
    expect(titles, contains('Commerce'));
    expect(titles, isNot(contains('Administration')));

    final planning = sections.firstWhere((s) => s.title == 'Planning');
    expect(planning.modules.map((m) => m.id), contains(EventModuleId.vendors));
    expect(planning.modules.map((m) => m.id), contains(EventModuleId.guests));

    final commerce = sections.firstWhere((s) => s.title == 'Commerce');
    expect(commerce.modules.map((m) => m.id), contains(EventModuleId.budget));
    expect(commerce.modules.map((m) => m.id), isNot(contains(EventModuleId.tickets)));
  });

  test('desktopSections includes tickets for public ticketed events', () {
    final event = _publicEvent();
    final desktopIds = EventModuleRegistry.desktopSections(event, _snapshot(event))
        .expand((s) => s.modules)
        .map((m) => m.id)
        .toSet();

    expect(desktopIds.contains(EventModuleId.tickets), isTrue);
  });

  group('Phase 2 route wiring', () {
    const eventId = 'evt_phase2';

    test('marketplace launcher carries eventId query param', () {
      expect(
        EventRouteRegistry.vendorsForEvent(eventId),
        '/vendors?eventId=evt_phase2',
      );
      expect(
        EventRouteRegistry.vendorDetailForEvent('ven_1', eventId: eventId),
        '/vendors/ven_1?eventId=evt_phase2',
      );
      expect(
        EventRouteRegistry.vendorDetailForEvent(
          'ven_1',
          eventId: eventId,
          service: 'Catering',
        ),
        '/vendors/ven_1?eventId=evt_phase2&service=Catering',
      );
      expect(
        EventRouteRegistry.marketplaceEventIdFromLocation(
          EventRouteRegistry.vendorsForEvent(eventId),
        ),
        eventId,
      );
    });

    test('organizer tickets manage is separate from attendee purchase', () {
      expect(EventRouteRegistry.eventTickets(eventId), '/events/evt_phase2/tickets');
      expect(EventRouteRegistry.eventTicketsManage(eventId), '/events/evt_phase2/tickets/manage');
    });

    test('tickets/manage is not a public path', () {
      expect(PortalRoutes.isPublicPath('/events/evt_phase2/tickets'), isTrue);
      expect(PortalRoutes.isPublicPath('/events/evt_phase2/tickets/manage'), isFalse);
    });

    test('token RSVP deep link is public without auth', () {
      expect(PortalRoutes.isPublicPath('/events/evt_phase2/rsvp'), isTrue);
    });

    test('event module paths include tickets/manage', () {
      expect(
        EventRouteRegistry.isEventModulePath('/events/evt_phase2/tickets/manage'),
        isTrue,
      );
    });
  });
}
