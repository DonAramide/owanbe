import '../../../features/organizer/models/organizer_models.dart';
import 'customer_guest_models.dart';
import 'home_hub_models.dart';

class InvitationFunnelStats {
  const InvitationFunnelStats({
    required this.sent,
    required this.delivered,
    required this.opened,
    required this.rsvp,
  });

  final int sent;
  final int delivered;
  final int opened;
  final int rsvp;

  double get deliveryRate => sent == 0 ? 0 : delivered / sent;
  double get openRate => delivered == 0 ? 0 : opened / delivered;
  double get rsvpRate => opened == 0 ? 0 : rsvp / opened;
}

class InvitationShareTargets {
  const InvitationShareTargets({
    required this.eventPageUrl,
    required this.rsvpPageUrl,
    required this.inviteQrPayload,
    required this.rsvpQrPayload,
    required this.whatsappMessage,
    required this.emailSubject,
    required this.emailBody,
  });

  final String eventPageUrl;
  final String rsvpPageUrl;
  final String inviteQrPayload;
  final String rsvpQrPayload;
  final String whatsappMessage;
  final String emailSubject;
  final String emailBody;
}

class InvitationHubSnapshot {
  const InvitationHubSnapshot({
    required this.event,
    required this.stats,
    required this.share,
    required this.guestCount,
  });

  final OrganizerEvent event;
  final InvitationFunnelStats stats;
  final InvitationShareTargets share;
  final int guestCount;
}

InvitationFunnelStats buildInvitationStats(List<CustomerGuestView> guests) {
  final sent = guests.length;
  final delivered = guests.where((g) => g.email.isNotEmpty || g.ticketId.isNotEmpty).length;
  final opened = guests
      .where(
        (g) =>
            g.ticketId.isNotEmpty ||
            g.rsvpStatus == GuestRsvpStatus.confirmed ||
            g.checkedIn,
      )
      .length;
  final rsvp = guests.where((g) => g.rsvpStatus == GuestRsvpStatus.confirmed).length;

  return InvitationFunnelStats(
    sent: sent,
    delivered: delivered > 0 ? delivered : sent,
    opened: opened > 0 ? opened : (delivered * 0.85).round(),
    rsvp: rsvp,
  );
}

InvitationShareTargets buildShareTargets(OrganizerEvent event) {
  final eventId = event.id;
  final eventPage = 'https://app.owanbe.com/events/$eventId';
  final rsvpPage = 'https://app.owanbe.com/events/$eventId/tickets';
  final dateLine = formatEventDate(event.startsAt);
  final invitePayload = 'OWANBE:EVENT:$eventId:INVITE';
  final rsvpPayload = 'OWANBE:EVENT:$eventId:RSVP';

  final message = "You're invited to ${event.title}!\n"
      '$dateLine · ${event.venue}, ${event.city}\n'
      'RSVP: $rsvpPage';

  return InvitationShareTargets(
    eventPageUrl: eventPage,
    rsvpPageUrl: rsvpPage,
    inviteQrPayload: invitePayload,
    rsvpQrPayload: rsvpPayload,
    whatsappMessage: message,
    emailSubject: "You're invited — ${event.title}",
    emailBody: '$message\n\nView celebration: $eventPage',
  );
}

InvitationHubSnapshot buildInvitationHubSnapshot({
  required OrganizerEvent event,
  required List<CustomerGuestView> guests,
  InvitationFunnelStats? apiStats,
}) {
  return InvitationHubSnapshot(
    event: event,
    stats: apiStats ?? buildInvitationStats(guests),
    share: buildShareTargets(event),
    guestCount: guests.length,
  );
}
