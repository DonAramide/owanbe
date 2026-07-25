import '../models/public_models.dart';
import 'attendee_pass_status.dart';

enum AttendeeEventLifecycle {
  upcoming,
  ongoing,
  past,
  cancelled,
}

/// Full event view for an attendee — ticket plus public event details.
class AttendeeEventView {
  const AttendeeEventView({
    required this.ticket,
    required this.tagline,
    required this.description,
    required this.endsAt,
    required this.category,
    required this.coverGradientStart,
    required this.coverGradientEnd,
    this.attendeeCount,
  });

  final AttendeeTicket ticket;
  final String tagline;
  final String description;
  final DateTime endsAt;
  final String category;
  final int coverGradientStart;
  final int coverGradientEnd;
  final int? attendeeCount;

  String get eventId => ticket.eventId;
  String get eventTitle => ticket.eventTitle;
  String get tierName => ticket.tierName;
  String get venue => ticket.venue;
  String get city => ticket.city;
  DateTime get startsAt => ticket.startsAt;
  String get qrPayload => ticket.qrPayload;
  bool get checkedIn => ticket.checkedIn || ticket.status.toLowerCase() == 'checked_in';
  String get entitlementStatus => ticket.status;
  bool get isCancelled => ticket.isCancelled;
  String? get accessLevel => ticket.accessLevel;
  String? get seatLabel => ticket.seatLabel;
  String? get gateInfo => ticket.gateInfo;
  String? get entryInstructions => ticket.entryInstructions;
  String? get arrivalInstructions => ticket.arrivalInstructions;
  String? get venueAddress => ticket.venueAddress;
  String? get supportContactEmail => ticket.supportContactEmail;
  String? get supportContactPhone => ticket.supportContactPhone;
  String? get groupLabel => ticket.groupLabel;
  int get siblingCount => ticket.siblingCount;
  DateTime? get checkedInAt => ticket.checkedInAt;

  AttendeePassLiveStatus get liveStatus =>
      resolveAttendeePassLiveStatus(ticket, endsAt: endsAt);

  String get liveStatusLabel => liveStatus.label;

  bool get isOngoing {
    if (isCancelled) return false;
    final now = DateTime.now();
    return !now.isBefore(startsAt) && now.isBefore(endsAt);
  }

  bool get isUpcoming {
    if (isCancelled || isOngoing) return false;
    return startsAt.isAfter(DateTime.now());
  }

  bool get isPast {
    if (isCancelled || isOngoing || isUpcoming) return false;
    return true;
  }

  AttendeeEventLifecycle get lifecycle {
    if (isCancelled) return AttendeeEventLifecycle.cancelled;
    if (isOngoing) return AttendeeEventLifecycle.ongoing;
    if (isUpcoming) return AttendeeEventLifecycle.upcoming;
    return AttendeeEventLifecycle.past;
  }

  String get lifecycleLabel {
    switch (lifecycle) {
      case AttendeeEventLifecycle.upcoming:
        return 'Upcoming';
      case AttendeeEventLifecycle.ongoing:
        return 'Ongoing';
      case AttendeeEventLifecycle.past:
        return checkedIn ? 'Completed' : 'Past';
      case AttendeeEventLifecycle.cancelled:
        return entitlementStatus.toLowerCase() == 'refunded' ? 'Refunded' : 'Cancelled';
    }
  }

  AttendeeEventView copyWith({AttendeeTicket? ticket, DateTime? endsAt}) => AttendeeEventView(
        ticket: ticket ?? this.ticket,
        tagline: tagline,
        description: description,
        endsAt: endsAt ?? this.endsAt,
        category: category,
        coverGradientStart: coverGradientStart,
        coverGradientEnd: coverGradientEnd,
        attendeeCount: attendeeCount,
      );

