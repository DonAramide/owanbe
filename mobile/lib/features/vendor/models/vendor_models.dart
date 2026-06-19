enum VendorParticipationStatus { invited, pending, confirmed, live, completed, declined }

/// UI lifecycle stages for event participation.
enum ParticipationLifecycle { invited, applied, approved, completed }

enum VendorCatalogType {
  catering('Catering'),
  photography('Photography'),
  decoration('Decoration'),
  entertainment('Entertainment'),
  security('Security'),
  rentals('Rentals'),
  beauty('Beauty'),
  logistics('Logistics');

  const VendorCatalogType(this.label);
  final String label;

  static VendorCatalogType? fromLabel(String label) {
    for (final t in values) {
      if (t.label.toLowerCase() == label.toLowerCase()) return t;
    }
    return null;
  }
}

enum VendorCatalogStatus { active, draft, paused }

enum VendorOrderStatus { newOrder, accepted, inProgress, fulfilled, cancelled }

enum VendorPayoutStatus { pending, processing, completed, failed }

enum VendorWalletEntryType { earning, refund, payout, adjustment }

class VendorProfile {
  const VendorProfile({
    required this.id,
    required this.businessName,
    required this.category,
    required this.vendorType,
    required this.tier,
    required this.city,
    this.tagline = '',
    this.rating = 0,
    this.completedEvents = 0,
  });

  final String id;
  final String businessName;
  final String category;
  final VendorCatalogType vendorType;
  final String tier;
  final String city;
  final String tagline;
  final double rating;
  final int completedEvents;
}

class VendorEventParticipation {
  const VendorEventParticipation({
    required this.id,
    required this.eventId,
    required this.eventTitle,
    required this.city,
    required this.venue,
    required this.startsAt,
    required this.status,
    required this.boothLabel,
    this.organizerName = 'Event organizer',
    this.expectedPayoutMinor = 0,
  });

  final String id;
  final String eventId;
  final String eventTitle;
  final String city;
  final String venue;
  final DateTime startsAt;
  final VendorParticipationStatus status;
  final String boothLabel;
  final String organizerName;
  final int expectedPayoutMinor;

  ParticipationLifecycle get lifecycleStage => switch (status) {
        VendorParticipationStatus.invited => ParticipationLifecycle.invited,
        VendorParticipationStatus.pending => ParticipationLifecycle.applied,
        VendorParticipationStatus.confirmed => ParticipationLifecycle.approved,
        VendorParticipationStatus.live => ParticipationLifecycle.approved,
        VendorParticipationStatus.completed => ParticipationLifecycle.completed,
        VendorParticipationStatus.declined => ParticipationLifecycle.invited,
      };

  String get lifecycleLabel => switch (lifecycleStage) {
        ParticipationLifecycle.invited => 'invited',
        ParticipationLifecycle.applied => 'applied',
        ParticipationLifecycle.approved => 'approved',
        ParticipationLifecycle.completed => 'completed',
      };

  String get statusLabel => switch (status) {
        VendorParticipationStatus.invited => 'invited',
        VendorParticipationStatus.pending => 'pending',
        VendorParticipationStatus.confirmed => 'confirmed',
        VendorParticipationStatus.live => 'live',
        VendorParticipationStatus.completed => 'completed',
        VendorParticipationStatus.declined => 'declined',
      };

  String get publicStatus => switch (status) {
        VendorParticipationStatus.live => 'live',
        VendorParticipationStatus.completed => 'completed',
        _ => 'upcoming',
      };
}

class VendorCatalogItem {
  const VendorCatalogItem({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.priceMinor,
    required this.currency,
    this.status = VendorCatalogStatus.active,
    this.ordersCount = 0,
  });

  final String id;
  final String name;
  final String description;
  final String category;
  final int priceMinor;
  final String currency;
  final VendorCatalogStatus status;
  final int ordersCount;

  VendorCatalogItem copyWith({
    String? name,
    String? description,
    VendorCatalogStatus? status,
    int? ordersCount,
  }) =>
      VendorCatalogItem(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        category: category,
        priceMinor: priceMinor,
        currency: currency,
        status: status ?? this.status,
        ordersCount: ordersCount ?? this.ordersCount,
      );
}

class VendorOrder {
  const VendorOrder({
    required this.id,
    required this.eventId,
    required this.eventTitle,
    required this.customerName,
    required this.itemName,
    required this.amountMinor,
    required this.status,
    required this.placedAt,
    this.notes,
  });

  final String id;
  final String eventId;
  final String eventTitle;
  final String customerName;
  final String itemName;
  final int amountMinor;
  final VendorOrderStatus status;
  final DateTime placedAt;
  final String? notes;

  String get statusLabel => switch (status) {
        VendorOrderStatus.newOrder => 'new',
        VendorOrderStatus.accepted => 'accepted',
        VendorOrderStatus.inProgress => 'in_progress',
        VendorOrderStatus.fulfilled => 'fulfilled',
        VendorOrderStatus.cancelled => 'cancelled',
      };
}

class VendorWalletSnapshot {
  const VendorWalletSnapshot({
    required this.availableMinor,
    required this.pendingMinor,
    required this.totalEarnedMinor,
    required this.underReviewMinor,
  });

  final int availableMinor;
  final int pendingMinor;
  final int totalEarnedMinor;
  final int underReviewMinor;
}

class VendorWalletEntry {
  const VendorWalletEntry({
    required this.id,
    required this.type,
    required this.amountMinor,
    required this.label,
    required this.reference,
    required this.timestamp,
    this.status = 'completed',
  });

  final String id;
  final VendorWalletEntryType type;
  final int amountMinor;
  final String label;
  final String reference;
  final DateTime timestamp;
  final String status;
}

class VendorPayoutRequest {
  const VendorPayoutRequest({
    required this.id,
    required this.amountMinor,
    required this.status,
    required this.requestedAt,
    this.completedAt,
    this.destinationLabel = 'Primary bank account',
  });

  final String id;
  final int amountMinor;
  final VendorPayoutStatus status;
  final DateTime requestedAt;
  final DateTime? completedAt;
  final String destinationLabel;

  String get statusLabel => switch (status) {
        VendorPayoutStatus.pending => 'pending',
        VendorPayoutStatus.processing => 'processing',
        VendorPayoutStatus.completed => 'completed',
        VendorPayoutStatus.failed => 'failed',
      };
}

class VendorAnalyticsSnapshot {
  const VendorAnalyticsSnapshot({
    required this.revenueMinor,
    required this.ordersCount,
    required this.fulfillmentRate,
    required this.avgOrderMinor,
    required this.revenueTrend,
    required this.ordersByEvent,
  });

  final int revenueMinor;
  final int ordersCount;
  final double fulfillmentRate;
  final int avgOrderMinor;
  final List<double> revenueTrend;
  final Map<String, int> ordersByEvent;
}
