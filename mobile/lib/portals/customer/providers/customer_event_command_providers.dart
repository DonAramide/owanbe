import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/auth_notifier.dart';
import '../../../core/api/persistence_providers.dart';
import '../../../features/operations/data/operations_store.dart';
import '../../../features/operations/models/operations_models.dart';
import '../../../features/operations/providers/operations_providers.dart';
import '../../../features/organizer/data/organizer_event_store.dart';
import '../../../features/organizer/finance/organizer_finance_api.dart';
import '../../../features/organizer/finance/organizer_finance_providers.dart';
import '../../../features/organizer/providers/organizer_providers.dart';
import '../models/command_center_models.dart';

final customerEventCommandRefreshProvider = StateProvider<int>((ref) => 0);

void refreshEventCommandCenter(WidgetRef ref) {
  ref.read(customerEventCommandRefreshProvider.notifier).state++;
}

/// True when the signed-in user can manage this event.
final customerEventOwnershipProvider = FutureProvider.autoDispose.family<bool, String>((ref, eventId) async {
  final session = ref.watch(authSessionProvider);
  if (session == null) return false;

  try {
    final event = await ref.read(eventsApiProvider).getOrganizerEvent(eventId);
    return event != null;
  } catch (_) {
    if (!allowMockPersistenceFallback()) return false;
    return OrganizerEventStore.instance.byId(eventId) != null;
  }
});

final customerEventCommandProvider =
    FutureProvider.autoDispose.family<EventCommandCenterSnapshot, String>((ref, eventId) async {
  ref.watch(customerEventCommandRefreshProvider);
  ref.watch(organizerRevisionProvider);
  ref.watch(operationsRevisionProvider);

  final event = await ref.watch(organizerEventProvider(eventId).future);
  if (event == null) {
    throw StateError('Event not found');
  }

  var opsGuests = <OpsGuest>[];
  var feed = <OpsFeedEvent>[];
  OrganizerEventFinanceSummary? finance;

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
    final session = ref.read(authSessionProvider);
    finance = await ref
        .read(organizerFinanceApiProvider)
        .fetchEventSummary(eventId: eventId, session: session);
  } catch (_) {
    finance = null;
  }

  return buildCommandCenterSnapshot(
    event: event,
    opsGuests: opsGuests,
    feed: feed,
    finance: finance,
  );
});
