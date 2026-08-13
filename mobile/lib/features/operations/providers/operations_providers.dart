import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/events_api.dart';
import '../../../core/api/persistence_providers.dart';
import '../../organizer/models/organizer_models.dart';
import '../../organizer/providers/organizer_providers.dart';
import '../data/operations_store.dart';
import '../models/operations_models.dart';

final operationsStoreProvider = Provider<OperationsStore>((ref) => OperationsStore.instance);

final operationsRevisionProvider = StateProvider<int>((ref) => 0);

void bumpOperationsRevision(WidgetRef ref) {
  ref.read(operationsRevisionProvider.notifier).state++;
}

final operationsShellTabProvider = NotifierProvider<OperationsShellTabController, int>(
  OperationsShellTabController.new,
);

class OperationsShellTabController extends Notifier<int> {
  @override
  int build() => 0;
  void select(int tab) => state = tab;
}

final liveOpsEventIdProvider = StateProvider<String?>((ref) => null);

final liveOrganizerEventsProvider = FutureProvider.autoDispose<List<OrganizerEvent>>((ref) async {
  ref.watch(organizerRevisionProvider);
  try {
    final events = await ref.read(organizerEventsProvider.future);
    return events
        .where((e) => e.status == OrganizerEventStatus.live || e.status == OrganizerEventStatus.published)
        .toList();
  } catch (e) {
    if (!allowMockPersistenceFallback()) rethrow;
    return ref
        .read(organizerStoreProvider)
        .all
        .where((e) => e.status == OrganizerEventStatus.live || e.status == OrganizerEventStatus.published)
        .toList();
  }
});

final operationsGuestsProvider = FutureProvider.autoDispose.family<List<OpsGuest>, String>((ref, eventId) async {
  ref.watch(operationsRevisionProvider);
  try {
    final guests = await ref.read(operationsApiProvider).listGuests(eventId);
    final event = await _safeEvent(ref, eventId);
    final completed = event?.status == OrganizerEventStatus.completed;
    return guests
        .map((g) {
          if (!g.checkedIn) return g;
          return g.copyWith(
            doorStatus: completed ? DoorAttendeeStatus.completed : DoorAttendeeStatus.inside,
          );
        })
        .toList();
  } catch (e) {
    if (!allowMockPersistenceFallback()) rethrow;
    OperationsStore.instance.ensureLive(eventId);
    return OperationsStore.instance.guests(eventId);
  }
});

Future<OrganizerEvent?> _safeEvent(Ref ref, String eventId) async {
  try {
    final events = await ref.read(organizerEventsProvider.future);
    for (final e in events) {
      if (e.id == eventId) return e;
    }
  } catch (_) {}
  return null;
}

final operationsFeedProvider = FutureProvider.autoDispose.family<List<OpsFeedEvent>, String>((ref, eventId) async {
  ref.watch(operationsRevisionProvider);
  try {
    return await ref.read(operationsApiProvider).listFeed(eventId);
  } catch (e) {
    if (!allowMockPersistenceFallback()) rethrow;
    OperationsStore.instance.ensureLive(eventId);
    return OperationsStore.instance.feed(eventId);
  }
});

/// Keeps Live Ops feed fresh via existing SSE `feed/stream` (HTTP seed + soft poll fallback).
final operationsLiveFeedProvider =
    StreamProvider.autoDispose.family<List<OpsFeedEvent>, String>((ref, eventId) {
  final api = ref.watch(operationsApiProvider);
  final controller = StreamController<List<OpsFeedEvent>>();
  var items = <OpsFeedEvent>[];
  StreamSubscription<OpsFeedEvent>? sseSub;
  Timer? poll;

  void push() {
    if (!controller.isClosed) controller.add(List<OpsFeedEvent>.unmodifiable(items));
  }

  Future<void> refresh() async {
    try {
      items = await api.listFeed(eventId);
      push();
    } catch (_) {
      if (allowMockPersistenceFallback()) {
        OperationsStore.instance.ensureLive(eventId);
        items = OperationsStore.instance.feed(eventId);
        push();
      }
    }
  }

  void prepend(OpsFeedEvent evt) {
    items = [evt, ...items.where((e) => e.id != evt.id && e.headline != evt.headline)].take(200).toList();
    push();
  }

  refresh();

  try {
    sseSub = api.streamFeed(eventId).listen(
      prepend,
      onError: (_) {},
      cancelOnError: false,
    );
  } catch (_) {}

  poll = Timer.periodic(const Duration(seconds: 12), (_) => refresh());

  final revSub = ref.listen(operationsRevisionProvider, (_, _) {
    refresh();
  });

  ref.onDispose(() {
    sseSub?.cancel();
    poll?.cancel();
    revSub.close();
    controller.close();
  });

  return controller.stream;
});

final operationsIncidentsProvider =
    FutureProvider.autoDispose.family<List<OpsIncident>, String>((ref, eventId) async {
  ref.watch(operationsRevisionProvider);
  try {
    return await ref.read(operationsApiProvider).listIncidents(eventId);
  } catch (e) {
    if (!allowMockPersistenceFallback()) rethrow;
    OperationsStore.instance.ensureLive(eventId);
    return OperationsStore.instance.incidents(eventId);
  }
});

