import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/auth_notifier.dart';
import '../../../core/api/event_services_api.dart';
import '../../../core/api/persistence_providers.dart';
import '../../../portals/customer/models/rentals_models.dart';

final eventServicesVendorQueryProvider =
    StateProvider.autoDispose.family<({String q, String category}), String>(
  (ref, eventId) => (q: '', category: ''),
);

final eventServicesHubProvider =
    FutureProvider.autoDispose.family<EventServicesHub?, String>((ref, eventId) async {
  final link = ref.keepAlive();
  final timer = Timer(const Duration(minutes: 2), link.close);
  ref.onDispose(timer.cancel);

  final session = ref.watch(authSessionProvider);
  if (session == null) return null;
  return ref.read(eventServicesApiProvider).fetchHub(session: session, eventId: eventId);
});

final eventServiceVendorsProvider =
    FutureProvider.autoDispose.family<List<EventServiceVendor>, String>((ref, eventId) async {
  final session = ref.watch(authSessionProvider);
  if (session == null) return const [];
  final filters = ref.watch(eventServicesVendorQueryProvider(eventId));
  return ref.read(eventServicesApiProvider).listVendors(
        session: session,
        eventId: eventId,
        q: filters.q,
        category: filters.category,
      );
});

final eventServiceRentalsProvider =
    FutureProvider.autoDispose.family<List<RentalCatalogItem>, String>((ref, eventId) async {
  final session = ref.watch(authSessionProvider);
  if (session == null) return const [];
  return ref.read(eventServicesApiProvider).listRentals(session: session, eventId: eventId);
});

final myServiceBookingsProvider =
    FutureProvider.autoDispose.family<List<EventServiceBooking>, String?>((ref, eventId) async {
  final session = ref.watch(authSessionProvider);
  if (session == null) return const [];
  return ref.read(eventServicesApiProvider).listMyBookings(
        session: session,
        eventId: eventId,
      );
});

final serviceNotificationsProvider =
    FutureProvider.autoDispose<List<ServiceNotification>>((ref) async {
  final session = ref.watch(authSessionProvider);
  if (session == null) return const [];
  return ref.read(eventServicesApiProvider).fetchNotifications(session);
});

Future<void> refreshEventServices(WidgetRef ref, String eventId) async {
  ref.invalidate(eventServicesHubProvider(eventId));
  ref.invalidate(eventServiceVendorsProvider(eventId));
  ref.invalidate(eventServiceRentalsProvider(eventId));
  ref.invalidate(myServiceBookingsProvider(eventId));
  ref.invalidate(myServiceBookingsProvider(null));
  ref.invalidate(serviceNotificationsProvider);
}
