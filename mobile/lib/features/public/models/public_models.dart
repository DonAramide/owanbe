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
  });

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

  TicketTier? cheapestTier() {
    if (ticketTiers.isEmpty) return null;
    return ticketTiers.reduce((a, b) => a.priceMinor < b.priceMinor ? a : b);
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
  });

  final String id;
  final String name;
  final String description;
  final int priceMinor;
  final String currency;
  final int remaining;
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
}
