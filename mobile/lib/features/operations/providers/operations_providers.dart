import 'package:flutter_riverpod/flutter_riverpod.dart';

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

final liveOrganizerEventsProvider = Provider<List<OrganizerEvent>>((ref) {
  ref.watch(organizerRevisionProvider);
  return ref
      .read(organizerStoreProvider)
      .all
      .where((e) => e.status == OrganizerEventStatus.live || e.status == OrganizerEventStatus.published)
      .toList();
});

final operationsGuestsProvider = FutureProvider.autoDispose.family<List<OpsGuest>, String>((ref, eventId) async {
  ref.watch(operationsRevisionProvider);
  ref.watch(organizerRevisionProvider);
  await Future<void>.delayed(const Duration(milliseconds: 40));
  OperationsStore.instance.ensureLive(eventId);
  return OperationsStore.instance.guests(eventId);
});

final operationsFeedProvider = FutureProvider.autoDispose.family<List<OpsFeedEvent>, String>((ref, eventId) async {
  ref.watch(operationsRevisionProvider);
  await Future<void>.delayed(const Duration(milliseconds: 30));
  OperationsStore.instance.ensureLive(eventId);
  return OperationsStore.instance.feed(eventId);
});

final operationsIncidentsProvider =
    FutureProvider.autoDispose.family<List<OpsIncident>, String>((ref, eventId) async {
  ref.watch(operationsRevisionProvider);
  await Future<void>.delayed(const Duration(milliseconds: 30));
  OperationsStore.instance.ensureLive(eventId);
  return OperationsStore.instance.incidents(eventId);
});

final operationsVendorsProvider =
    FutureProvider.autoDispose.family<List<VendorOpsSnapshot>, String>((ref, eventId) async {
  ref.watch(operationsRevisionProvider);
  ref.watch(organizerRevisionProvider);
  await Future<void>.delayed(const Duration(milliseconds: 30));
  OperationsStore.instance.ensureLive(eventId);
  return OperationsStore.instance.vendors(eventId);
});

final operationsKpisProvider = FutureProvider.autoDispose.family<LiveEventKpis, String>((ref, eventId) async {
  ref.watch(operationsRevisionProvider);
  await Future<void>.delayed(const Duration(milliseconds: 20));
  OperationsStore.instance.ensureLive(eventId);
  return OperationsStore.instance.kpis(eventId);
});

final operationsHealthProvider =
    FutureProvider.autoDispose.family<EventHealthSnapshot, String>((ref, eventId) async {
  ref.watch(operationsRevisionProvider);
  await Future<void>.delayed(const Duration(milliseconds: 30));
  OperationsStore.instance.ensureLive(eventId);
  return OperationsStore.instance.health(eventId);
});

final checkInFilterProvider = StateProvider<CheckInFilter>((ref) => CheckInFilter.all);

final lastQrScanProvider = StateProvider<QrScanResponse?>((ref) => null);
