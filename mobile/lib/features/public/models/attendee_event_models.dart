import '../models/public_models.dart';

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
  bool get checkedIn => ticket.checkedIn;

  bool get isUpcoming => startsAt.isAfter(DateTime.now().subtract(const Duration(hours: 6)));

  AttendeeEventView copyWith({AttendeeTicket? ticket}) => AttendeeEventView(
        ticket: ticket ?? this.ticket,
        tagline: tagline,
        description: description,
        endsAt: endsAt,
        category: category,
        coverGradientStart: coverGradientStart,
        coverGradientEnd: coverGradientEnd,
        attendeeCount: attendeeCount,
      );

  static AttendeeEventView fromTicket(AttendeeTicket ticket, PublicEvent? event) {
    if (event != null) {
      return AttendeeEventView(
        ticket: ticket,
        tagline: event.tagline,
        description: event.description,
        endsAt: event.endsAt,
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
      endsAt: ticket.startsAt.add(const Duration(hours: 6)),
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
  final now = DateTime.now();
  final upcoming = events.where((e) => e.startsAt.isAfter(now.subtract(const Duration(hours: 6)))).toList()
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
