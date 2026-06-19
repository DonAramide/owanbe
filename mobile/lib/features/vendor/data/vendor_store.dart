import '../../organizer/data/organizer_event_store.dart';
import '../models/vendor_models.dart';

/// In-memory vendor merchant store — local until full workflow is complete.
class VendorStore {
  VendorStore._();
  static final VendorStore instance = VendorStore._();

  static const demoVendorId = 'vendor_jollof';

  final VendorProfile profile = const VendorProfile(
    id: demoVendorId,
    businessName: 'Jollof & Co',
    category: 'Catering',
    vendorType: VendorCatalogType.catering,
    tier: 'premium',
    city: 'Lagos',
    tagline: 'Premium West African catering for celebrations',
    rating: 4.8,
    completedEvents: 24,
  );

  final List<VendorEventParticipation> _participations = _seedParticipations();
  final List<VendorCatalogItem> _catalog = _seedCatalog();
  final List<VendorOrder> _orders = _seedOrders();
  final List<VendorWalletEntry> _walletEntries = _seedWallet();
  final List<VendorPayoutRequest> _payouts = _seedPayouts();

  List<VendorEventParticipation> get participations => List.unmodifiable(_participations);
  List<VendorCatalogItem> get catalog => List.unmodifiable(_catalog);
  List<VendorOrder> get orders => List.unmodifiable(_orders);
  List<VendorWalletEntry> get walletEntries => List.unmodifiable(_walletEntries);
  List<VendorPayoutRequest> get payouts => List.unmodifiable(_payouts);

  int get pendingPayoutsMinor => _payouts
      .where((p) => p.status == VendorPayoutStatus.pending || p.status == VendorPayoutStatus.processing)
      .fold(0, (sum, p) => sum + p.amountMinor);

  int get lifetimeRevenueMinor => orders
      .where((o) => o.status != VendorOrderStatus.cancelled)
      .fold(0, (sum, o) => sum + o.amountMinor);

  int get totalBookings => orders.length;

  List<VendorEventParticipation> participationsForLifecycle(ParticipationLifecycle stage) {
    if (stage == ParticipationLifecycle.invited) {
      final invited = _participations.where((p) => p.lifecycleStage == ParticipationLifecycle.invited);
      final discoverable = discoverableEvents();
      final seen = invited.map((p) => p.eventId).toSet();
      return [...invited, ...discoverable.where((d) => !seen.contains(d.eventId))];
    }
    return _participations.where((p) => p.lifecycleStage == stage).toList();
  }

  /// Sync open events from organizer store for vendor applications.
  List<VendorEventParticipation> discoverableEvents() {
    final existing = _participations.map((p) => p.eventId).toSet();
    final published = OrganizerEventStore.instance.publishedForPublic();
    final discovered = <VendorEventParticipation>[];
    for (final e in published) {
      if (existing.contains(e.id)) continue;
      discovered.add(
        VendorEventParticipation(
          id: 'disc_${e.id}',
          eventId: e.id,
          eventTitle: e.title,
          city: e.city,
          venue: e.venue,
          startsAt: e.startsAt,
          status: VendorParticipationStatus.invited,
          boothLabel: 'Vendor village',
          expectedPayoutMinor: 25000000,
        ),
      );
    }
    return discovered;
  }

  VendorEventParticipation applyToEvent(String eventId) {
    final org = OrganizerEventStore.instance.byId(eventId);
    if (org == null) throw StateError('event not found');
    final p = VendorEventParticipation(
      id: 'part_${DateTime.now().millisecondsSinceEpoch}',
      eventId: eventId,
      eventTitle: org.title,
      city: org.city,
      venue: org.venue,
      startsAt: org.startsAt,
      status: VendorParticipationStatus.pending,
      boothLabel: 'Vendor village',
      expectedPayoutMinor: 25000000,
    );
    _participations.insert(0, p);
    return p;
  }

  VendorEventParticipation acceptParticipation(String id) {
    final idx = _participations.indexWhere((p) => p.id == id);
    if (idx < 0) throw StateError('participation not found');
    final current = _participations[idx];
    if (current.status != VendorParticipationStatus.invited) {
      throw StateError('not invited');
    }
    _participations[idx] = VendorEventParticipation(
      id: current.id,
      eventId: current.eventId,
      eventTitle: current.eventTitle,
      city: current.city,
      venue: current.venue,
      startsAt: current.startsAt,
      status: VendorParticipationStatus.confirmed,
      boothLabel: current.boothLabel,
      organizerName: current.organizerName,
      expectedPayoutMinor: current.expectedPayoutMinor,
    );
    return _participations[idx];
  }

  VendorCatalogItem addCatalogItem({
    required String name,
    required String description,
    required String category,
    required int priceMinor,
  }) {
    final item = VendorCatalogItem(
      id: 'cat_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      description: description,
      category: category,
      priceMinor: priceMinor,
      currency: 'NGN',
      status: VendorCatalogStatus.active,
    );
    _catalog.insert(0, item);
    return item;
  }

