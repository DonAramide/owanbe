import '../../../features/operations/models/operations_models.dart';
import '../../../features/organizer/models/organizer_models.dart';

enum GuestRsvpStatus { confirmed, pending, declined }

enum CustomerGuestFilter {
  all,
  rsvpConfirmed,
  rsvpPending,
  checkedIn,
  notCheckedIn,
  vip,
  vvip,
}

extension GuestRsvpStatusX on GuestRsvpStatus {
  String get label => switch (this) {
        GuestRsvpStatus.confirmed => 'RSVP Yes',
        GuestRsvpStatus.pending => 'Pending',
        GuestRsvpStatus.declined => 'Declined',
      };
}

extension CustomerGuestFilterX on CustomerGuestFilter {
  String get label => switch (this) {
        CustomerGuestFilter.all => 'All',
        CustomerGuestFilter.rsvpConfirmed => 'RSVP Yes',
        CustomerGuestFilter.rsvpPending => 'Pending',
        CustomerGuestFilter.checkedIn => 'Checked in',
        CustomerGuestFilter.notCheckedIn => 'Not checked in',
        CustomerGuestFilter.vip => 'VIP',
        CustomerGuestFilter.vvip => 'VVIP',
      };
}

class CustomerGuestView {
  const CustomerGuestView({
    required this.id,
    required this.name,
    required this.email,
    required this.ticketId,
    required this.tierName,
    required this.tier,
    required this.checkedIn,
    required this.rsvpStatus,
    this.checkedInAt,
    this.purchasedAt,
    this.timeline = const [],
  });

  final String id;
  final String name;
  final String email;
  final String ticketId;
  final String tierName;
  final GuestTier tier;
  final bool checkedIn;
  final GuestRsvpStatus rsvpStatus;
  final DateTime? checkedInAt;
  final DateTime? purchasedAt;
  final List<AttendeeTimelineEvent> timeline;

  OpsGuest toOpsGuest() => OpsGuest(
        id: id,
        name: name,
        email: email,
        ticketId: ticketId,
        tierName: tierName,
        tier: tier,
        checkedIn: checkedIn,
        checkedInAt: checkedInAt,
      );
}

GuestRsvpStatus deriveRsvpStatus({
  required bool hasTicket,
  DateTime? purchasedAt,
  bool declined = false,
}) {
  if (declined) return GuestRsvpStatus.declined;
  if (purchasedAt != null || hasTicket) return GuestRsvpStatus.confirmed;
  return GuestRsvpStatus.pending;
}

CustomerGuestView guestFromOps(OpsGuest guest, OrganizerAttendee? attendee) {
  return CustomerGuestView(
    id: guest.id,
    name: guest.name,
    email: guest.email.isNotEmpty ? guest.email : (attendee?.email ?? ''),
    ticketId: guest.ticketId,
    tierName: guest.tierName,
    tier: guest.tier,
    checkedIn: guest.checkedIn,
    checkedInAt: guest.checkedInAt,
    purchasedAt: attendee?.purchasedAt,
    rsvpStatus: deriveRsvpStatus(
      hasTicket: guest.ticketId.isNotEmpty,
      purchasedAt: attendee?.purchasedAt,
    ),
    timeline: attendee?.timeline ?? const [],
  );
}

CustomerGuestView guestFromAttendee(OrganizerAttendee attendee) {
  final tier = attendee.tierName.toLowerCase().contains('vvip')
      ? GuestTier.vvip
      : attendee.tierName.toLowerCase().contains('vip')
          ? GuestTier.vip
          : GuestTier.general;
  return CustomerGuestView(
    id: attendee.id,
    name: attendee.name,
    email: attendee.email,
    ticketId: attendee.ticketId,
    tierName: attendee.tierName,
    tier: tier,
    checkedIn: attendee.checkedIn,
    purchasedAt: attendee.purchasedAt,
    rsvpStatus: deriveRsvpStatus(
      hasTicket: attendee.ticketId.isNotEmpty,
      purchasedAt: attendee.purchasedAt,
    ),
    timeline: attendee.timeline,
  );
}

List<CustomerGuestView> mergeGuestViews({
  required List<OpsGuest> opsGuests,
  required List<OrganizerAttendee> attendees,
}) {
  final attendeeById = {for (final a in attendees) a.id: a};
  final attendeeByTicket = {
    for (final a in attendees)
      if (a.ticketId.isNotEmpty) a.ticketId: a,
  };

  final views = <CustomerGuestView>[];
  final seen = <String>{};

  for (final guest in opsGuests) {
    final attendee = attendeeById[guest.id] ?? attendeeByTicket[guest.ticketId];
    views.add(guestFromOps(guest, attendee));
    seen.add(guest.id);
    if (guest.ticketId.isNotEmpty) seen.add(guest.ticketId);
  }

  for (final attendee in attendees) {
    if (seen.contains(attendee.id) ||
        (attendee.ticketId.isNotEmpty && seen.contains(attendee.ticketId))) {
      continue;
    }
    views.add(guestFromAttendee(attendee));
  }

  views.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return views;
}

List<CustomerGuestView> filterCustomerGuests(
  List<CustomerGuestView> guests,
  CustomerGuestFilter filter,
) {
  return switch (filter) {
    CustomerGuestFilter.all => guests,
    CustomerGuestFilter.rsvpConfirmed =>
      guests.where((g) => g.rsvpStatus == GuestRsvpStatus.confirmed).toList(),
    CustomerGuestFilter.rsvpPending =>
      guests.where((g) => g.rsvpStatus == GuestRsvpStatus.pending).toList(),
    CustomerGuestFilter.checkedIn => guests.where((g) => g.checkedIn).toList(),
    CustomerGuestFilter.notCheckedIn => guests.where((g) => !g.checkedIn).toList(),
    CustomerGuestFilter.vip => guests.where((g) => g.tier == GuestTier.vip).toList(),
    CustomerGuestFilter.vvip => guests.where((g) => g.tier == GuestTier.vvip).toList(),
  };
}

List<CustomerGuestView> searchCustomerGuests(List<CustomerGuestView> guests, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return guests;
  return guests
      .where(
        (g) =>
            g.name.toLowerCase().contains(q) ||
            g.email.toLowerCase().contains(q) ||
            g.ticketId.toLowerCase().contains(q),
      )
      .toList();
}

class CustomerGuestSummary {
  const CustomerGuestSummary({
    required this.total,
    required this.rsvpConfirmed,
    required this.checkedIn,
  });

  final int total;
  final int rsvpConfirmed;
  final int checkedIn;
}

CustomerGuestSummary summarizeGuests(List<CustomerGuestView> guests) {
  return CustomerGuestSummary(
    total: guests.length,
    rsvpConfirmed: guests.where((g) => g.rsvpStatus == GuestRsvpStatus.confirmed).length,
    checkedIn: guests.where((g) => g.checkedIn).length,
  );
}

const mockImportContacts = <({String name, String email})>[
  (name: 'Amaka Okafor', email: 'amaka@example.com'),
  (name: 'Tunde Bakare', email: 'tunde@example.com'),
  (name: 'Chioma Eze', email: 'chioma@example.com'),
  (name: 'Ibrahim Musa', email: 'ibrahim@example.com'),
  (name: 'Ngozi Adeleke', email: 'ngozi@example.com'),
];
