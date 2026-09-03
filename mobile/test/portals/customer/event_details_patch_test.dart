import 'package:flutter_test/flutter_test.dart';
import 'package:owambe/portals/customer/data/event_details_patch.dart';
import 'package:owambe/portals/customer/models/customer_event_mapper.dart';
import 'package:owambe/portals/customer/models/customer_event_models.dart';
import 'package:owambe/portals/customer/router/event_route_registry.dart';

void main() {
  final starts = DateTime.utc(2026, 8, 20, 14, 0);
  final event = CustomerEvent(
    id: 'evt_1',
    title: 'Test Date',
    tagline: 'A gathering',
    description: 'Details',
    city: 'Lagos',
    venue: 'Landmark',
    startsAt: starts,
    endsAt: starts.add(const Duration(hours: 6)),
    category: 'Wedding',
    status: CustomerEventStatus.published,
    coverGradientStart: 0xFF4B2C6F,
    coverGradientEnd: 0xFFD4A853,
    ticketTiers: const [],
    vendors: const [],
    attendees: const [],
    venueName: 'Landmark',
    venueAddress: 'Victoria Island',
    state: 'Lagos',
    lga: 'Eti-Osa',
    expectedGuests: 150,
    categorySlug: 'wedding',
  );

  test('PATCH body includes identity fields and omits ticketTiers', () {
    final body = EventDetailsDraft.fromEvent(event).toPatchBody();
    expect(body['title'], 'Test Date');
    expect(body['description'], 'Details');
    expect(body['venueName'], 'Landmark');
    expect(body['city'], 'Lagos');
    expect(body['state'], 'Lagos');
    expect(body.containsKey('ticketTiers'), isFalse);
    expect(body.containsKey('status'), isFalse);
    expect(body.containsKey('id'), isFalse);
    expect(body.containsKey('organizerId'), isFalse);
  });

  test('empty title is invalid', () {
    final draft = EventDetailsDraft.fromEvent(event);
    final invalid = EventDetailsDraft(
      title: '  ',
      tagline: draft.tagline,
      description: draft.description,
      category: draft.category,
      categorySlug: draft.categorySlug,
      startsAt: draft.startsAt,
      endsAt: draft.endsAt,
      venueName: draft.venueName,
      venueAddress: draft.venueAddress,
      city: draft.city,
      state: draft.state,
      lga: draft.lga,
      expectedGuests: draft.expectedGuests,
    );
    expect(invalid.validate(), 'Event name is required');
  });

  test('end before start is invalid', () {
    final draft = EventDetailsDraft.fromEvent(event);
    final invalid = EventDetailsDraft(
      title: draft.title,
      tagline: draft.tagline,
      description: draft.description,
      category: draft.category,
      categorySlug: draft.categorySlug,
      startsAt: draft.endsAt,
      endsAt: draft.startsAt.subtract(const Duration(hours: 1)),
      venueName: draft.venueName,
      venueAddress: draft.venueAddress,
      city: draft.city,
      state: draft.state,
      lga: draft.lga,
      expectedGuests: draft.expectedGuests,
    );
    expect(invalid.validate(), 'End time must be on or after start time');
  });

  test('mapper reads updatedAt and location metadata', () {
    final mapped = mapCustomerEvent({
      'id': 'uuid-1',
      'externalRef': 'evt_1',
      'title': 'Mapped',
      'startsAt': '2026-08-20T14:00:00.000Z',
      'updatedAt': '2026-08-21T10:00:00.000Z',
      'createdAt': '2026-06-01T00:00:00.000Z',
      'state': 'Lagos',
      'lga': 'Ikeja',
      'organizerContactEmail': 'host@owanbe.dev',
    });
    expect(mapped.updatedAt, DateTime.parse('2026-08-21T10:00:00.000Z'));
    expect(mapped.state, 'Lagos');
    expect(mapped.lga, 'Ikeja');
    expect(mapped.organizerContactEmail, 'host@owanbe.dev');
  });

  test('event edit route is registered', () {
    expect(EventRouteRegistry.eventEdit('evt_1'), '/events/evt_1/edit');
    expect(EventRouteRegistry.isEventModulePath('/events/evt_1/edit'), isTrue);
  });
}