final operationsVendorsProvider =
    FutureProvider.autoDispose.family<List<VendorOpsSnapshot>, String>((ref, eventId) async {
  ref.watch(operationsRevisionProvider);
  ref.watch(organizerRevisionProvider);
  if (!allowMockPersistenceFallback()) return const [];
  OperationsStore.instance.ensureLive(eventId);
  return OperationsStore.instance.vendors(eventId);
});

final operationsKpisProvider = FutureProvider.autoDispose.family<LiveEventKpis, String>((ref, eventId) async {
  ref.watch(operationsRevisionProvider);
  try {
    final openIncidents = (await ref.read(operationsIncidentsProvider(eventId).future))
        .where((i) => i.status == IncidentStatus.open || i.status == IncidentStatus.investigating)
        .length;
    return await ref.read(operationsApiProvider).fetchDoorSummary(eventId, openIncidents: openIncidents);
  } catch (e) {
    if (!allowMockPersistenceFallback()) {
      // Fallback: derive from guest list if door-summary unavailable.
      try {
        final guests = await ref.read(operationsGuestsProvider(eventId).future);
        final checked = guests.where((g) => g.checkedIn).length;
        final total = guests.length;
        final remaining = total - checked;
        final pct = total == 0 ? 0.0 : (checked / total) * 100;
        final openIncidents = (await ref.read(operationsIncidentsProvider(eventId).future))
            .where((i) => i.status != IncidentStatus.resolved)
            .length;
        return LiveEventKpis(
          checkedIn: checked,
          remainingGuests: remaining,
          capacity: total,
          noShows: remaining,
          attendancePct: pct,
          capacityPct: pct,
          vendorsActive: 0,
          ordersToday: 0,
          revenueTodayMinor: 0,
          openIncidents: openIncidents,
          totalRegistered: total,
        );
      } catch (_) {
        rethrow;
      }
    }
    OperationsStore.instance.ensureLive(eventId);
    return OperationsStore.instance.kpis(eventId);
  }
});

final operationsHealthProvider =
    FutureProvider.autoDispose.family<EventHealthSnapshot, String>((ref, eventId) async {
  ref.watch(operationsRevisionProvider);
  try {
    final kpis = await ref.read(operationsKpisProvider(eventId).future);
    final incidents = await ref.read(operationsIncidentsProvider(eventId).future);
    final checkInRate = kpis.totalRegistered == 0 ? 0.0 : kpis.checkedIn / kpis.totalRegistered;
    final capacityRate = kpis.capacity == 0 ? 0.0 : kpis.checkedIn / kpis.capacity;
    final openIncidents = incidents.where((i) => i.status != IncidentStatus.resolved).length;
    final openCritical = incidents
        .where((i) => i.status != IncidentStatus.resolved && i.priority == IncidentPriority.critical)
        .length;
    final queue = kpis.queueState;
    final level = openCritical > 0
        ? EventHealthLevel.critical
        : openIncidents > 0 || queue == 'heavy'
            ? EventHealthLevel.warning
            : EventHealthLevel.healthy;
    return EventHealthSnapshot(
      level: level,
      attendanceRate: checkInRate,
      checkInRate: checkInRate,
      capacityRate: capacityRate,
      vendorActivityRate: 0,
      incidentRate: kpis.totalRegistered == 0 ? 0 : openIncidents / kpis.totalRegistered,
      revenueVelocityMinor: 0,
      queueState: queue,
      checkInThroughputPerHour: kpis.checkInsLast60m,
      summary: openCritical > 0
          ? 'Critical incidents require attention'
          : openIncidents > 0
              ? '$openIncidents open incident(s) · queue $queue'
              : 'Operations nominal · ${kpis.attendancePct.toStringAsFixed(0)}% attendance · queue $queue',
    );
  } catch (e) {
    if (!allowMockPersistenceFallback()) rethrow;
    OperationsStore.instance.ensureLive(eventId);
    return OperationsStore.instance.health(eventId);
  }
});

final checkInFilterProvider = StateProvider<CheckInFilter>((ref) => CheckInFilter.all);

final lastQrScanProvider = StateProvider<QrScanResponse?>((ref) => null);

Future<bool> _isOffline() async {
  try {
    final results = await Connectivity().checkConnectivity();
    return results.isEmpty || results.every((r) => r == ConnectivityResult.none);
  } catch (_) {
    return false;
  }
}

