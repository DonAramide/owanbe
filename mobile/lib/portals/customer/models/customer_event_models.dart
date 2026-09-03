import '../../../shared/models/event_access_mode.dart';

/// Native Event OS event lifecycle status.
enum CustomerEventStatus { draft, published, live, completed, cancelled }

enum CustomerVenueType { physical, virtual, hybrid }

enum CustomerTicketTierType { regular, vip, vvip, earlyBird, group, corporate, table }

enum CustomerTicketVisibility { publicListing, hidden }

enum CustomerVendorSlotStatus { invited, pending, approved, rejected, suspended }

class CustomerTicketTier {
  const CustomerTicketTier({
    required this.id,
    required this.name,
    required this.description,
    required this.priceMinor,
    required this.currency,
    required this.capacity,
    required this.remaining,
    this.dbTierId,
    this.tierType = CustomerTicketTierType.regular,
    this.visibility = CustomerTicketVisibility.publicListing,
    this.salesWindowStart,
    this.salesWindowEnd,
    this.salesPaused = false,
  });

  final String id;
  final String? dbTierId;
  final String name;
  final String description;
  final int priceMinor;
  final String currency;
  final int capacity;
  final int remaining;
  final CustomerTicketTierType tierType;
  final CustomerTicketVisibility visibility;
  final DateTime? salesWindowStart;
  final DateTime? salesWindowEnd;
  final bool salesPaused;
}

class CustomerVendorSlot {
  const CustomerVendorSlot({
    required this.id,
    required this.businessName,
    required this.category,
    required this.tier,
    required this.status,
    this.catalogVendorId,
    this.city,
    this.contactEmail,
    this.revenueMinor = 0,
    this.ordersCount = 0,
  });

  final String id;
  final String businessName;
  final String category;
  final String tier;
  final CustomerVendorSlotStatus status;
  final String? catalogVendorId;
  final String? city;
  final String? contactEmail;
  final int revenueMinor;
  final int ordersCount;
}

class CustomerAttendee {
  const CustomerAttendee({
    required this.id,
    required this.name,
    required this.email,
    required this.tierName,
    required this.ticketId,
    this.checkedIn = false,
    this.purchasedAt,
  });

  final String id;
  final String name;
  final String email;
  final String tierName;
  final String ticketId;
  final bool checkedIn;
  final DateTime? purchasedAt;
}

/// Canonical Event OS event model (Customer Portal).
class CustomerEvent {
  const CustomerEvent({
    required this.id,
    required this.title,
    required this.tagline,
    required this.description,
    required this.city,
    required this.venue,
    required this.startsAt,
    required this.endsAt,
    required this.category,
    required this.status,
    required this.coverGradientStart,
    required this.coverGradientEnd,
    required this.ticketTiers,
    required this.vendors,
    required this.attendees,
    this.venueType = CustomerVenueType.physical,
    this.tags = const [],
    this.bannerLabel = 'Default banner',
    this.mediaLabels = const [],
    this.isFeatured = false,
    this.pageViews = 0,
    this.refundRequests = 0,
    this.createdAt,
    this.publishedAt,
    this.eventAccessMode = EventAccessMode.privateInvitation,
    this.budgetMinor = 0,
    this.expectedGuests = 0,
    this.categorySlug = '',
    this.venueName = '',
    this.venueAddress = '',
    this.venueLatitude,
    this.venueLongitude,
    this.googlePlaceId,
    this.celebrantImageUrl,
    this.updatedAt,
    this.state = '',
    this.lga = '',
    this.organizerContactEmail,
  });

  final String id;
  final String title;
  final String tagline;
  final String description;
  final String city;
  final String venue;
  final DateTime startsAt;
  final DateTime endsAt;
  final String category;
  final CustomerEventStatus status;
  final CustomerVenueType venueType;
  final List<String> tags;
  final String bannerLabel;
  final List<String> mediaLabels;
  final int coverGradientStart;
  final int coverGradientEnd;
  final List<CustomerTicketTier> ticketTiers;
  final List<CustomerVendorSlot> vendors;
  final List<CustomerAttendee> attendees;
  final bool isFeatured;
  final int pageViews;
  final int refundRequests;
  final DateTime? createdAt;
  final DateTime? publishedAt;
  final EventAccessMode eventAccessMode;
  final int budgetMinor;
  final int expectedGuests;
  final String categorySlug;
  final String venueName;
  final String venueAddress;
  final double? venueLatitude;
  final double? venueLongitude;
  final String? googlePlaceId;
  final String? celebrantImageUrl;
  final DateTime? updatedAt;
  final String state;
  final String lga;
  final String? organizerContactEmail;

