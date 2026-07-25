import '../../../core/api/vendors_api.dart';
import 'customer_event_models.dart';
export 'customer_event_models.dart';

/// Aggregated snapshot for CUS-020 Home Hub.
class CustomerHomeSnapshot {
  const CustomerHomeSnapshot({
    required this.activeEvents,
    required this.nearestEvent,
    required this.invitations,
    required this.vendors,
  });

  final List<CustomerEventSummary> activeEvents;
  final CustomerEventSummary? nearestEvent;
  final List<CustomerInvitationCard> invitations;
  final List<MarketplaceVendor> vendors;
}

/// Organizer portal home — planning and vendor discovery only.
class OrganizerHomeSnapshot {
  const OrganizerHomeSnapshot({
    required this.activeEvents,
    required this.nearestEvent,
    required this.vendors,
  });

  final List<CustomerEventSummary> activeEvents;
  final CustomerEventSummary? nearestEvent;
  final List<MarketplaceVendor> vendors;
}

/// Attendee portal home — invitations and tickets only.
class AttendeeHomeSnapshot {
  const AttendeeHomeSnapshot({
    required this.invitations,
  });

  final List<CustomerInvitationCard> invitations;

  CustomerInvitationCard? get nearestInvitation {
    if (invitations.isEmpty) return null;
    return invitations.first;
  }
}

class CustomerInvitationCard {
  const CustomerInvitationCard({
    required this.id,
    required this.eventTitle,
    required this.eventId,
    required this.startsAt,
    required this.venue,
    required this.city,
    required this.kind,
  });

  final String id;
  final String eventTitle;
  final String eventId;
  final DateTime startsAt;
  final String venue;
  final String city;
  final CustomerInvitationKind kind;
}

enum CustomerInvitationKind { ticket, rsvp }

String homeGreeting(DateTime now) {
  final hour = now.hour;
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}

String formatCountdown(DateTime target, DateTime now) {
  final diff = target.difference(now);
  if (diff.isNegative) return 'Happening now';
  final days = diff.inDays;
  if (days > 0) return '$days day${days == 1 ? '' : 's'} to go';
  final hours = diff.inHours;
  if (hours > 0) return '$hours hour${hours == 1 ? '' : 's'} to go';
  final minutes = diff.inMinutes;
  return '$minutes min to go';
}

String formatEventDate(DateTime date) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}
