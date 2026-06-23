import '../../../features/organizer/models/organizer_models.dart';
import '../../../core/api/vendors_api.dart';

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

class CustomerEventSummary {
  const CustomerEventSummary({
    required this.id,
    required this.title,
    required this.startsAt,
    required this.city,
    required this.venue,
    required this.status,
    required this.guestCount,
    required this.progress,
    required this.coverGradientStart,
    required this.coverGradientEnd,
    required this.isLive,
  });

  final String id;
  final String title;
  final DateTime startsAt;
  final String city;
  final String venue;
  final OrganizerEventStatus status;
  final int guestCount;
  final double progress;
  final int coverGradientStart;
  final int coverGradientEnd;
  final bool isLive;

  factory CustomerEventSummary.fromOrganizerEvent(OrganizerEvent event) {
    return CustomerEventSummary(
      id: event.id,
      title: event.title,
      startsAt: event.startsAt,
      city: event.city,
      venue: event.venue,
      status: event.status,
      guestCount: event.attendees.length,
      progress: computePlanningProgress(event),
      coverGradientStart: event.coverGradientStart,
      coverGradientEnd: event.coverGradientEnd,
      isLive: event.status == OrganizerEventStatus.live,
    );
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

/// Planning completion estimate (0–1) from event setup signals.
double computePlanningProgress(OrganizerEvent event) {
  var score = 0.0;
  if (event.title.trim().isNotEmpty) score += 0.12;
  if (event.description.trim().isNotEmpty) score += 0.08;
  if (event.attendees.isNotEmpty) score += 0.22;
  if (event.vendors.isNotEmpty) score += 0.18;
  if (event.ticketTiers.isNotEmpty) score += 0.15;
  if (event.status == OrganizerEventStatus.published ||
      event.status == OrganizerEventStatus.live ||
      event.status == OrganizerEventStatus.completed) {
    score += 0.25;
  }
  return score.clamp(0.0, 1.0);
}

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
