import 'package:flutter_test/flutter_test.dart';
import 'package:owambe/portals/customer/models/command_center_models.dart';
import 'package:owambe/portals/customer/models/customer_event_models.dart';
import 'package:owambe/portals/customer/models/program_models.dart';
import 'package:owambe/portals/customer/operations/event_operations_models.dart';
import 'package:owambe/portals/customer/planning/event_planning_models.dart';
import 'package:owambe/portals/customer/router/event_route_registry.dart';
import 'package:owambe/shared/models/event_access_mode.dart';

CustomerEvent _event({CustomerEventStatus status = CustomerEventStatus.draft}) => CustomerEvent(
      id: 'evt_ops',
      title: 'Live Gala',
      tagline: '',
      description: 'Ready',
      city: 'Lagos',
      venue: 'Eko Hotel',
      startsAt: DateTime.now(),
      endsAt: DateTime.now().add(const Duration(hours: 6)),
      category: 'Gala',
      status: status,
      coverGradientStart: 0xFF4B2C6F,
      coverGradientEnd: 0xFFD4A853,
      ticketTiers: const [],
      vendors: const [],
      attendees: const [],
      eventAccessMode: EventAccessMode.publicTicketed,
    );

EventCommandCenterSnapshot _snapshot(CustomerEvent event) => buildCommandCenterSnapshot(
      event: event,
      opsGuests: const [],
      feed: const [],
    );

ProgramSnapshot _emptyProgram() => const ProgramSnapshot(
      items: [],
      day: ProgramDaySnapshot(),
      recentActivity: [],
    );

void main() {
  test('execution mode when event is live', () {
    final mode = resolveEventDesktopMode(
      event: _event(status: CustomerEventStatus.live),
      lifecycleStage: EventLifecycleStage.liveEvent,
    );
    expect(mode, EventDesktopMode.execution);
  });

  test('execution mode on event day', () {
    final mode = resolveEventDesktopMode(
      event: _event(status: CustomerEventStatus.published),
      lifecycleStage: EventLifecycleStage.readyForEvent,
    );
    expect(mode, EventDesktopMode.execution);
  });

  test('planning mode before event day', () {
    final event = CustomerEvent(
      id: 'evt_future',
      title: 'Future Gala',
      tagline: '',
      description: '',
      city: 'Lagos',
      venue: 'Hall',
      startsAt: DateTime.now().add(const Duration(days: 14)),
      endsAt: DateTime.now().add(const Duration(days: 14, hours: 6)),
      category: 'Gala',
      status: CustomerEventStatus.draft,
      coverGradientStart: 0xFF4B2C6F,
      coverGradientEnd: 0xFFD4A853,
      ticketTiers: const [],
      vendors: const [],
      attendees: const [],
      eventAccessMode: EventAccessMode.publicTicketed,
    );
    final mode = resolveEventDesktopMode(
      event: event,
      lifecycleStage: EventLifecycleStage.planning,
    );
    expect(mode, EventDesktopMode.planning);
  });

  test('closing mode after event', () {
    final mode = resolveEventDesktopMode(
      event: _event(status: CustomerEventStatus.completed),
      lifecycleStage: EventLifecycleStage.completed,
    );
    expect(mode, EventDesktopMode.closing);
  });

  test('ops routes are event-scoped under day', () {
    expect(EventRouteRegistry.eventDayCheckIn('evt_ops'), '/events/evt_ops/day/check-in');
    expect(EventRouteRegistry.eventDayQrScan('evt_ops'), '/events/evt_ops/day/scan');
    expect(EventRouteRegistry.eventDayIncidents('evt_ops'), '/events/evt_ops/day/incidents');
    expect(EventRouteRegistry.isEventModulePath('/events/evt_ops/day/check-in'), isTrue);
  });

  test('operational health derives from live signals', () {
    final workspace = buildEventOperationsWorkspace(
      event: _event(status: CustomerEventStatus.live),
      lifecycleStage: EventLifecycleStage.liveEvent,
      snapshot: _snapshot(_event(status: CustomerEventStatus.live)),
      guests: const [],
      opsGuests: const [],
      program: _emptyProgram(),
    );
    expect(workspace.mode, EventDesktopMode.execution);
    expect(workspace.operationalHealthScore, greaterThanOrEqualTo(0));
    expect(workspace.healthDimensions, isNotEmpty);
  });
}
