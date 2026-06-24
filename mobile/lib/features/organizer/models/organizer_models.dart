import '../../public/models/public_models.dart';
import '../../../shared/models/event_access_mode.dart';

enum OrganizerEventStatus { draft, published, live, completed, cancelled }

enum VenueType { physical, virtual, hybrid }

enum TicketTierType { regular, vip, vvip, earlyBird, group, corporate, table }

enum TicketVisibility { publicListing, hidden }

enum VendorSlotStatus { invited, pending, approved, rejected, suspended }

enum OrganizerAttentionType {
  pendingVendorApproval,
  lowTicketSales,
  refundRequest,
  unpublishedDraft,
}

class OrganizerEvent {
  const OrganizerEvent({
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
    this.venueType = VenueType.physical,
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
  final OrganizerEventStatus status;
  final VenueType venueType;
  final List<String> tags;
  final String bannerLabel;
  final List<String> mediaLabels;
  final int coverGradientStart;
  final int coverGradientEnd;
  final List<OrganizerTicketTier> ticketTiers;
  final List<OrganizerVendorSlot> vendors;
  final List<OrganizerAttendee> attendees;
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

  bool get isPrivateCelebration => eventAccessMode == EventAccessMode.privateInvitation;

  bool get isPublicTicketed => eventAccessMode == EventAccessMode.publicTicketed;

  bool get isUpcoming =>
      status == OrganizerEventStatus.published || status == OrganizerEventStatus.draft;

  int get ticketsSold => ticketTiers.fold(0, (sum, t) => sum + (t.capacity - t.remaining));

  int get revenueMinor =>
      ticketTiers.fold(0, (sum, t) => sum + (t.capacity - t.remaining) * t.priceMinor);

  int get totalCapacity => ticketTiers.fold(0, (sum, t) => sum + t.capacity);

  int get checkedInCount => attendees.where((a) => a.checkedIn).length;

  int get noShowCount => attendees.where((a) => !a.checkedIn).length;

  double get sellThroughRate => totalCapacity == 0 ? 0 : ticketsSold / totalCapacity;

  OrganizerEvent copyWith({
    String? title,
    String? tagline,
    String? description,
    String? city,
    String? venue,
    DateTime? startsAt,
    DateTime? endsAt,
    String? category,
    OrganizerEventStatus? status,
    VenueType? venueType,
    List<String>? tags,
    String? bannerLabel,
    List<String>? mediaLabels,
    List<OrganizerTicketTier>? ticketTiers,
    List<OrganizerVendorSlot>? vendors,
    List<OrganizerAttendee>? attendees,
    bool? isFeatured,
    int? pageViews,
    int? refundRequests,
    DateTime? publishedAt,
    EventAccessMode? eventAccessMode,
    int? budgetMinor,
    int? expectedGuests,
    String? categorySlug,
    String? venueName,
    String? venueAddress,
    double? venueLatitude,
    double? venueLongitude,
    String? googlePlaceId,
    String? celebrantImageUrl,
  }) {
    return OrganizerEvent(
      id: id,
      title: title ?? this.title,
      tagline: tagline ?? this.tagline,
      description: description ?? this.description,
      city: city ?? this.city,
      venue: venue ?? this.venue,
      startsAt: startsAt ?? this.startsAt,
      endsAt: endsAt ?? this.endsAt,
      category: category ?? this.category,
      status: status ?? this.status,
      venueType: venueType ?? this.venueType,
      tags: tags ?? this.tags,
      bannerLabel: bannerLabel ?? this.bannerLabel,
      mediaLabels: mediaLabels ?? this.mediaLabels,
      coverGradientStart: coverGradientStart,
      coverGradientEnd: coverGradientEnd,
      ticketTiers: ticketTiers ?? this.ticketTiers,
      vendors: vendors ?? this.vendors,
      attendees: attendees ?? this.attendees,
      isFeatured: isFeatured ?? this.isFeatured,
      pageViews: pageViews ?? this.pageViews,
      refundRequests: refundRequests ?? this.refundRequests,
      createdAt: createdAt,
      publishedAt: publishedAt ?? this.publishedAt,
      eventAccessMode: eventAccessMode ?? this.eventAccessMode,
      budgetMinor: budgetMinor ?? this.budgetMinor,
      expectedGuests: expectedGuests ?? this.expectedGuests,
      categorySlug: categorySlug ?? this.categorySlug,
      venueName: venueName ?? this.venueName,
      venueAddress: venueAddress ?? this.venueAddress,
      venueLatitude: venueLatitude ?? this.venueLatitude,
      venueLongitude: venueLongitude ?? this.venueLongitude,
      googlePlaceId: googlePlaceId ?? this.googlePlaceId,
      celebrantImageUrl: celebrantImageUrl ?? this.celebrantImageUrl,
    );
  }

  PublicEvent toPublicEvent() {
    return PublicEvent(
      id: id,
      title: title,
      tagline: tagline,
      description: description,
      city: city,
      venue: venue,
      startsAt: startsAt,
      endsAt: endsAt,
      coverGradientStart: coverGradientStart,
      coverGradientEnd: coverGradientEnd,
      category: category,
      isFeatured: isFeatured,
      attendeeCount: ticketsSold,
      status: switch (status) {
        OrganizerEventStatus.live => 'live',
        OrganizerEventStatus.completed => 'completed',
        OrganizerEventStatus.cancelled => 'cancelled',
        _ => 'upcoming',
      },
      ticketTiers: ticketTiers
          .where((t) => t.visibility == TicketVisibility.publicListing && !t.salesPaused)
          .map(
            (t) => TicketTier(
              id: t.id,
              name: t.name,
              description: t.description,
              priceMinor: t.priceMinor,
              currency: t.currency,
              remaining: t.remaining,
            ),
          )
          .toList(),
    );
  }
}

class OrganizerTicketTier {
  const OrganizerTicketTier({
    required this.id,
    required this.name,
    required this.description,
    required this.priceMinor,
    required this.currency,
    required this.capacity,
    required this.remaining,
    this.dbTierId,
    this.tierType = TicketTierType.regular,
    this.visibility = TicketVisibility.publicListing,
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
  final TicketTierType tierType;
  final TicketVisibility visibility;
  final DateTime? salesWindowStart;
  final DateTime? salesWindowEnd;
  final bool salesPaused;

  OrganizerTicketTier copyWith({
    String? name,
    String? description,
    int? priceMinor,
    int? capacity,
    int? remaining,
    TicketTierType? tierType,
    TicketVisibility? visibility,
    DateTime? salesWindowStart,
    DateTime? salesWindowEnd,
    bool? salesPaused,
  }) {
    return OrganizerTicketTier(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      priceMinor: priceMinor ?? this.priceMinor,
      currency: currency,
      capacity: capacity ?? this.capacity,
      remaining: remaining ?? this.remaining,
      tierType: tierType ?? this.tierType,
      visibility: visibility ?? this.visibility,
      salesWindowStart: salesWindowStart ?? this.salesWindowStart,
      salesWindowEnd: salesWindowEnd ?? this.salesWindowEnd,
      salesPaused: salesPaused ?? this.salesPaused,
    );
  }
}

class OrganizerVendorSlot {
  const OrganizerVendorSlot({
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
  final VendorSlotStatus status;
  final String? catalogVendorId;
  final String? city;
  final String? contactEmail;
  final int revenueMinor;
  final int ordersCount;

  OrganizerVendorSlot copyWith({VendorSlotStatus? status, int? revenueMinor, int? ordersCount}) =>
      OrganizerVendorSlot(
        id: id,
        businessName: businessName,
        category: category,
        tier: tier,
        status: status ?? this.status,
        catalogVendorId: catalogVendorId,
        city: city,
        contactEmail: contactEmail,
        revenueMinor: revenueMinor ?? this.revenueMinor,
        ordersCount: ordersCount ?? this.ordersCount,
      );
}

class AttendeePurchase {
  const AttendeePurchase({required this.item, required this.amountMinor, required this.purchasedAt});

  final String item;
  final int amountMinor;
  final DateTime purchasedAt;
}

class AttendeeTimelineEvent {
  const AttendeeTimelineEvent({required this.label, required this.at});

  final String label;
  final DateTime at;
}

class OrganizerAttendee {
  const OrganizerAttendee({
    required this.id,
    required this.name,
    required this.email,
    required this.tierName,
    required this.ticketId,
    this.checkedIn = false,
    this.purchasedAt,
    this.purchases = const [],
    this.timeline = const [],
  });

  final String id;
  final String name;
  final String email;
  final String tierName;
  final String ticketId;
  final bool checkedIn;
  final DateTime? purchasedAt;
  final List<AttendeePurchase> purchases;
  final List<AttendeeTimelineEvent> timeline;

  OrganizerAttendee copyWith({bool? checkedIn, List<AttendeeTimelineEvent>? timeline}) =>
      OrganizerAttendee(
        id: id,
        name: name,
        email: email,
        tierName: tierName,
        ticketId: ticketId,
        checkedIn: checkedIn ?? this.checkedIn,
        purchasedAt: purchasedAt,
        purchases: purchases,
        timeline: timeline ?? this.timeline,
      );
}

class OrganizerAttentionItem {
  const OrganizerAttentionItem({
    required this.type,
    required this.headline,
    required this.message,
    this.eventId,
    this.severity = 'WARNING',
  });

  final OrganizerAttentionType type;
  final String headline;
  final String message;
  final String? eventId;
  final String severity;
}

class EventAnalyticsSnapshot {
  const EventAnalyticsSnapshot({
    required this.eventId,
    required this.pageViews,
    required this.ticketsSold,
    required this.revenueMinor,
    required this.checkInRate,
    required this.registrations,
    required this.checkIns,
    required this.noShows,
    required this.dailySales,
    required this.weeklySales,
    required this.monthlySales,
    required this.salesTrend,
    required this.tierBreakdown,
    required this.tierTypeBreakdown,
  });

  final String eventId;
  final int pageViews;
  final int ticketsSold;
  final int revenueMinor;
  final double checkInRate;
  final int registrations;
  final int checkIns;
  final int noShows;
  final List<double> dailySales;
  final List<double> weeklySales;
  final List<double> monthlySales;
  final List<double> salesTrend;
  final Map<String, int> tierBreakdown;
  final Map<TicketTierType, int> tierTypeBreakdown;
}

class EventWizardV2Draft {
  EventWizardV2Draft({
    this.categorySlug = '',
    this.categoryLabel = '',
    this.eventAccessMode = EventAccessMode.privateInvitation,
    this.title = '',
    this.tagline = '',
    this.city = '',
    this.venueName = '',
    this.venueAddress = '',
    this.venueLatitude,
    this.venueLongitude,
    this.googlePlaceId,
    this.budgetMinor = 0,
    this.expectedGuests = 150,
    this.tags = const [],
    this.budgetAllocation = const [],
    DateTime? startsAt,
    DateTime? endsAt,
    this.ticketTiers = const [],
    this.preferredVendorIds = const [],
    this.requiredServices = const [],
    this.venueDeferred = false,
    this.state = '',
    this.lga = '',
    this.celebrantImageUrl,
  })  : startsAt = startsAt ?? DateTime.now().add(const Duration(days: 60)),
        endsAt = endsAt ?? DateTime.now().add(const Duration(days: 60, hours: 6));

  final String categorySlug;
  final String categoryLabel;
  final EventAccessMode eventAccessMode;
  final String title;
  final String tagline;
  final String city;
  final String venueName;
  final String venueAddress;
  final double? venueLatitude;
  final double? venueLongitude;
  final String? googlePlaceId;
  final int budgetMinor;
  final int expectedGuests;
  final List<String> tags;
  final List<Map<String, dynamic>> budgetAllocation;
  final DateTime startsAt;
  final DateTime endsAt;
  final List<OrganizerTicketTier> ticketTiers;
  final List<String> preferredVendorIds;
  final List<String> requiredServices;
  final bool venueDeferred;
  final String state;
  final String lga;
  final String? celebrantImageUrl;
}

class EventWizardDraft {
  EventWizardDraft({
    this.title = '',
    this.tagline = '',
    this.description = '',
    this.city = '',
    this.venue = '',
    this.category = 'Festival',
    this.venueType = VenueType.physical,
    this.tags = const [],
    this.bannerLabel = 'Hero banner',
    this.mediaLabels = const [],
    DateTime? startsAt,
    DateTime? endsAt,
    this.ticketTiers = const [],
  })  : startsAt = startsAt ?? DateTime.now().add(const Duration(days: 30)),
        endsAt = endsAt ?? DateTime.now().add(const Duration(days: 30, hours: 5));

  String title;
  String tagline;
  String description;
  String city;
  String venue;
  String category;
  VenueType venueType;
  List<String> tags;
  String bannerLabel;
  List<String> mediaLabels;
  DateTime startsAt;
  DateTime endsAt;
  List<OrganizerTicketTier> ticketTiers;
}

String ticketTierTypeLabel(TicketTierType type) => switch (type) {
      TicketTierType.regular => 'Regular',
      TicketTierType.vip => 'VIP',
      TicketTierType.vvip => 'VVIP',
      TicketTierType.earlyBird => 'Early Bird',
      TicketTierType.group => 'Group',
      TicketTierType.corporate => 'Corporate',
      TicketTierType.table => 'Table',
    };

String vendorSlotStatusLabel(VendorSlotStatus status) => status.name;
