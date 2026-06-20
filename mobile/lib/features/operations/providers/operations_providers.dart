import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/operations_api.dart';
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
    return await ref.read(operationsApiProvider).listGuests(eventId);
  } catch (e) {
    if (!allowMockPersistenceFallback()) rethrow;
    OperationsStore.instance.ensureLive(eventId);
    return OperationsStore.instance.guests(eventId);
  }
});

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
    final guests = await ref.read(operationsGuestsProvider(eventId).future);
    final checked = guests.where((g) => g.checkedIn).length;
    final total = guests.length;
    final openIncidents = (await ref.read(operationsIncidentsProvider(eventId).future))
        .where((i) => i.status == IncidentStatus.open)
        .length;
    return LiveEventKpis(
      checkedIn: checked,
      remainingGuests: total - checked,
      vendorsActive: 0,
      ordersToday: 0,
      revenueTodayMinor: 0,
      openIncidents: openIncidents,
      totalRegistered: total,
    );
  } catch (e) {
    if (!allowMockPersistenceFallback()) rethrow;
    OperationsStore.instance.ensureLive(eventId);
    return OperationsStore.instance.kpis(eventId);
  }
});

final operationsHealthProvider =
    FutureProvider.autoDispose.family<EventHealthSnapshot, String>((ref, eventId) async {
  ref.watch(operationsRevisionProvider);
  try {
    final guests = await ref.read(operationsGuestsProvider(eventId).future);
    final incidents = await ref.read(operationsIncidentsProvider(eventId).future);
    final checked = guests.where((g) => g.checkedIn).length;
    final total = guests.length;
    final checkInRate = total == 0 ? 0.0 : checked / total;
    final openIncidents = incidents.where((i) => i.status == IncidentStatus.open).length;
    final openCritical = incidents
        .where((i) => i.status == IncidentStatus.open && i.priority == IncidentPriority.critical)
        .length;
    return EventHealthSnapshot(
      level: openCritical > 0
          ? EventHealthLevel.critical
          : openIncidents > 0
              ? EventHealthLevel.warning
              : EventHealthLevel.healthy,
      attendanceRate: checkInRate,
      checkInRate: checkInRate,
      vendorActivityRate: 0,
      incidentRate: total == 0 ? 0 : openIncidents / total,
      revenueVelocityMinor: 0,
      summary: openCritical > 0
          ? 'Critical incidents require attention'
          : openIncidents > 0
              ? '$openIncidents open incident(s)'
              : 'Operations nominal',
    );
  } catch (e) {
    if (!allowMockPersistenceFallback()) rethrow;
    OperationsStore.instance.ensureLive(eventId);
    return OperationsStore.instance.health(eventId);
  }
});

final checkInFilterProvider = StateProvider<CheckInFilter>((ref) => CheckInFilter.all);

final lastQrScanProvider = StateProvider<QrScanResponse?>((ref) => null);

Future<QrScanResponse> performQrCheckIn(WidgetRef ref, String eventId, String ticketCode) async {
  try {
    final api = ref.read(operationsApiProvider);
    final result = await api.checkIn(eventId: eventId, ticketCode: ticketCode, source: 'qr');
    bumpOperationsRevision(ref);
    bumpOrganizerRevision(ref);
    if (result.duplicate) {
      return const QrScanResponse(result: QrScanResult.alreadyUsed, message: 'Already checked in');
    }
    final tier = result.tierName?.toLowerCase() ?? '';
    if (tier.contains('vvip')) {
      return QrScanResponse(result: QrScanResult.vvip, message: 'VVIP — fast lane cleared');
    }
    if (tier.contains('vip')) {
      return QrScanResponse(result: QrScanResult.vip, message: 'VIP — lounge access granted');
    }
    return QrScanResponse(result: QrScanResult.valid, message: 'Check-in successful');
  } catch (e) {
    if (!allowMockPersistenceFallback()) {
      return QrScanResponse(result: QrScanResult.invalid, message: e.toString());
    }
    return OperationsStore.instance.scanTicket(eventId, ticketCode);
  }
}

Future<void> performManualCheckIn(WidgetRef ref, String eventId, OpsGuest guest) async {
  try {
    await ref.read(operationsApiProvider).checkIn(
          eventId: eventId,
          entitlementId: guest.id,
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