  static AttendeeEventView fromTicket(AttendeeTicket ticket, PublicEvent? event) {
    if (event != null) {
      // Prefer entitlement accessLevel; fall back to matching public tier.
      final tierAccess = event.ticketTiers
          .where((t) => t.name.toLowerCase() == ticket.tierName.toLowerCase())
          .map((t) => t.accessLevel)
          .whereType<String>()
          .where((s) => s.trim().isNotEmpty)
          .firstOrNull;
      final enriched = ticket.accessLevel == null || ticket.accessLevel!.trim().isEmpty
          ? AttendeeTicket(
              id: ticket.id,
              eventId: ticket.eventId,
              eventTitle: ticket.eventTitle,
              tierName: ticket.tierName,
              venue: ticket.venue,
              city: ticket.city,
              startsAt: ticket.startsAt,
              qrPayload: ticket.qrPayload,
              purchasedAt: ticket.purchasedAt,
              checkedIn: ticket.checkedIn,
              status: ticket.status,
              endsAt: ticket.endsAt ?? event.endsAt,
              checkedInAt: ticket.checkedInAt,
              venueAddress: ticket.venueAddress ?? event.venueAddress,
              accessLevel: tierAccess,
              seatLabel: ticket.seatLabel,
              gateInfo: ticket.gateInfo,
              entryInstructions: ticket.entryInstructions,
              arrivalInstructions: ticket.arrivalInstructions,
              supportContactEmail: ticket.supportContactEmail ?? event.organizerContactEmail,
              supportContactPhone: ticket.supportContactPhone ?? event.organizerContactPhone,
              groupLabel: ticket.groupLabel,
              ticketOrderId: ticket.ticketOrderId,
              siblingCount: ticket.siblingCount,
              ticketCode: ticket.ticketCode,
            )
          : AttendeeTicket(
              id: ticket.id,
              eventId: ticket.eventId,
              eventTitle: ticket.eventTitle,
              tierName: ticket.tierName,
              venue: ticket.venue,
              city: ticket.city,
              startsAt: ticket.startsAt,
              qrPayload: ticket.qrPayload,
              purchasedAt: ticket.purchasedAt,
              checkedIn: ticket.checkedIn,
              status: ticket.status,
              endsAt: ticket.endsAt ?? event.endsAt,
              checkedInAt: ticket.checkedInAt,
              venueAddress: ticket.venueAddress ?? event.venueAddress,
              accessLevel: ticket.accessLevel,
              seatLabel: ticket.seatLabel,
              gateInfo: ticket.gateInfo,
              entryInstructions: ticket.entryInstructions,
              arrivalInstructions: ticket.arrivalInstructions,
              supportContactEmail: ticket.supportContactEmail ?? event.organizerContactEmail,
              supportContactPhone: ticket.supportContactPhone ?? event.organizerContactPhone,
              groupLabel: ticket.groupLabel,
              ticketOrderId: ticket.ticketOrderId,
              siblingCount: ticket.siblingCount,
              ticketCode: ticket.ticketCode,
            );

      return AttendeeEventView(
        ticket: enriched,
        tagline: event.tagline,
        description: event.description,
        endsAt: enriched.endsAt ?? event.endsAt,
        category: event.category,
        coverGradientStart: event.coverGradientStart,
        coverGradientEnd: event.coverGradientEnd,
        attendeeCount: event.attendeeCount,
      );
    }
    return AttendeeEventView(
      ticket: ticket,
      tagline: '',
      description: 'Join us for ${ticket.eventTitle} in ${ticket.city}.',
      endsAt: ticket.endsAt ?? ticket.startsAt.add(const Duration(hours: 6)),
      category: 'Celebration',
      coverGradientStart: 0xFF4B2C6F,
      coverGradientEnd: 0xFFD4A853,
    );
  }
}

class AttendeeDashboardStats {
  const AttendeeDashboardStats({
    required this.totalTickets,
    required this.upcoming,
    required this.checkedIn,
    required this.nextEvent,
  });

  final int totalTickets;
  final int upcoming;
  final int checkedIn;
  final AttendeeEventView? nextEvent;
}

AttendeeDashboardStats summarizeAttendeeEvents(List<AttendeeEventView> events) {
  final upcoming = events
      .where(
        (e) =>
            e.lifecycle == AttendeeEventLifecycle.upcoming ||
            e.lifecycle == AttendeeEventLifecycle.ongoing,
      )
      .toList()
    ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  return AttendeeDashboardStats(
    totalTickets: events.length,
    upcoming: upcoming.length,
    checkedIn: events.where((e) => e.checkedIn).length,
    nextEvent: upcoming.isEmpty ? null : upcoming.first,
  );
}

String formatAttendeeDateRange(DateTime start, DateTime end) {
  final date = '${_month(start.month)} ${start.day}, ${start.year}';
  final time =
      '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')} – ${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
  return '$date · $time';
}

String formatAttendeeDateTime(DateTime at) {
  return '${_month(at.month)} ${at.day}, ${at.year} · '
      '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
}

String _month(int m) => const [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ][m - 1];
