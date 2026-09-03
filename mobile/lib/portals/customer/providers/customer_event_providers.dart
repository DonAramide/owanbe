import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/auth_notifier.dart';
import '../../../core/api/persistence_providers.dart';
import '../../../core/providers/silent_refresh.dart';
import '../../../identity/workspace_providers.dart';
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
  final session = ref.watchSignedInUser();
  if (session == null || !ref.watch(isOrganizerWorkspaceProvider)) {
    return const [];
  }
  try {
    return await ref.read(customerEventsApiProvider).listEvents(session: session);
  } catch (_) {
    if (!allowMockPersistenceFallback()) rethrow;
    if (!ref.read(isOrganizerWorkspaceProvider)) rethrow;
    return CustomerEventDevStore.instance.all;
  }
});

final customerEventProvider = FutureProvider.autoDispose.family<CustomerEvent?, String>((ref, id) async {
  ref.watch(customerEventRevisionProvider);
  try {
    final session = ref.watchSignedInUser();
    return await ref.read(customerEventsApiProvider).getEvent(id, session: session);
  } catch (_) {
    if (!allowMockPersistenceFallback()) rethrow;
    final session = ref.read(authSessionProvider);
    if (session == null || !ref.read(isOrganizerWorkspaceProvider)) {
      rethrow;
    }
    return CustomerEventDevStore.instance.byId(id);
  }
});
