import 'attendee_event_models.dart';
import 'public_models.dart';

/// Live admission status for an attendee digital pass (Phase 6A).
enum AttendeePassLiveStatus {
  registered,
  readyForEntry,
  checkedIn,
  insideEvent,
  completed,
  cancelled,
  expired,
  refunded,
}

extension AttendeePassLiveStatusX on AttendeePassLiveStatus {
  String get label {
    switch (this) {
      case AttendeePassLiveStatus.registered:
        return 'Registered';
      case AttendeePassLiveStatus.readyForEntry:
        return 'Ready for Entry';
      case AttendeePassLiveStatus.checkedIn:
        return 'Checked In';
      case AttendeePassLiveStatus.insideEvent:
        return 'Inside Event';
      case AttendeePassLiveStatus.completed:
        return 'Completed';
      case AttendeePassLiveStatus.cancelled:
        return 'Cancelled';
      case AttendeePassLiveStatus.expired:
        return 'Expired';
      case AttendeePassLiveStatus.refunded:
        return 'Refunded';
    }
  }

  String get description {
    switch (this) {
      case AttendeePassLiveStatus.registered:
        return 'Your ticket is registered. Present your QR at the gate when the event opens.';
      case AttendeePassLiveStatus.readyForEntry:
        return 'You are eligible for entry. Show this pass to event staff.';
      case AttendeePassLiveStatus.checkedIn:
        return 'Staff have validated your ticket.';
      case AttendeePassLiveStatus.insideEvent:
        return 'You are checked in and the event is in progress.';
      case AttendeePassLiveStatus.completed:
        return 'This event has ended and your attendance was recorded.';
      case AttendeePassLiveStatus.cancelled:
        return 'This ticket was cancelled and is no longer valid for entry.';
      case AttendeePassLiveStatus.expired:
        return 'This pass was not used before the event ended.';
      case AttendeePassLiveStatus.refunded:
        return 'This ticket was refunded and is no longer valid.';
    }
  }

  bool get allowsEntry =>
      this == AttendeePassLiveStatus.readyForEntry ||
      this == AttendeePassLiveStatus.registered;

  bool get isCheckedInState =>
      this == AttendeePassLiveStatus.checkedIn ||
      this == AttendeePassLiveStatus.insideEvent ||
      this == AttendeePassLiveStatus.completed;
}

AttendeePassLiveStatus resolveAttendeePassLiveStatus(
  AttendeeTicket ticket, {
  DateTime? endsAt,
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  final status = ticket.status.toLowerCase();
  final end = endsAt ?? ticket.endsAt ?? ticket.startsAt.add(const Duration(hours: 6));

  if (status == 'refunded') return AttendeePassLiveStatus.refunded;
  if (status == 'voided') return AttendeePassLiveStatus.cancelled;

  final checkedIn = ticket.checkedIn || status == 'checked_in';
  if (checkedIn) {
    if (clock.isAfter(end)) return AttendeePassLiveStatus.completed;
    if (!clock.isBefore(ticket.startsAt) && clock.isBefore(end)) {
      return AttendeePassLiveStatus.insideEvent;
    }
    return AttendeePassLiveStatus.checkedIn;
  }

  if (clock.isAfter(end)) return AttendeePassLiveStatus.expired;

  // Entry window: day of event or within 4 hours before start through end.
  final entryOpens = ticket.startsAt.subtract(const Duration(hours: 4));
  if (!clock.isBefore(entryOpens) && clock.isBefore(end)) {
    return AttendeePassLiveStatus.readyForEntry;
  }

  return AttendeePassLiveStatus.registered;
}

AttendeePassLiveStatus resolveViewPassLiveStatus(AttendeeEventView view, {DateTime? now}) {
  return resolveAttendeePassLiveStatus(view.ticket, endsAt: view.endsAt, now: now);
}

class AttendeeAttendanceTimelineItem {
  const AttendeeAttendanceTimelineItem({
    required this.title,
    required this.subtitle,
    required this.at,
    required this.kind,
  });

  final String title;
  final String subtitle;
  final DateTime at;
  final String kind;
}

List<AttendeeAttendanceTimelineItem> buildAttendanceTimeline(AttendeeEventView view) {
  final items = <AttendeeAttendanceTimelineItem>[
    AttendeeAttendanceTimelineItem(
      title: 'Registered',
      subtitle: 'Ticket issued · ${view.tierName}',
      at: view.ticket.purchasedAt,
      kind: 'registered',
    ),
  ];
  final checkedInAt = view.ticket.checkedInAt;
  if (view.checkedIn && checkedInAt != null) {
    items.add(
      AttendeeAttendanceTimelineItem(
        title: 'Checked in',
        subtitle: 'Validated by event staff',
        at: checkedInAt,
        kind: 'checked_in',
      ),
    );
  } else if (view.checkedIn) {
    items.add(
      AttendeeAttendanceTimelineItem(
        title: 'Checked in',
        subtitle: 'Validated by event staff',
        at: view.startsAt,
        kind: 'checked_in',
      ),
    );
  }
  if (view.isPast) {
    items.add(
      AttendeeAttendanceTimelineItem(
        title: view.checkedIn ? 'Event completed' : 'Event ended',
        subtitle: view.checkedIn ? 'Attendance recorded' : 'Pass closed',
        at: view.endsAt,
        kind: 'completed',
      ),
    );
  }
  items.sort((a, b) => a.at.compareTo(b.at));
  return items;
}