  bool get isPrivateCelebration => eventAccessMode == EventAccessMode.privateInvitation;

  bool get isPublicTicketed => eventAccessMode == EventAccessMode.publicTicketed;

  int get ticketsSold => ticketTiers.fold(0, (sum, t) => sum + (t.capacity - t.remaining));

  int get revenueMinor =>
      ticketTiers.fold(0, (sum, t) => sum + (t.capacity - t.remaining) * t.priceMinor);

  int get totalCapacity => ticketTiers.fold(0, (sum, t) => sum + t.capacity);

  int get checkedInCount => attendees.where((a) => a.checkedIn).length;

  CustomerEvent copyWith({
    String? title,
    CustomerEventStatus? status,
    DateTime? publishedAt,
    List<CustomerVendorSlot>? vendors,
    List<CustomerAttendee>? attendees,
    List<CustomerTicketTier>? ticketTiers,
    int? budgetMinor,
    int? expectedGuests,
  }) {
    return CustomerEvent(
      id: id,
      title: title ?? this.title,
      tagline: tagline,
      description: description,
      city: city,
      venue: venue,
      startsAt: startsAt,
      endsAt: endsAt,
      category: category,
      status: status ?? this.status,
      coverGradientStart: coverGradientStart,
      coverGradientEnd: coverGradientEnd,
      ticketTiers: ticketTiers ?? this.ticketTiers,
      vendors: vendors ?? this.vendors,
      attendees: attendees ?? this.attendees,
      venueType: venueType,
      tags: tags,
      bannerLabel: bannerLabel,
      mediaLabels: mediaLabels,
      isFeatured: isFeatured,
      pageViews: pageViews,
      refundRequests: refundRequests,
      createdAt: createdAt,
      publishedAt: publishedAt ?? this.publishedAt,
      eventAccessMode: eventAccessMode,
      budgetMinor: budgetMinor ?? this.budgetMinor,
      expectedGuests: expectedGuests ?? this.expectedGuests,
      categorySlug: categorySlug,
      venueName: venueName,
      venueAddress: venueAddress,
      venueLatitude: venueLatitude,
      venueLongitude: venueLongitude,
      googlePlaceId: googlePlaceId,
      celebrantImageUrl: celebrantImageUrl,
      updatedAt: updatedAt,
      state: state,
      lga: lga,
      organizerContactEmail: organizerContactEmail,
    );
  }
}

/// Lightweight list card model for home / my events.
class CustomerEventSummary {
  const CustomerEventSummary({
    required this.id,
    required this.title,
    required this.startsAt,
    required this.city,
    required this.venue,
    required this.status,
    required this.guestCount,
    required this.progress,
    required this.coverGradientStart,
    required this.coverGradientEnd,
    required this.isLive,
  });

  final String id;
  final String title;
  final DateTime startsAt;
  final String city;
  final String venue;
  final CustomerEventStatus status;
  final int guestCount;
  final double progress;
  final int coverGradientStart;
  final int coverGradientEnd;
  final bool isLive;

  factory CustomerEventSummary.fromEvent(CustomerEvent event) {
    return CustomerEventSummary(
      id: event.id,
      title: event.title,
      startsAt: event.startsAt,
      city: event.city,
      venue: event.venue,
      status: event.status,
      guestCount: event.attendees.length,
      progress: computePlanningProgress(event),
      coverGradientStart: event.coverGradientStart,
      coverGradientEnd: event.coverGradientEnd,
      isLive: event.status == CustomerEventStatus.live,
    );
  }
}

/// Planning completion estimate (0–1) from event setup signals.
double computePlanningProgress(CustomerEvent event) {
  var score = 0.0;
  if (event.title.trim().isNotEmpty) score += 0.12;
  if (event.description.trim().isNotEmpty) score += 0.08;
  if (event.attendees.isNotEmpty) score += 0.22;
  if (event.vendors.isNotEmpty) score += 0.18;
  if (event.ticketTiers.isNotEmpty) score += 0.15;
  if (event.status == CustomerEventStatus.published ||
      event.status == CustomerEventStatus.live ||
      event.status == CustomerEventStatus.completed) {
    score += 0.25;
  }
  return score.clamp(0.0, 1.0);
}
