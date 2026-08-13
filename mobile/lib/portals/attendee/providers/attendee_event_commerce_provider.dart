import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/persistence_providers.dart';
import '../../../features/organizer/providers/organizer_providers.dart';
import '../../../features/organizer/data/organizer_event_store.dart';
import '../../../features/organizer/models/organizer_models.dart';
import '../../../features/public/models/attendee_event_models.dart';
import '../../../features/public/models/public_models.dart';
import '../../../features/public/providers/attendee_events_provider.dart';
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

  /// Build a detail view from a registered pass when the public event API is unavailable
  /// (private invitation events, or legacy/seed rows blocked by visibility rules).
  static AttendeeEventCommerceView fromAttendeePass(AttendeeEventView pass) {
    final endsAt = pass.endsAt;
    final event = PublicEvent(
      id: pass.eventId,
      title: pass.eventTitle,
      tagline: pass.tagline.isNotEmpty ? pass.tagline : pass.eventTitle,
      description: pass.description.isNotEmpty
          ? pass.description
          : 'Join us for ${pass.eventTitle} in ${pass.city}.',
      city: pass.city,
      venue: pass.venue,
      startsAt: pass.startsAt,
      endsAt: endsAt,
      coverGradientStart: pass.coverGradientStart,
      coverGradientEnd: pass.coverGradientEnd,
      category: pass.category,
      isFeatured: false,
      ticketTiers: [
        TicketTier(
          id: pass.ticket.id,
          name: pass.tierName,
          description: pass.tierName,
          priceMinor: 0,
          currency: 'NGN',
          remaining: 0,
          accessLevel: pass.accessLevel,
        ),
      ],
      attendeeCount: pass.attendeeCount,
      status: pass.lifecycle.name,
      venueAddress: pass.venueAddress,
      organizerContactEmail: pass.supportContactEmail,
      organizerContactPhone: pass.supportContactPhone,
    );
    return AttendeeEventCommerceView(
      event: event,
      organizerLabel: 'Owambe Organizer',
      venueAddress: pass.venueAddress,
    );
  }
}

/// Loads event detail for attendees: public catalog first, then owned pass fallback.
final attendeeEventCommerceProvider =
    FutureProvider.autoDispose.family<AttendeeEventCommerceView?, String>((ref, eventId) async {
  ref.watch(organizerRevisionProvider);

  PublicEvent? publicEvent;
  try {
    publicEvent = await ref.watch(publicEventProvider(eventId).future);
  } catch (_) {
    publicEvent = null;
  }

  if (publicEvent != null) {
    if (allowMockPersistenceFallback()) {
      final source = OrganizerEventStore.instance.byId(eventId);
      return AttendeeEventCommerceView.fromPublic(publicEvent, source);
    }
    return AttendeeEventCommerceView.fromPublic(publicEvent);
  }

  // Private invitation / visibility-blocked: still open detail when the attendee holds a pass.
  final passes = await ref.watch(attendeeEventsProvider.future);
  final owned = passes.where((e) => e.eventId == eventId).toList();
  if (owned.isEmpty) return null;
  return AttendeeEventCommerceView.fromAttendeePass(owned.first);
});