  VendorCatalogItem toggleCatalogStatus(String id) {
    final idx = _catalog.indexWhere((c) => c.id == id);
    if (idx < 0) throw StateError('item not found');
    final item = _catalog[idx];
    final next = item.status == VendorCatalogStatus.active
        ? VendorCatalogStatus.paused
        : VendorCatalogStatus.active;
    _catalog[idx] = item.copyWith(status: next);
    return _catalog[idx];
  }

  VendorOrder updateOrderStatus(String id, VendorOrderStatus status) {
    final idx = _orders.indexWhere((o) => o.id == id);
    if (idx < 0) throw StateError('order not found');
    final o = _orders[idx];
    _orders[idx] = VendorOrder(
      id: o.id,
      eventId: o.eventId,
      eventTitle: o.eventTitle,
      customerName: o.customerName,
      itemName: o.itemName,
      amountMinor: o.amountMinor,
      status: status,
      placedAt: o.placedAt,
      notes: o.notes,
    );
    return _orders[idx];
  }

  VendorWalletSnapshot walletSnapshot() {
    var available = 0;
    var pending = 0;
    var earned = 0;
    var review = 0;
    for (final e in _walletEntries) {
      if (e.type == VendorWalletEntryType.payout) continue;
      earned += e.amountMinor;
      if (e.status == 'pending') {
        pending += e.amountMinor;
      } else if (e.status == 'under_review') {
        review += e.amountMinor;
      } else {
        available += e.amountMinor;
      }
    }
    for (final p in _payouts) {
      if (p.status == VendorPayoutStatus.pending || p.status == VendorPayoutStatus.processing) {
        available -= p.amountMinor;
      }
    }
    if (available < 0) available = 0;
    return VendorWalletSnapshot(
      availableMinor: available,
      pendingMinor: pending,
      totalEarnedMinor: earned,
      underReviewMinor: review,
    );
  }

  VendorPayoutRequest requestPayout(int amountMinor) {
    final wallet = walletSnapshot();
    if (amountMinor <= 0 || amountMinor > wallet.availableMinor) {
      throw StateError('invalid payout amount');
    }
    final payout = VendorPayoutRequest(
      id: 'pay_${DateTime.now().millisecondsSinceEpoch}',
      amountMinor: amountMinor,
      status: VendorPayoutStatus.pending,
      requestedAt: DateTime.now(),
    );
    _payouts.insert(0, payout);
    _walletEntries.insert(
      0,
      VendorWalletEntry(
        id: 'wlt_${DateTime.now().millisecondsSinceEpoch}',
        type: VendorWalletEntryType.payout,
        amountMinor: -amountMinor,
        label: 'Payout request',
        reference: payout.id,
        timestamp: DateTime.now(),
        status: 'pending',
      ),
    );
    return payout;
  }

  VendorAnalyticsSnapshot analytics() {
    final fulfilled = _orders.where((o) => o.status == VendorOrderStatus.fulfilled).length;
    final rate = _orders.isEmpty ? 0.0 : fulfilled / _orders.length;
    final revenue = _orders
        .where((o) => o.status != VendorOrderStatus.cancelled)
        .fold(0, (sum, o) => sum + o.amountMinor);
    final byEvent = <String, int>{};
    for (final o in _orders) {
      byEvent[o.eventTitle] = (byEvent[o.eventTitle] ?? 0) + 1;
    }
    return VendorAnalyticsSnapshot(
      revenueMinor: revenue,
      ordersCount: _orders.length,
      fulfillmentRate: rate,
      avgOrderMinor: _orders.isEmpty ? 0 : revenue ~/ _orders.length,
      revenueTrend: _syntheticTrend(revenue),
      ordersByEvent: byEvent,
    );
  }

  List<double> _syntheticTrend(int revenue) {
    if (revenue == 0) return [0, 0, 0, 0, 0, 0, 0];
    final step = revenue / 7;
    return List.generate(7, (i) => step * (i + 1));
  }

  static List<VendorEventParticipation> _seedParticipations() {
    return [
      VendorEventParticipation(
        id: 'part_lagos',
        eventId: 'evt_lagos_owanbe_2026',
        eventTitle: 'Lagos Sunset Owanbe',
        city: 'Lagos',
        venue: 'Eko Atlantic Waterfront',
        startsAt: DateTime(2026, 8, 15, 18, 0),
        status: VendorParticipationStatus.confirmed,
        boothLabel: 'Zone B · Premium catering',
        expectedPayoutMinor: 85000000,
      ),
      VendorEventParticipation(
        id: 'part_abuja',
        eventId: 'evt_abuja_wedding_expo',
        eventTitle: 'Abuja Wedding Expo',
        city: 'Abuja',
        venue: 'Transcorp Hilton',
        startsAt: DateTime(2026, 7, 20, 10, 0),
        status: VendorParticipationStatus.invited,
        boothLabel: 'Expo floor · Tasting booth',
        expectedPayoutMinor: 35000000,
      ),
      VendorEventParticipation(
        id: 'part_phf',
        eventId: 'evt_phf_food_fest',
        eventTitle: 'Port Harcourt Food Festival',
        city: 'Port Harcourt',
        venue: 'Liberation Stadium',
        startsAt: DateTime(2026, 9, 5, 12, 0),
        status: VendorParticipationStatus.pending,
        boothLabel: 'Food court · Stall 12',
        expectedPayoutMinor: 42000000,
      ),
      VendorEventParticipation(
        id: 'part_ibadan',
        eventId: 'evt_ibadan_culinary',
        eventTitle: 'Ibadan Culinary Week',
        city: 'Ibadan',
        venue: 'Trans Amusement Park',
        startsAt: DateTime(2025, 11, 10, 11, 0),
        status: VendorParticipationStatus.completed,
        boothLabel: 'Main pavilion',
        expectedPayoutMinor: 28000000,
      ),
    ];
  }

