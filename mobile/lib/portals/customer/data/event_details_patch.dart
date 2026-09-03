import '../models/customer_event_models.dart';

/// Identity fields the Organizer Event Details editor may PATCH.
///
/// Never includes ticketTiers, status, ownership, or commerce records.
class EventDetailsDraft {
  const EventDetailsDraft({
    required this.title,
    required this.tagline,
    required this.description,
    required this.category,
    required this.categorySlug,
    required this.startsAt,
    required this.endsAt,
    required this.venueName,
    required this.venueAddress,
    required this.city,
    required this.state,
    required this.lga,
    required this.expectedGuests,
    this.venueType = CustomerVenueType.physical,
    this.celebrantImageUrl,
  });

  final String title;
  final String tagline;
  final String description;
  final String category;
  final String categorySlug;
  final DateTime startsAt;
  final DateTime endsAt;
  final String venueName;
  final String venueAddress;
  final String city;
  final String state;
  final String lga;
  final int expectedGuests;
  final CustomerVenueType venueType;
  final String? celebrantImageUrl;

  factory EventDetailsDraft.fromEvent(CustomerEvent event) {
    return EventDetailsDraft(
      title: event.title,
      tagline: event.tagline,
      description: event.description,
      category: event.category,
      categorySlug: event.categorySlug,
      startsAt: event.startsAt,
      endsAt: event.endsAt,
      venueName: event.venueName.isNotEmpty ? event.venueName : event.venue,
      venueAddress: event.venueAddress,
      city: event.city,
      state: event.state,
      lga: event.lga,
      expectedGuests: event.expectedGuests,
      venueType: event.venueType,
      celebrantImageUrl: event.celebrantImageUrl,
    );
  }

  String? validate() {
    if (title.trim().isEmpty) return 'Event name is required';
    if (endsAt.isBefore(startsAt)) return 'End time must be on or after start time';
    if (expectedGuests < 0) return 'Expected guests cannot be negative';
    return null;
  }

  /// Body for existing `PATCH /events/:eventId`. Omits ticketTiers on purpose.
  Map<String, dynamic> toPatchBody() {
    return {
      'title': title.trim(),
      'tagline': tagline.trim(),
      'description': description.trim(),
      'category': category.trim(),
      if (categorySlug.trim().isNotEmpty) 'categorySlug': categorySlug.trim(),
      'startsAt': startsAt.toUtc().toIso8601String(),
      'endsAt': endsAt.toUtc().toIso8601String(),
      'venue': venueName.trim(),
      'venueName': venueName.trim(),
      'venueAddress': venueAddress.trim(),
      'city': city.trim(),
      'state': state.trim(),
      'lga': lga.trim(),
      'expectedGuests': expectedGuests,
      'venueType': venueType.name,
      if (celebrantImageUrl != null) 'celebrantImageUrl': celebrantImageUrl,
    };
  }

  EventDetailsDraft copyWith({String? celebrantImageUrl}) {
    return EventDetailsDraft(
      title: title,
      tagline: tagline,
      description: description,
      category: category,
      categorySlug: categorySlug,
      startsAt: startsAt,
      endsAt: endsAt,
      venueName: venueName,
      venueAddress: venueAddress,
      city: city,
      state: state,
      lga: lga,
      expectedGuests: expectedGuests,
      venueType: venueType,
      celebrantImageUrl: celebrantImageUrl ?? this.celebrantImageUrl,
    );
  }
}
