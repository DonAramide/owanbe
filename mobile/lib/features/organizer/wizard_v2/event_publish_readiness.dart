import '../models/organizer_models.dart';
import '../../../shared/models/event_access_mode.dart';

class EventReadinessItem {
  const EventReadinessItem({
    required this.id,
    required this.label,
    required this.done,
    required this.severity,
    this.actionLabel,
  });

  final String id;
  final String label;
  final bool done;
  final String severity; // blocking | warning | info
  final String? actionLabel;
}

class EventPublishReadiness {
  const EventPublishReadiness({
    required this.items,
    required this.readyToPublish,
    required this.nextBestActionId,
  });

  final List<EventReadinessItem> items;
  final bool readyToPublish;
  final String nextBestActionId;

  List<EventReadinessItem> get blocking => items.where((i) => !i.done && i.severity == 'blocking').toList();
  List<EventReadinessItem> get warnings => items.where((i) => !i.done && i.severity == 'warning').toList();
}

/// Shared readiness rules for wizard review + Event Workspace guidance.
EventPublishReadiness evaluateEventPublishReadiness({
  required String title,
  required DateTime startsAt,
  required DateTime endsAt,
  required EventAccessMode accessMode,
  required bool venueDeferred,
  required String venueName,
  required String city,
  required List<OrganizerTicketTier> ticketTiers,
  String description = '',
  String? celebrantImageUrl,
  bool hasCelebrantBytes = false,
}) {
  final items = <EventReadinessItem>[
    EventReadinessItem(
      id: 'title',
      label: 'Event name',
      done: title.trim().isNotEmpty,
      severity: 'blocking',
      actionLabel: 'Add name',
    ),
    EventReadinessItem(
      id: 'dates',
      label: 'Start and end date/time',
      done: endsAt.isAfter(startsAt),
      severity: 'blocking',
      actionLabel: 'Fix schedule',
    ),
    EventReadinessItem(
      id: 'venue',
      label: venueDeferred ? 'Venue (deferred — OK for draft)' : 'Venue or city',
      done: venueDeferred || venueName.trim().isNotEmpty || city.trim().isNotEmpty,
      severity: venueDeferred ? 'info' : 'warning',
      actionLabel: 'Set venue',
    ),
    EventReadinessItem(
      id: 'tickets',
      label: accessMode == EventAccessMode.publicTicketed
          ? 'At least one ticket tier'
          : 'Tickets (optional for private events)',
      done: accessMode != EventAccessMode.publicTicketed || ticketTiers.isNotEmpty,
      severity: accessMode == EventAccessMode.publicTicketed ? 'blocking' : 'info',
      actionLabel: 'Create tickets',
    ),
    EventReadinessItem(
      id: 'description',
      label: 'Description',
      done: description.trim().length >= 20,
      severity: 'warning',
      actionLabel: 'Add description',
    ),
    EventReadinessItem(
      id: 'branding',
      label: 'Cover / celebrant image',
      done: hasCelebrantBytes || (celebrantImageUrl != null && celebrantImageUrl.isNotEmpty),
      severity: 'warning',
      actionLabel: 'Add branding',
    ),
  ];

  final ready = items.where((i) => i.severity == 'blocking').every((i) => i.done);
  String next = 'publish';
  if (accessMode == EventAccessMode.publicTicketed && ticketTiers.isEmpty) {
    next = 'tickets';
  } else if (title.trim().isEmpty || !endsAt.isAfter(startsAt)) {
    next = 'details';
  } else if (!venueDeferred && venueName.trim().isEmpty && city.trim().isEmpty) {
    next = 'venue';
  } else if (description.trim().length < 20) {
    next = 'details';
  } else if (ready) {
    next = 'publish';
  }

  return EventPublishReadiness(items: items, readyToPublish: ready, nextBestActionId: next);
}
