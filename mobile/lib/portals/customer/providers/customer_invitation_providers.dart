import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/organizer/providers/organizer_providers.dart';
import '../models/invitation_hub_models.dart';
import 'customer_guest_providers.dart';

final customerInvitationRefreshProvider = StateProvider<int>((ref) => 0);

void refreshInvitationHub(WidgetRef ref) {
  ref.read(customerInvitationRefreshProvider.notifier).state++;
}

final customerEventInvitationProvider =
    FutureProvider.autoDispose.family<InvitationHubSnapshot, String>((ref, eventId) async {
  ref.watch(customerInvitationRefreshProvider);
  ref.watch(customerGuestRefreshProvider);

  final event = await ref.watch(organizerEventProvider(eventId).future);
  if (event == null) {
    throw StateError('Event not found');
  }

  final guests = await ref.watch(customerEventGuestsProvider(eventId).future);
  return buildInvitationHubSnapshot(event: event, guests: guests);
});
