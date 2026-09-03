import '../../../shared/models/event_access_mode.dart';
import 'customer_event_models.dart';

String _eventPublicId(Map<String, dynamic> json) =>
    (json['externalRef'] ?? json['external_ref'] ?? json['id'] ?? '').toString();

DateTime? _parseDate(dynamic raw) {
  if (raw == null) return null;
  return DateTime.tryParse(raw.toString());
}

CustomerEventStatus mapCustomerEventStatus(String raw) => switch (raw) {
      'published' => CustomerEventStatus.published,
      'live' => CustomerEventStatus.live,
      'completed' => CustomerEventStatus.completed,
      'cancelled' => CustomerEventStatus.cancelled,
      _ => CustomerEventStatus.draft,
    };

CustomerVenueType mapCustomerVenueType(String raw) => switch (raw) {
      'virtual' => CustomerVenueType.virtual,
      'hybrid' => CustomerVenueType.hybrid,
      _ => CustomerVenueType.physical,
    };

CustomerTicketTierType mapCustomerTicketTierType(String raw) => switch (raw) {
      'vip' => CustomerTicketTierType.vip,
      'vvip' => CustomerTicketTierType.vvip,
      'earlyBird' => CustomerTicketTierType.earlyBird,
      'group' => CustomerTicketTierType.group,
      'corporate' => CustomerTicketTierType.corporate,
      'table' => CustomerTicketTierType.table,
      _ => CustomerTicketTierType.regular,
    };

CustomerTicketVisibility mapCustomerTicketVisibility(String raw) =>
    raw == 'hidden' ? CustomerTicketVisibility.hidden : CustomerTicketVisibility.publicListing;

CustomerTicketTier mapCustomerTicketTier(Map<String, dynamic> json, {String? dbTierId}) {
  final meta = json['metadata'] as Map<String, dynamic>? ?? {};
  return CustomerTicketTier(
    id: (json['id'] ?? json['externalTierId'] ?? '').toString(),
    dbTierId: dbTierId ?? json['tierId'] as String?,
    name: (json['name'] ?? '').toString(),
    description: (json['description'] ?? '').toString(),
    priceMinor: int.tryParse((json['priceMinor'] ?? '0').toString()) ?? 0,
    currency: (json['currency'] ?? 'NGN').toString(),
    capacity: (json['capacity'] as num?)?.toInt() ?? 0,
    remaining: (json['remaining'] as num?)?.toInt() ?? 0,
    tierType: mapCustomerTicketTierType((json['tierType'] ?? 'regular').toString()),
    visibility: mapCustomerTicketVisibility(
      (json['visibility'] ?? meta['visibility'] ?? 'publicListing').toString(),
    ),
    salesWindowStart: _parseDate(json['salesStartAt'] ?? meta['salesStartAt']),
    salesWindowEnd: _parseDate(json['salesEndAt'] ?? meta['salesEndAt']),
    salesPaused: json['salesPaused'] == true,
  );
}

/// Maps API event JSON to [CustomerEvent] (Event OS native model).
CustomerEvent mapCustomerEvent(Map<String, dynamic> json) {
  final tiers = (json['ticketTiers'] as List<dynamic>? ?? [])
      .map((e) => mapCustomerTicketTier(e as Map<String, dynamic>))
      .toList();
  return CustomerEvent(
    id: _eventPublicId(json),
    title: (json['title'] ?? '').toString(),
    tagline: (json['tagline'] ?? '').toString(),
    description: (json['description'] ?? '').toString(),
    city: (json['city'] ?? '').toString(),
    venue: (json['venue'] ?? '').toString(),
    startsAt: DateTime.parse((json['startsAt'] ?? DateTime.now().toIso8601String()).toString()),
    endsAt: json['endsAt'] != null
        ? DateTime.parse(json['endsAt'].toString())
        : DateTime.parse((json['startsAt'] ?? DateTime.now().toIso8601String()).toString())
            .add(const Duration(hours: 4)),
    category: (json['category'] ?? 'Festival').toString(),
    status: mapCustomerEventStatus((json['status'] ?? 'draft').toString()),
    venueType: mapCustomerVenueType((json['venueType'] ?? 'physical').toString()),
    tags: (json['tags'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
    bannerLabel: (json['bannerLabel'] ?? 'Default banner').toString(),
    mediaLabels: (json['mediaLabels'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
    coverGradientStart: (json['coverGradientStart'] as num?)?.toInt() ?? 0xFF4B2C6F,
    coverGradientEnd: (json['coverGradientEnd'] as num?)?.toInt() ?? 0xFFD4A853,
    ticketTiers: tiers,
    vendors: const [],
    attendees: const [],
    isFeatured: json['isFeatured'] == true,
    createdAt: _parseDate(json['createdAt']),
    publishedAt: _parseDate(json['publishedAt']),
    eventAccessMode: EventAccessModeX.fromApi(json['eventAccessMode']?.toString()),
    budgetMinor: int.tryParse((json['budgetMinor'] ?? '0').toString()) ?? 0,
    expectedGuests: (json['expectedGuests'] as num?)?.toInt() ?? 0,
    categorySlug: (json['categorySlug'] ?? '').toString(),
    venueName: (json['venueName'] ?? json['venue'] ?? '').toString(),
    venueAddress: (json['venueAddress'] ?? '').toString(),
    venueLatitude: (json['venueLatitude'] as num?)?.toDouble(),
    venueLongitude: (json['venueLongitude'] as num?)?.toDouble(),
    googlePlaceId: json['googlePlaceId']?.toString(),
    celebrantImageUrl: json['celebrantImageUrl']?.toString(),
    updatedAt: _parseDate(json['updatedAt']),
    state: (json['state'] ?? '').toString(),
    lga: (json['lga'] ?? '').toString(),
    organizerContactEmail: json['organizerContactEmail']?.toString(),
  );
}
