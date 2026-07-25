class PublicEvent {
  const PublicEvent({
    required this.id,
    required this.title,
    required this.tagline,
    required this.description,
    required this.city,
    required this.venue,
    required this.startsAt,
    required this.endsAt,
    required this.coverGradientStart,
    required this.coverGradientEnd,
    required this.category,
    required this.isFeatured,
    required this.ticketTiers,
    this.attendeeCount,
    this.status = 'upcoming',
    this.venueType = 'physical',
    List<String> tags = const [],
    this.organizerId,
    this.venueLatitude,
    this.venueLongitude,
    this.ticketsSold = 0,
    this.venueAddress,
    this.celebrantImageUrl,
    List<EventGalleryItem> galleryMedia = const [],
    List<EventSpeaker> speakers = const [],
    List<EventSponsor> sponsors = const [],
    List<EventFaq> faqs = const [],
    this.organizerName,
    this.organizerContactEmail,
    this.organizerContactPhone,
  })  : _tags = tags,
        _galleryMedia = galleryMedia,
        _speakers = speakers,
        _sponsors = sponsors,
        _faqs = faqs;

  final String id;
  final String title;
  final String tagline;
  final String description;
  final String city;
  final String venue;
  final DateTime startsAt;
  final DateTime endsAt;
  final int coverGradientStart;
  final int coverGradientEnd;
  final String category;
  final bool isFeatured;
  final List<TicketTier> ticketTiers;
  final int? attendeeCount;
  final String status;
  final String venueType;
  final List<String>? _tags;
  final String? organizerId;
  final double? venueLatitude;
  final double? venueLongitude;
  final int ticketsSold;
  final String? venueAddress;
  final String? celebrantImageUrl;
  final List<EventGalleryItem>? _galleryMedia;
  final List<EventSpeaker>? _speakers;
  final List<EventSponsor>? _sponsors;
  final List<EventFaq>? _faqs;
  final String? organizerName;
  final String? organizerContactEmail;
  final String? organizerContactPhone;

  List<String> get tags => _tags ?? const [];
  List<EventGalleryItem> get galleryMedia => _galleryMedia ?? const [];
  List<EventSpeaker> get speakers => _speakers ?? const [];
  List<EventSponsor> get sponsors => _sponsors ?? const [];
  List<EventFaq> get faqs => _faqs ?? const [];

  TicketTier? cheapestTier() {
    if (ticketTiers.isEmpty) return null;
    return ticketTiers.reduce((a, b) => a.priceMinor < b.priceMinor ? a : b);
  }

  bool get isFree {
    if (ticketTiers.isEmpty) return false;
    return ticketTiers.every((t) => t.priceMinor <= 0);
  }

  bool get isPaid {
    if (ticketTiers.isEmpty) return false;
    return ticketTiers.any((t) => t.priceMinor > 0);
  }

  int get engagementScore {
    final sold = ticketsSold > 0 ? ticketsSold : (attendeeCount ?? 0);
    if (sold > 0) return sold * 10 + (isFeatured ? 50 : 0);
    final scarcity = ticketTiers.fold<int>(0, (s, t) {
      return s + (t.remaining < 20 ? (20 - t.remaining) : 0);
    });
    return scarcity + (isFeatured ? 25 : 0);
  }

  bool get hasCoordinates => venueLatitude != null && venueLongitude != null;

  List<EventGalleryItem> get resolvedGallery {
    final items = <EventGalleryItem>[
      ...galleryMedia.where((g) => g.url.trim().isNotEmpty),
    ];
    final cover = celebrantImageUrl?.trim();
    if (cover != null && cover.isNotEmpty && !items.any((g) => g.url == cover)) {
      items.insert(0, EventGalleryItem(url: cover, type: 'image', label: 'Cover'));
    }
    return items;
  }
}

