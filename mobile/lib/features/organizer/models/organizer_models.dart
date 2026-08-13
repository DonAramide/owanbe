import '../../public/models/public_models.dart';
import '../../../shared/models/event_access_mode.dart';

enum OrganizerEventStatus { draft, published, live, completed, cancelled }

enum VenueType { physical, virtual, hybrid }

enum TicketTierType { regular, vip, vvip, earlyBird, group, corporate, table, complimentary }

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
    this.language = 'en',
    this.ageRestrictionMin = 0,
    this.listingVisibility = 'invite_only',
    this.registrationEnabled = true,
    this.checkInEnabled = true,
    this.themeColor = '#4B2C6F',
    this.requiredServices = const [],
    this.venueDeferred = false,
    this.state = '',
    this.lga = '',
    this.selectedTemplateSlug = '',
    this.reportedTicketsSold,
    this.reportedRevenueMinor,
    this.reportedOrdersCount,
    this.reportedBuyersCount,
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
  final String language;
  final int ageRestrictionMin;
  final String listingVisibility;
  final bool registrationEnabled;
  final bool checkInEnabled;
  final String themeColor;
  final List<String> requiredServices;
  final bool venueDeferred;
  final String state;
  final String lga;
  final String selectedTemplateSlug;
  /// Server sales snapshot (Phase 14) — preferred over inventory-derived estimates.
  final int? reportedTicketsSold;
  final int? reportedRevenueMinor;
  final int? reportedOrdersCount;
  final int? reportedBuyersCount;

  bool get isPrivateCelebration => eventAccessMode == EventAccessMode.privateInvitation;

  bool get isPublicTicketed => eventAccessMode == EventAccessMode.publicTicketed;

  bool get isUpcoming =>
      startsAt.isAfter(DateTime.now()) &&
      (status == OrganizerEventStatus.draft ||
          status == OrganizerEventStatus.published ||
          status == OrganizerEventStatus.live);

  int get ticketsSold =>
      reportedTicketsSold ?? ticketTiers.fold(0, (sum, t) => sum + (t.capacity - t.remaining));

  int get revenueMinor =>
      reportedRevenueMinor ??
      ticketTiers.fold(0, (sum, t) => sum + (t.capacity - t.remaining) * t.priceMinor);

  int get ordersCount => reportedOrdersCount ?? 0;

  int get buyersCount => reportedBuyersCount ?? attendees.length;

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
    String? language,
    int? ageRestrictionMin,
    String? listingVisibility,
    bool? registrationEnabled,
    bool? checkInEnabled,
    String? themeColor,
    List<String>? requiredServices,
    bool? venueDeferred,
    String? state,
    String? lga,
    String? selectedTemplateSlug,
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
      language: language ?? this.language,
      ageRestrictionMin: ageRestrictionMin ?? this.ageRestrictionMin,
      listingVisibility: listingVisibility ?? this.listingVisibility,
      registrationEnabled: registrationEnabled ?? this.registrationEnabled,
      checkInEnabled: checkInEnabled ?? this.checkInEnabled,
      themeColor: themeColor ?? this.themeColor,
      requiredServices: requiredServices ?? this.requiredServices,
      venueDeferred: venueDeferred ?? this.venueDeferred,
      state: state ?? this.state,
      lga: lga ?? this.lga,
      selectedTemplateSlug: selectedTemplateSlug ?? this.selectedTemplateSlug,
      reportedTicketsSold: reportedTicketsSold,
      reportedRevenueMinor: reportedRevenueMinor,
      reportedOrdersCount: reportedOrdersCount,
      reportedBuyersCount: reportedBuyersCount,
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
              salesStartAt: t.salesWindowStart,
              salesEndAt: t.salesWindowEnd,
            ),
          )
          .toList(),
      venueType: venueType.name,
      tags: tags,
      venueLatitude: venueLatitude,
      venueLongitude: venueLongitude,
      ticketsSold: ticketsSold,
      venueAddress: venueAddress.isNotEmpty ? venueAddress : null,
      celebrantImageUrl: celebrantImageUrl,
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
    this.archived = false,
    this.unlimitedCapacity = false,
    this.minQuantity = 1,
    this.maxQuantity,
    this.maxPerUser,
    this.sortOrder = 0,
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
  final bool archived;
  final bool unlimitedCapacity;
  final int minQuantity;
  final int? maxQuantity;
  final int? maxPerUser;
  final int sortOrder;

  bool get isSoldOut => !unlimitedCapacity && remaining <= 0;

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
    bool? archived,
    bool? unlimitedCapacity,
    int? minQuantity,
    int? maxQuantity,
    int? maxPerUser,
    int? sortOrder,
    bool clearMaxQuantity = false,
    bool clearMaxPerUser = false,
  }) {
    return OrganizerTicketTier(
      id: id,
      dbTierId: dbTierId,
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
      archived: archived ?? this.archived,
      unlimitedCapacity: unlimitedCapacity ?? this.unlimitedCapacity,
      minQuantity: minQuantity ?? this.minQuantity,
      maxQuantity: clearMaxQuantity ? null : (maxQuantity ?? this.maxQuantity),
      maxPerUser: clearMaxPerUser ? null : (maxPerUser ?? this.maxPerUser),
      sortOrder: sortOrder ?? this.sortOrder,
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

class EventWizardV2Draft {
  EventWizardV2Draft({
    this.categorySlug = '',
    this.categoryLabel = '',
    this.eventAccessMode = EventAccessMode.privateInvitation,
    this.title = '',
    this.tagline = '',
    this.description = '',
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
    this.language = 'en',
    this.ageRestrictionMin = 0,
    this.listingVisibility = 'invite_only',
    this.venueType = VenueType.physical,
    this.registrationEnabled = true,
    this.checkInEnabled = true,
    this.bannerLabel = 'Default banner',
    this.themeColor = '#4B2C6F',
    this.selectedTemplateSlug = '',
  })  : startsAt = startsAt ?? DateTime.now().add(const Duration(days: 60)),
        endsAt = endsAt ?? DateTime.now().add(const Duration(days: 60, hours: 6));

  final String categorySlug;
  final String categoryLabel;
  final EventAccessMode eventAccessMode;
  final String title;
  final String tagline;
  final String description;
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
  /// BCP-47-ish language code for the event.
  final String language;
  /// 0 = none; otherwise minimum age.
  final int ageRestrictionMin;
  /// invite_only | public | hidden
  final String listingVisibility;
  final VenueType venueType;
  final bool registrationEnabled;
  final bool checkInEnabled;
  final String bannerLabel;
  final String themeColor;
  final String selectedTemplateSlug;
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
      TicketTierType.complimentary => 'Complimentary',
    };

String vendorSlotStatusLabel(VendorSlotStatus status) => status.name;
