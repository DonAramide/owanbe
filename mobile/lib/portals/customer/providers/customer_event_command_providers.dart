import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/auth_notifier.dart';
import '../../../core/api/persistence_providers.dart';
import '../../../core/providers/silent_refresh.dart';
import '../../../features/operations/data/operations_store.dart';
import '../../../features/operations/models/operations_models.dart';
import '../../../features/operations/providers/operations_providers.dart';
import '../api/customer_events_api.dart';
import '../data/customer_event_dev_store.dart';
import '../models/command_center_models.dart';
import '../models/customer_finance_models.dart';
import '../models/vendor_crm_models.dart';
import '../providers/customer_event_providers.dart';
import '../providers/customer_finance_providers.dart';
import '../providers/vendor_crm_providers.dart';

final customerEventCommandRefreshProvider = StateProvider<int>((ref) => 0);

void refreshEventCommandCenter(WidgetRef ref) {
  ref.read(customerEventCommandRefreshProvider.notifier).state++;
}

/// True when the signed-in user can manage this event.
final customerEventOwnershipProvider = FutureProvider.autoDispose.family<bool, String>((ref, eventId) async {
  final session = ref.watchSignedInUser();
  if (session == null) return false;

  try {
    final event = await ref.read(customerEventsApiProvider).getEvent(eventId, session: session);
    return event != null;
  } catch (_) {
    if (!allowMockPersistenceFallback()) return false;
    return CustomerEventDevStore.instance.byId(eventId) != null;
  }
});

final customerEventCommandProvider =
    FutureProvider.autoDispose.family<EventCommandCenterSnapshot, String>((ref, eventId) async {
  ref.watch(customerEventCommandRefreshProvider);
  ref.watch(customerEventRevisionProvider);
  ref.watch(operationsRevisionProvider);

  final event = await ref.watch(customerEventProvider(eventId).future);
  if (event == null) {
    throw StateError('Event not found');
  }

  var opsGuests = <OpsGuest>[];
  var feed = <OpsFeedEvent>[];
  CustomerEventFinanceSummary? finance;

  try {
    opsGuests = await ref.read(operationsApiProvider).listGuests(eventId);
  } catch (_) {
    if (allowMockPersistenceFallback()) {
      OperationsStore.instance.ensureLive(eventId);
      opsGuests = OperationsStore.instance.guests(eventId);
    }
  }

  try {
    feed = await ref.read(operationsApiProvider).listFeed(eventId);
  } catch (_) {
    if (allowMockPersistenceFallback()) {
      OperationsStore.instance.ensureLive(eventId);
      feed = OperationsStore.instance.feed(eventId);
    }
  }

  try {
    finance = await ref.read(customerEventFinanceSummaryProvider(eventId).future);
  } catch (_) {
    finance = null;
  }

  VendorCrmSnapshot? crm;
  try {
    crm = await ref.read(vendorCrmApiProvider).listForEvent(eventId);
  } catch (_) {
    crm = null;
  }

  return buildCommandCenterSnapshot(
    event: event,
    opsGuests: opsGuests,
    feed: feed,
    finance: finance,
    crm: crm,
  );
});
