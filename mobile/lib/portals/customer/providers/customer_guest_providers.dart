import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/event_guests_api.dart';
import '../../../core/api/persistence_providers.dart';
import '../../../features/operations/data/operations_store.dart';
import '../../../features/operations/models/operations_models.dart';
import '../../../features/operations/providers/operations_providers.dart';
import '../../../features/organizer/providers/organizer_providers.dart';
import '../data/customer_guest_persistence.dart';
import '../models/customer_guest_models.dart';

final customerGuestRefreshProvider = StateProvider<int>((ref) => 0);

void refreshCustomerGuests(WidgetRef ref) {
  ref.read(customerGuestRefreshProvider.notifier).state++;
}

final customerGuestSearchProvider = StateProvider.autoDispose<String>((ref) => '');

final customerGuestFilterProvider =
    StateProvider.autoDispose<CustomerGuestFilter>((ref) => CustomerGuestFilter.all);

final customerSelectedGuestProvider = StateProvider.autoDispose<CustomerGuestView?>((ref) => null);

GuestRsvpStatus _rsvpFromApi(String raw) => switch (raw) {
      'confirmed' => GuestRsvpStatus.confirmed,
      'declined' => GuestRsvpStatus.declined,
      _ => GuestRsvpStatus.pending,
    };

CustomerGuestView _guestViewFromApi(dynamic record) {
  return CustomerGuestView(
    id: record.id as String,
    name: record.name as String,
    email: (record.email as String?) ?? '',
    ticketId: (record.guestRef as String?) ?? '',
    tierName: 'General Admission',
    tier: GuestTier.general,
    checkedIn: false,
    rsvpStatus: _rsvpFromApi(record.rsvpStatus as String),
  );
}

final customerEventGuestsProvider =
    FutureProvider.autoDispose.family<List<CustomerGuestView>, String>((ref, eventId) async {
  ref.watch(customerGuestRefreshProvider);
  ref.watch(operationsRevisionProvider);
  ref.watch(organizerRevisionProvider);

  final event = await ref.watch(organizerEventProvider(eventId).future);

  try {
    final apiGuests = await ref.read(eventGuestsApiProvider).listGuests(eventId);
    if (apiGuests.isNotEmpty) {
      return apiGuests.map(_guestViewFromApi).toList();
    }
  } catch (_) {
    if (!allowMockPersistenceFallback()) rethrow;
  }

  var opsGuests = <OpsGuest>[];
  try {
    opsGuests = await ref.read(operationsApiProvider).listGuests(eventId);
  } catch (_) {
    if (allowMockPersistenceFallback()) {
      OperationsStore.instance.ensureLive(eventId);
      opsGuests = OperationsStore.instance.guests(eventId);
    } else {
      rethrow;
    }
  }

  return mergeGuestViews(
    opsGuests: opsGuests,
    attendees: event?.attendees ?? const [],
  );
});

final customerFilteredGuestsProvider =
    Provider.autoDispose.family<AsyncValue<List<CustomerGuestView>>, String>((ref, eventId) {
  final guests = ref.watch(customerEventGuestsProvider(eventId));
  final query = ref.watch(customerGuestSearchProvider);
  final filter = ref.watch(customerGuestFilterProvider);

  return guests.whenData((list) {
    final searched = searchCustomerGuests(list, query);
    return filterCustomerGuests(searched, filter);
  });
});
