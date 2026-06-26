import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/persistence_providers.dart';
import '../../../features/organizer/providers/organizer_providers.dart';
import '../models/invitation_hub_models.dart';
import 'customer_guest_providers.dart';

final customerInvitationRefreshProvider = StateProvider<int>((ref) => 0);

void refreshInvitationHub(WidgetRef ref) {
  ref.read(customerInvitationRefreshProvider.notifier).state++;
}

final customerInvitationStatsProvider =
    FutureProvider.autoDispose.family<InvitationFunnelStats?, String>((ref, eventId) async {
  if (allowMockPersistenceFallback()) return null;
  try {
    final hub = await ref.read(eventGuestsApiProvider).fetchInvitationHub(eventId);
    return InvitationFunnelStats(
      sent: hub.stats.sent,
      delivered: hub.stats.delivered,
      opened: hub.stats.opened,
      rsvp: hub.stats.rsvp,
    );
  } catch (_) {
    return null;
  }
});

final customerEventInvitationProvider =
    FutureProvider.autoDispose.family<InvitationHubSnapshot, String>((ref, eventId) async {
  ref.watch(customerInvitationRefreshProvider);
  ref.watch(customerGuestRefreshProvider);

  final event = await ref.watch(organizerEventProvider(eventId).future);
  if (event == null) {
    throw StateError('Event not found');
  }

  final guests = await ref.watch(customerEventGuestsProvider(eventId).future);
  final apiStats = await ref.watch(customerInvitationStatsProvider(eventId).future);
  return buildInvitationHubSnapshot(event: event, guests: guests, apiStats: apiStats);
});
