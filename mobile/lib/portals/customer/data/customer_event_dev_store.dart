import '../../../core/api/vendors_api.dart';
import '../../../shared/models/event_access_mode.dart';
import '../models/customer_event_models.dart';

/// Dev-only in-memory event store for Event OS (ALLOW_MOCK_PERSISTENCE_FALLBACK).
class CustomerEventDevStore {
  CustomerEventDevStore._();
  static final CustomerEventDevStore instance = CustomerEventDevStore._();

  final List<CustomerEvent> _events = _seed();

  List<CustomerEvent> get all => List.unmodifiable(_events);

  CustomerEvent? byId(String id) {
    try {
      return _events.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  CustomerEvent publish(String id) => _update(
        id,
        (e) => e.copyWith(status: CustomerEventStatus.published, publishedAt: DateTime.now()),
      );

  CustomerEvent setLive(String id) =>
      _update(id, (e) => e.copyWith(status: CustomerEventStatus.live));

  CustomerEvent _update(String id, CustomerEvent Function(CustomerEvent e) transform) {
    final idx = _events.indexWhere((e) => e.id == id);
    if (idx < 0) throw StateError('event not found');
    _events[idx] = transform(_events[idx]);
    return _events[idx];
  }

  CustomerVendorSlot inviteVendor(String eventId, {required MarketplaceVendor vendor}) {
    final idx = _events.indexWhere((e) => e.id == eventId);
    if (idx < 0) throw StateError('event not found');
    final event = _events[idx];
    final slot = CustomerVendorSlot(
      id: 'v_${vendor.id}',
      catalogVendorId: vendor.id,
      businessName: vendor.businessName,
      category: vendor.slug ?? 'vendor',
      tier: 'standard',
      status: CustomerVendorSlotStatus.invited,
      city: vendor.city,
    );
    _events[idx] = event.copyWith(vendors: [...event.vendors, slot]);
    return slot;
  }

  static List<CustomerEvent> _seed() => [
        CustomerEvent(
          id: 'evt_demo_owanbe',
          title: 'Adaeze & Emeka — Traditional Wedding',
          tagline: 'Two families, one celebration',
          description: 'Join us for a beautiful traditional wedding celebration.',
          city: 'Lagos',
          venue: 'Eko Hotel & Suites',
          startsAt: DateTime.now().add(const Duration(days: 45)),
          endsAt: DateTime.now().add(const Duration(days: 45, hours: 8)),
          category: 'Wedding',
          status: CustomerEventStatus.published,
          coverGradientStart: 0xFF4B2C6F,
          coverGradientEnd: 0xFFD4A853,
          ticketTiers: const [],
          vendors: const [],
          attendees: const [],
          eventAccessMode: EventAccessMode.privateInvitation,
          budgetMinor: 500000000,
          expectedGuests: 250,
          categorySlug: 'wedding',
        ),
      ];
}
