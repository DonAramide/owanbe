import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/persistence_providers.dart';
import '../../../features/organizer/providers/organizer_providers.dart';
import '../../../features/organizer/data/organizer_event_store.dart';
import '../../../features/organizer/models/organizer_models.dart';
import '../../../features/public/models/public_models.dart';
import '../../../features/public/providers/public_providers.dart';

/// Enriched event view for attendee commerce (public event + optional organizer metadata).
class AttendeeEventCommerceView {
  const AttendeeEventCommerceView({
    required this.event,
    this.organizerLabel = 'Verified Owambe Organizer',
    this.venueAddress,
    this.galleryLabels = const [],
    this.bannerLabel,
    this.tags = const [],
  });

  final PublicEvent event;
  final String organizerLabel;
  final String? venueAddress;
  final List<String> galleryLabels;
  final String? bannerLabel;
  final List<String> tags;

  String get eventId => event.id;

  int get totalTicketsRemaining =>
      event.ticketTiers.fold(0, (sum, tier) => sum + tier.remaining);

  bool get hasTicketAvailability => totalTicketsRemaining > 0;

  static AttendeeEventCommerceView fromPublic(PublicEvent event, [OrganizerEvent? source]) {
    final organizer = (event.organizerName?.trim().isNotEmpty ?? false)
        ? event.organizerName!.trim()
        : 'Verified Owambe Organizer';
    if (source == null) {
      return AttendeeEventCommerceView(
        event: event,
        organizerLabel: organizer,
        venueAddress: event.venueAddress,
      );
    }
    return AttendeeEventCommerceView(
      event: event,
      organizerLabel: organizer,
      venueAddress: (event.venueAddress?.trim().isNotEmpty ?? false)
          ? event.venueAddress
          : (source.venueAddress.isNotEmpty ? source.venueAddress : null),
      galleryLabels: source.mediaLabels,
      bannerLabel: source.bannerLabel,
      tags: source.tags,
    );
  }
}

/// Loads any event by id for attendee commerce — works for all published events.
final attendeeEventCommerceProvider =
    FutureProvider.autoDispose.family<AttendeeEventCommerceView?, String>((ref, eventId) async {
  ref.watch(organizerRevisionProvider);
  final event = await ref.watch(publicEventProvider(eventId).future);
  if (event == null) return null;

  if (allowMockPersistenceFallback()) {
    final source = OrganizerEventStore.instance.byId(eventId);
    return AttendeeEventCommerceView.fromPublic(event, source);
  }
  return AttendeeEventCommerceView.fromPublic(event);
});