Future<QrScanResponse> performQrCheckIn(WidgetRef ref, String eventId, String ticketCode) async {
  if (await _isOffline()) {
    return const QrScanResponse(
      result: QrScanResult.offline,
      message: 'You appear offline. Connect to check in tickets.',
    );
  }
  final input = ticketCode.trim();
  if (input.isEmpty) {
    return const QrScanResponse(result: QrScanResult.invalid, message: 'Enter or paste a ticket code / QR payload');
  }
  try {
    final api = ref.read(operationsApiProvider);
    final result = await api.checkIn(eventId: eventId, ticketCode: input, source: 'qr');
    bumpOperationsRevision(ref);
    bumpOrganizerRevision(ref);
    final guest = OpsGuest(
      id: result.ticketCode ?? input,
      name: result.holderName ?? 'Guest',
      email: '',
      ticketId: result.ticketCode ?? resolveDoorTicketInput(input),
      tierName: result.tierName ?? 'General',
      tier: _tierFromName(result.tierName ?? ''),
      checkedIn: !result.duplicate,
      doorStatus: DoorAttendeeStatus.inside,
    );
    if (result.duplicate) {
      return QrScanResponse(
        result: QrScanResult.alreadyUsed,
        message: 'Already checked in — ${guest.name}',
        guest: guest.copyWith(checkedIn: true),
      );
    }
    final tier = result.tierName?.toLowerCase() ?? '';
    if (tier.contains('vvip')) {
      return QrScanResponse(result: QrScanResult.vvip, message: 'VVIP — fast lane cleared', guest: guest);
    }
    if (tier.contains('vip')) {
      return QrScanResponse(result: QrScanResult.vip, message: 'VIP — lounge access granted', guest: guest);
    }
    if (result.invitation) {
      return QrScanResponse(result: QrScanResult.valid, message: 'Invitation arrival — check-in successful', guest: guest);
    }
    return QrScanResponse(result: QrScanResult.valid, message: 'Check-in successful', guest: guest);
  } on EventsApiException catch (e) {
    final code = e.code.toUpperCase();
    if (code.contains('TICKET_CANCELLED') || e.message.toLowerCase().contains('voided') || e.message.toLowerCase().contains('refunded')) {
      return QrScanResponse(result: QrScanResult.cancelled, message: e.message);
    }
    if (code.contains('TICKET_NOT_FOUND') || code.contains('TICKET_INVALID') || code.contains('TICKET_REQUIRED')) {
      return QrScanResponse(result: QrScanResult.invalid, message: e.message);
    }
    if (!allowMockPersistenceFallback()) {
      return QrScanResponse(result: QrScanResult.invalid, message: e.message);
    }
    return OperationsStore.instance.scanTicket(eventId, ticketCode);
  } catch (e) {
    if (await _isOffline()) {
      return const QrScanResponse(
        result: QrScanResult.offline,
        message: 'Network error — check connection and retry.',
      );
    }
    if (!allowMockPersistenceFallback()) {
      return QrScanResponse(result: QrScanResult.invalid, message: e.toString());
    }
    return OperationsStore.instance.scanTicket(eventId, ticketCode);
  }
}

GuestTier _tierFromName(String tierName) {
  final lower = tierName.toLowerCase();
  if (lower.contains('vvip')) return GuestTier.vvip;
  if (lower.contains('vip')) return GuestTier.vip;
  return GuestTier.general;
}

Future<void> performManualCheckIn(WidgetRef ref, String eventId, OpsGuest guest) async {
  if (await _isOffline()) {
    throw EventsApiException(code: 'OFFLINE', message: 'You appear offline. Connect to check in.');
  }
  try {
    await ref.read(operationsApiProvider).checkIn(
          eventId: eventId,
          entitlementId: guest.id,
          ticketCode: guest.ticketId,
          source: 'manual',
        );
    bumpOperationsRevision(ref);
    bumpOrganizerRevision(ref);
  } catch (e) {
    if (!allowMockPersistenceFallback()) rethrow;
    OperationsStore.instance.checkInGuest(eventId, guest.id, manual: true);
    bumpOperationsRevision(ref);
    bumpOrganizerRevision(ref);
  }
}

/// Canonical door check-in from organizer attendee lists (entitlement id or ticket code).
Future<void> performOrganizerAttendeeCheckIn(
  WidgetRef ref, {
  required String eventId,
  required String entitlementOrGuestId,
  String? ticketCode,
}) async {
  if (await _isOffline()) {
    throw EventsApiException(code: 'OFFLINE', message: 'You appear offline. Connect to check in.');
  }
  await ref.read(operationsApiProvider).checkIn(
        eventId: eventId,
        entitlementId: entitlementOrGuestId,
        ticketCode: ticketCode,
        source: 'manual',
      );
  bumpOperationsRevision(ref);
  bumpOrganizerRevision(ref);
}

Future<void> performLogIncident(
  WidgetRef ref, {
  required String eventId,
  required String title,
  required IncidentCategory category,
  required IncidentPriority priority,
  required String reporter,
  String description = '',
}) async {
  try {
    await ref.read(operationsApiProvider).createIncident(
          eventId: eventId,
          title: title,
          category: category,
          priority: priority,
          reporter: reporter,
          description: description,
        );
    bumpOperationsRevision(ref);
  } catch (e) {
    if (!allowMockPersistenceFallback()) rethrow;
    OperationsStore.instance.logIncident(
      eventId: eventId,
      title: title,
      category: category,
      priority: priority,
      reporter: reporter,
      description: description,
    );
    bumpOperationsRevision(ref);
  }
}
