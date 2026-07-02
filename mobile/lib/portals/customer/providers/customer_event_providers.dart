import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/auth_notifier.dart';
import '../../../auth/user_role.dart';
import '../../../core/api/persistence_providers.dart';
import '../api/customer_events_api.dart';
import '../data/customer_event_dev_store.dart';
import '../models/customer_event_models.dart';

final customerEventsApiProvider = Provider<CustomerEventsApi>((ref) => CustomerEventsApi());

final customerEventRevisionProvider = StateProvider<int>((ref) => 0);

void bumpCustomerEventRevision(WidgetRef ref) {
  ref.read(customerEventRevisionProvider.notifier).state++;
}

final customerEventsProvider = FutureProvider.autoDispose<List<CustomerEvent>>((ref) async {
  ref.watch(customerEventRevisionProvider);
  final session = ref.watch(authSessionProvider);
  // Attendees (client role) do not own events — skip the organizer endpoint
  // entirely so we never get a 403 that propagates to the UI.
  if (session == null || session.role == UserRole.client) return const [];
  try {
    return await ref.read(customerEventsApiProvider).listEvents(session: session);
  } catch (_) {
    if (!allowMockPersistenceFallback()) rethrow;
    return CustomerEventDevStore.instance.all;
  }
});

final customerEventProvider = FutureProvider.autoDispose.family<CustomerEvent?, String>((ref, id) async {
  ref.watch(customerEventRevisionProvider);
  try {
    final session = ref.watch(authSessionProvider);
    return await ref.read(customerEventsApiProvider).getEvent(id, session: session);
  } catch (_) {
    if (!allowMockPersistenceFallback()) rethrow;
    return CustomerEventDevStore.instance.byId(id);
  }
});
