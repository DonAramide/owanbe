import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/ticket_commerce_api.dart';
import '../../../features/public/models/attendee_event_models.dart';
import '../../../features/public/models/public_models.dart';
import '../../../features/public/providers/attendee_events_provider.dart';

AttendeeTicket mapEntitlementToTicket(TicketEntitlementResponse e) {
  final status = (e.status ?? 'issued').toLowerCase();
  return AttendeeTicket(
    id: e.id,
    eventId: e.eventId,
    eventTitle: e.eventTitle,
    tierName: e.tierName,
    venue: e.eventVenue,
    city: e.eventCity,
    startsAt: e.startsAt,
    qrPayload: e.qrPayload,
    purchasedAt: e.issuedAt ?? DateTime.now(),
    checkedIn: status == 'checked_in',
    status: status,
    endsAt: e.endsAt,
    checkedInAt: e.checkedInAt,
    venueAddress: e.venueAddress,
    accessLevel: e.accessLevel,
    seatLabel: e.seatLabel,
    gateInfo: e.gateInfo,
    entryInstructions: e.entryInstructions,
    arrivalInstructions: e.arrivalInstructions,
    supportContactEmail: e.supportContactEmail,
    supportContactPhone: e.supportContactPhone,
    groupLabel: e.groupLabel,
    ticketOrderId: e.ticketOrderId,
    siblingCount: e.siblingCount,
    ticketCode: e.ticketCode,
  );
}

/// Selected pass for multi-ticket switcher (ticket entitlement id).
final selectedPassTicketIdProvider = StateProvider<String?>((ref) => null);

/// When true, entitlements poll so check-in flips without manual refresh.
final attendeePassLiveWatchProvider = StateProvider<bool>((ref) => false);

/// Polls entitlements while an entry/pass detail screen is open.
final attendeePassLiveSyncProvider = Provider.autoDispose<void>((ref) {
  final watching = ref.watch(attendeePassLiveWatchProvider);
  if (!watching) return;

  final timer = Timer.periodic(const Duration(seconds: 8), (_) {
    ref.invalidate(attendeeTicketsSyncProvider);
  });
  ref.onDispose(timer.cancel);
});

final attendeePassByIdProvider =
    Provider.autoDispose.family<AsyncValue<AttendeeEventView?>, String>((ref, ticketId) {
  return ref.watch(attendeeEventsProvider).whenData((events) {
    for (final e in events) {
      if (e.ticket.id == ticketId) return e;
    }
    return null;
  });
});

final attendeePassesForEventProvider =
    Provider.autoDispose.family<AsyncValue<List<AttendeeEventView>>, String>((ref, eventId) {
  return ref.watch(attendeeEventsProvider).whenData(
        (events) => events.where((e) => e.eventId == eventId).toList(),
      );
});

/// Sibling passes for the same event (family / group / multi-ticket).
List<AttendeeEventView> siblingPassesFor(List<AttendeeEventView> all, AttendeeEventView current) {
  return all.where((e) => e.eventId == current.eventId).toList()
    ..sort((a, b) => a.ticket.purchasedAt.compareTo(b.ticket.purchasedAt));
}

String passSwitcherLabel(AttendeeEventView pass, int index, int total) {
  final group = pass.groupLabel?.trim();
  if (group != null && group.isNotEmpty) return '$group · ${index + 1}/$total';
  if (total <= 1) return pass.tierName;
  return '${pass.tierName} · ${index + 1}/$total';
}