class TicketTier {
  const TicketTier({
    required this.id,
    required this.name,
    required this.description,
    required this.priceMinor,
    required this.currency,
    required this.remaining,
    this.salesStartAt,
    this.salesEndAt,
    this.benefits = const [],
    this.accessLevel,
    this.perks = const [],
    this.restrictions = const [],
  });

  final String id;
  final String name;
  final String description;
  final int priceMinor;
  final String currency;
  final int remaining;
  final DateTime? salesStartAt;
  final DateTime? salesEndAt;
  final List<String> benefits;
  final String? accessLevel;
  final List<String> perks;
  final List<String> restrictions;

  bool get hasBenefitsContent =>
      benefits.isNotEmpty ||
      perks.isNotEmpty ||
      restrictions.isNotEmpty ||
      (accessLevel != null && accessLevel!.trim().isNotEmpty);
}

class EventGalleryItem {
  const EventGalleryItem({required this.url, this.type = 'image', this.label});
  final String url;
  final String type; // image | video
  final String? label;

  bool get isVideo => type.toLowerCase() == 'video' || url.toLowerCase().contains('.mp4');
}

class EventSpeaker {
  const EventSpeaker({required this.name, this.title, this.bio, this.imageUrl});
  final String name;
  final String? title;
  final String? bio;
  final String? imageUrl;
}

class EventSponsor {
  const EventSponsor({required this.name, this.tier, this.logoUrl, this.websiteUrl});
  final String name;
  final String? tier;
  final String? logoUrl;
  final String? websiteUrl;
}

class EventFaq {
  const EventFaq({required this.question, required this.answer});
  final String question;
  final String answer;
}

class CartLine {
  const CartLine({
    required this.eventId,
    required this.eventTitle,
    required this.tierId,
    required this.tierName,
    required this.unitPriceMinor,
    required this.currency,
    required this.quantity,
  });

  final String eventId;
  final String eventTitle;
  final String tierId;
  final String tierName;
  final int unitPriceMinor;
  final String currency;
  final int quantity;

  int get lineTotalMinor => unitPriceMinor * quantity;

  CartLine copyWith({int? quantity}) => CartLine(
        eventId: eventId,
        eventTitle: eventTitle,
        tierId: tierId,
        tierName: tierName,
        unitPriceMinor: unitPriceMinor,
        currency: currency,
        quantity: quantity ?? this.quantity,
      );
}

class AttendeeTicket {
  const AttendeeTicket({
    required this.id,
    required this.eventId,
    required this.eventTitle,
    required this.tierName,
    required this.venue,
    required this.city,
    required this.startsAt,
    required this.qrPayload,
    required this.purchasedAt,
    this.checkedIn = false,
    this.status = 'issued',
    this.endsAt,
    this.checkedInAt,
    this.venueAddress,
    this.accessLevel,
    this.seatLabel,
    this.gateInfo,
    this.entryInstructions,
    this.arrivalInstructions,
    this.supportContactEmail,
    this.supportContactPhone,
    this.groupLabel,
    this.ticketOrderId,
    this.siblingCount = 1,
    this.ticketCode,
  });

  final String id;
  final String eventId;
  final String eventTitle;
  final String tierName;
  final String venue;
  final String city;
  final DateTime startsAt;
  final String qrPayload;
  final DateTime purchasedAt;
  final bool checkedIn;
  /// Entitlement status: issued | checked_in | voided | refunded
  final String status;
  final DateTime? endsAt;
  final DateTime? checkedInAt;
  final String? venueAddress;
  final String? accessLevel;
  final String? seatLabel;
  final String? gateInfo;
  final String? entryInstructions;
  final String? arrivalInstructions;
  final String? supportContactEmail;
  final String? supportContactPhone;
  final String? groupLabel;
  final String? ticketOrderId;
  final int siblingCount;
  final String? ticketCode;

  bool get isCancelled =>
      status.toLowerCase() == 'voided' || status.toLowerCase() == 'refunded';
}
