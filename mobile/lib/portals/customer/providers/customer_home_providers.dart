import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/auth_notifier.dart';
import '../../../core/api/persistence_providers.dart';
import '../../../core/api/vendors_api.dart';
import '../../../core/providers/silent_refresh.dart';
import '../../../features/vendor/vendor_identity.dart';
import '../../../features/public/providers/public_providers.dart';
import '../../../features/public/providers/ticket_commerce_providers.dart';
import '../models/customer_event_models.dart';
import '../models/home_hub_models.dart';
import '../providers/customer_event_providers.dart';

final customerHomeRefreshProvider = StateProvider<int>((ref) => 0);

void refreshCustomerHome(WidgetRef ref) {
  ref.read(customerHomeRefreshProvider.notifier).state++;
}

final customerOwnedEventsProvider = FutureProvider.autoDispose<List<CustomerEvent>>((ref) async {
  ref.watch(customerHomeRefreshProvider);
  return ref.watch(customerEventsProvider.future);
});

final customerTicketInvitationsProvider = FutureProvider.autoDispose<List<CustomerInvitationCard>>((ref) async {
  ref.watch(customerHomeRefreshProvider);
  final session = ref.watchSignedInUser();
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

List<MarketplaceVendor> _seedBackedDemoVendors() => const [
      // Sole demo listing: seeded vendors row owned by vendor@owanbe.dev
      // (infra/db/029_identity_dev_seed.sql). Never emit orphan ids (v1…v11).
      MarketplaceVendor(
        id: VendorIdentity.seedDemoVendorId,
        businessName: 'Jollof & Co',
        city: 'Lagos',
        ratingAverage: 4.9,
        slug: 'catering',
        priceFromMinor: 95000000,
      ),
    ];

final customerMarketplaceVendorsProvider = FutureProvider.autoDispose<List<MarketplaceVendor>>((ref) async {
  ref.watch(customerHomeRefreshProvider);
  try {
    final vendors = await ref.read(vendorsApiProvider).listCatalog();
    if (vendors.isNotEmpty) return vendors;
  } catch (_) {
    if (!allowMockPersistenceFallback()) rethrow;
  }
  if (allowMockPersistenceFallback()) return _seedBackedDemoVendors();
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
            e.status != CustomerEventStatus.completed &&
            e.status != CustomerEventStatus.cancelled,
      )
      .map(CustomerEventSummary.fromEvent)
      .toList()
    ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

  return CustomerHomeSnapshot(
    activeEvents: active,
    nearestEvent: _pickNearestEvent(active, now),
    invitations: invitations,
    vendors: vendors,
  );
});

final organizerHomeSnapshotProvider = FutureProvider.autoDispose<OrganizerHomeSnapshot>((ref) async {
  ref.watch(customerHomeRefreshProvider);

  final eventsResult = await ref.watch(customerOwnedEventsProvider.future);
  final vendors = await ref.watch(customerMarketplaceVendorsProvider.future);

  final now = DateTime.now();
  final active = eventsResult
      .where(
        (e) =>
            e.status != CustomerEventStatus.completed &&
            e.status != CustomerEventStatus.cancelled,
      )
      .map(CustomerEventSummary.fromEvent)
      .toList()
    ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

  return OrganizerHomeSnapshot(
    activeEvents: active,
    nearestEvent: _pickNearestEvent(active, now),
    vendors: vendors,
  );
});

final attendeeHomeSnapshotProvider = FutureProvider.autoDispose<AttendeeHomeSnapshot>((ref) async {
  ref.watch(customerHomeRefreshProvider);
  final invitations = await ref.watch(customerTicketInvitationsProvider.future);
  return AttendeeHomeSnapshot(invitations: invitations);
});