  static List<VendorCatalogItem> _seedCatalog() => const [
        VendorCatalogItem(
          id: 'cat_party',
          name: 'Party Jollof Package',
          description: 'Serves 50 · Smoky party jollof, plantain, coleslaw',
          category: 'Catering',
          priceMinor: 45000000,
          currency: 'NGN',
          ordersCount: 12,
        ),
        VendorCatalogItem(
          id: 'cat_vip',
          name: 'VIP Canapé Flight',
          description: '24 pieces · Puff puff, suya bites, pepper soup shots',
          category: 'Catering',
          priceMinor: 18000000,
          currency: 'NGN',
          ordersCount: 8,
        ),
        VendorCatalogItem(
          id: 'cat_drink',
          name: 'Zobo & Chapman Station',
          description: 'Self-serve station · 100 cups included',
          category: 'Catering',
          priceMinor: 12000000,
          currency: 'NGN',
          ordersCount: 5,
        ),
      ];

  static List<VendorOrder> _seedOrders() => [
        VendorOrder(
          id: 'ord_1',
          eventId: 'evt_lagos_owanbe_2026',
          eventTitle: 'Lagos Sunset Owanbe',
          customerName: 'Amaka O.',
          itemName: 'Party Jollof Package',
          amountMinor: 45000000,
          status: VendorOrderStatus.inProgress,
          placedAt: DateTime.now().subtract(const Duration(hours: 2)),
          notes: 'Setup by 5pm · Zone B',
        ),
        VendorOrder(
          id: 'ord_2',
          eventId: 'evt_lagos_owanbe_2026',
          eventTitle: 'Lagos Sunset Owanbe',
          customerName: 'Tunde K.',
          itemName: 'VIP Canapé Flight',
          amountMinor: 18000000,
          status: VendorOrderStatus.accepted,
          placedAt: DateTime.now().subtract(const Duration(hours: 5)),
        ),
        VendorOrder(
          id: 'ord_3',
          eventId: 'evt_lagos_owanbe_2026',
          eventTitle: 'Lagos Sunset Owanbe',
          customerName: 'Organizer pre-order',
          itemName: 'Zobo & Chapman Station',
          amountMinor: 12000000,
          status: VendorOrderStatus.fulfilled,
          placedAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
        VendorOrder(
          id: 'ord_4',
          eventId: 'evt_lagos_owanbe_2026',
          eventTitle: 'Lagos Sunset Owanbe',
          customerName: 'Chioma E.',
          itemName: 'Party Jollof Package',
          amountMinor: 45000000,
          status: VendorOrderStatus.newOrder,
          placedAt: DateTime.now().subtract(const Duration(minutes: 20)),
        ),
      ];

  static List<VendorWalletEntry> _seedWallet() => [
        VendorWalletEntry(
          id: 'wlt_1',
          type: VendorWalletEntryType.earning,
          amountMinor: 45000000,
          label: 'Party Jollof Package',
          reference: 'ord_3',
          timestamp: DateTime.now().subtract(const Duration(days: 1)),
        ),
        VendorWalletEntry(
          id: 'wlt_2',
          type: VendorWalletEntryType.earning,
          amountMinor: 18000000,
          label: 'VIP Canapé Flight',
          reference: 'ord_2',
          timestamp: DateTime.now().subtract(const Duration(hours: 5)),
          status: 'pending',
        ),
        VendorWalletEntry(
          id: 'wlt_3',
          type: VendorWalletEntryType.earning,
          amountMinor: 45000000,
          label: 'Party Jollof Package',
          reference: 'ord_1',
          timestamp: DateTime.now().subtract(const Duration(hours: 2)),
          status: 'pending',
        ),
      ];

  static List<VendorPayoutRequest> _seedPayouts() => [
        VendorPayoutRequest(
          id: 'pay_prev',
          amountMinor: 25000000,
          status: VendorPayoutStatus.completed,
          requestedAt: DateTime.now().subtract(const Duration(days: 14)),
          completedAt: DateTime.now().subtract(const Duration(days: 12)),
        ),
        VendorPayoutRequest(
          id: 'pay_pending',
          amountMinor: 15000000,
          status: VendorPayoutStatus.pending,
          requestedAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ];
}
