import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/auth_notifier.dart';
import '../../../core/api/persistence_providers.dart';
import '../../../core/api/vendors_api.dart';
import '../../../features/organizer/data/organizer_event_store.dart';
import '../../../features/organizer/models/organizer_models.dart';
import '../../../features/organizer/providers/organizer_providers.dart';
import '../../../features/public/providers/public_providers.dart';
import '../../../features/public/providers/ticket_commerce_providers.dart';
import '../models/home_hub_models.dart';

final customerHomeRefreshProvider = StateProvider<int>((ref) => 0);

void refreshCustomerHome(WidgetRef ref) {
  ref.read(customerHomeRefreshProvider.notifier).state++;
}

final customerOwnedEventsProvider = FutureProvider.autoDispose<List<OrganizerEvent>>((ref) async {
  ref.watch(customerHomeRefreshProvider);
  ref.watch(organizerRevisionProvider);
  try {
    return await ref.read(eventsApiProvider).listOrganizerEvents();
  } catch (_) {
    if (!allowMockPersistenceFallback()) rethrow;
    return OrganizerEventStore.instance.all;
  }
});

final customerTicketInvitationsProvider = FutureProvider.autoDispose<List<CustomerInvitationCard>>((ref) async {
  ref.watch(customerHomeRefreshProvider);
  final session = ref.watch(authSessionProvider);
  if (session == null) return const [];

  try {
    final api = ref.read(ticketCommerceApiProvider);
    final entitlements = await api.fetchMyEntitlements(session);
    return entitlements
        .where((e) => e.startsAt.isAfter(DateTime.now().subtract(const Duration(hours: 6))))
        .map(
          (e) => CustomerInvitationCard(
            id: e.id,
            eventTitle: e.eventTitle,
            eventId: e.eventId,
            startsAt: e.startsAt,
            venue: e.eventVenue,
            city: e.eventCity,
            kind: CustomerInvitationKind.ticket,
          ),
        )
        .toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  } catch (_) {
    final local = ref.watch(attendeeTicketsProvider);
    return local
        .map(
          (t) => CustomerInvitationCard(
            id: t.id,
            eventTitle: t.eventTitle,
            eventId: t.eventId,
            startsAt: t.startsAt,
            venue: t.venue,
            city: t.city,
            kind: CustomerInvitationKind.ticket,
          ),
        )
        .toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  }
});

List<MarketplaceVendor> _mockVendors() => const [
      MarketplaceVendor(id: 'v1', businessName: 'Golden Pot Catering', city: 'Lagos', ratingAverage: 4.9, slug: 'catering'),
      MarketplaceVendor(id: 'v2', businessName: 'DJ Kola Live', city: 'Lagos', ratingAverage: 4.8, slug: 'dj-music'),
      MarketplaceVendor(id: 'v3', businessName: 'Lumière Photography', city: 'Abuja', ratingAverage: 4.7, slug: 'photography'),
      MarketplaceVendor(id: 'v4', businessName: 'Royal Décor Studio', city: 'Lagos', ratingAverage: 4.6, slug: 'decor'),
    ];

final customerMarketplaceVendorsProvider = FutureProvider.autoDispose<List<MarketplaceVendor>>((ref) async {
  ref.watch(customerHomeRefreshProvider);
  try {
    final vendors = await ref.read(vendorsApiProvider).listCatalog();
    if (vendors.isNotEmpty) return vendors;
  } catch (_) {
    if (!allowMockPersistenceFallback()) rethrow;
  }
  if (allowMockPersistenceFallback()) return _mockVendors();
  return const [];
});

CustomerEventSummary? _pickNearestEvent(List<CustomerEventSummary> events, DateTime now) {
  if (events.isEmpty) return null;
  final live = events.where((e) => e.isLive).toList();
  if (live.isNotEmpty) return live.first;
  final upcoming = events.where((e) => e.startsAt.isAfter(now.subtract(const Duration(hours: 12)))).toList()
    ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  if (upcoming.isNotEmpty) return upcoming.first;
  final sorted = [...events]..sort((a, b) => b.startsAt.compareTo(a.startsAt));
  return sorted.first;
}

final customerHomeSnapshotProvider = FutureProvider.autoDispose<CustomerHomeSnapshot>((ref) async {
  ref.watch(customerHomeRefreshProvider);

  final eventsResult = await ref.watch(customerOwnedEventsProvider.future);
  final invitations = await ref.watch(customerTicketInvitationsProvider.future);
  final vendors = await ref.watch(customerMarketplaceVendorsProvider.future);

  final now = DateTime.now();
  final active = eventsResult
      .where(
        (e) =>
            e.status != OrganizerEventStatus.completed &&
            e.status != OrganizerEventStatus.cancelled,
      )
      .map(CustomerEventSummary.fromOrganizerEvent)
      .toList()
    ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

  return CustomerHomeSnapshot(
    activeEvents: active,
    nearestEvent: _pickNearestEvent(active, now),
    invitations: invitations,
    vendors: vendors,
  );
});
