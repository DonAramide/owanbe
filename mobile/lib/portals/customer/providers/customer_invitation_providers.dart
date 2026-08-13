import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/event_guests_api.dart';
import '../../../core/api/persistence_providers.dart';
import '../models/invitation_hub_models.dart';
import '../providers/customer_event_providers.dart';
import 'customer_guest_providers.dart';

final customerInvitationRefreshProvider = StateProvider<int>((ref) => 0);

void refreshInvitationHub(WidgetRef ref) {
  ref.read(customerInvitationRefreshProvider.notifier).state++;
}

/// Merged invitation status rows: every guest appears, with latest delivery when present.
List<InvitationRecord> mergeInvitationStatusRows(InvitationHubPayload hub) {
  final latestByGuest = <String, InvitationRecord>{};
  for (final item in hub.items) {
    if (item.guestId.isEmpty) continue;
    final prev = latestByGuest[item.guestId];
    if (prev == null) {
      latestByGuest[item.guestId] = item;
      continue;
    }
    final prevSent = prev.sentAt ?? '';
    final nextSent = item.sentAt ?? '';
    if (nextSent.compareTo(prevSent) >= 0) {
      latestByGuest[item.guestId] = item;
    }
  }

  if (hub.guests.isEmpty) {
    return hub.items;
  }

  return [
    for (final g in hub.guests)
      latestByGuest[g.id] ??
          InvitationRecord(
            id: '',
            guestId: g.id,
            guestName: g.name,
            guestEmail: g.email,
            channel: 'email',
            status: 'not_sent',
            deliveryStatus: 'not_sent',
            rsvpStatus: g.rsvpStatus,
            ticketIssued: g.ticketIssued,
            sentAt: null,
            respondedAt: g.respondedAt,
          ),
  ];
}

InvitationHubStats statsFromMergedRows(List<InvitationRecord> rows, InvitationHubStats api) {
  final awaiting = rows.where((r) {
    final s = (r.rsvpStatus ?? '').toLowerCase();
    return s.isEmpty || s == 'pending' || s == 'invited';
  }).length;
  final accepted = rows.where((r) => (r.rsvpStatus ?? '').toLowerCase() == 'confirmed').length;
  final declined = rows.where((r) => (r.rsvpStatus ?? '').toLowerCase() == 'declined').length;
  final tickets = rows.where((r) => r.ticketIssued).length;
  final sent = rows.where((r) => r.hasBeenSent).length;
  return InvitationHubStats(
    sent: api.sent > 0 ? api.sent : sent,
    delivered: api.delivered,
    opened: api.opened,
    rsvp: accepted,
    pending: awaiting,
    declined: declined,
    ticketsIssued: tickets,
    totalInvited: rows.length,
  );
}

final invitationHubPayloadProvider =
    FutureProvider.autoDispose.family<InvitationHubPayload, String>((ref, eventId) async {
  ref.watch(customerInvitationRefreshProvider);
  ref.watch(customerGuestRefreshProvider);
  return ref.read(eventGuestsApiProvider).fetchInvitationHub(eventId);
});

final invitationStatusRowsProvider =
    FutureProvider.autoDispose.family<({InvitationHubStats stats, List<InvitationRecord> rows}), String>(
        (ref, eventId) async {
  final hub = await ref.watch(invitationHubPayloadProvider(eventId).future);
  final rows = mergeInvitationStatusRows(hub);
  return (stats: statsFromMergedRows(rows, hub.stats), rows: rows);
});

final customerInvitationStatsProvider =
    FutureProvider.autoDispose.family<InvitationFunnelStats?, String>((ref, eventId) async {
  try {
    final hub = await ref.watch(invitationHubPayloadProvider(eventId).future);
    return InvitationFunnelStats(
      sent: hub.stats.sent,
      delivered: hub.stats.delivered,
      opened: hub.stats.opened,
      rsvp: hub.stats.rsvp,
    );
  } catch (_) {
    if (!allowMockPersistenceFallback()) rethrow;
    return null;
  }
});

final customerEventInvitationProvider =
    FutureProvider.autoDispose.family<InvitationHubSnapshot, String>((ref, eventId) async {
  ref.watch(customerInvitationRefreshProvider);
  ref.watch(customerGuestRefreshProvider);

  final event = await ref.watch(customerEventProvider(eventId).future);
  if (event == null) {
    throw StateError('Event not found');
  }

  final guests = await ref.watch(customerEventGuestsProvider(eventId).future);
  final apiStats = await ref.watch(customerInvitationStatsProvider(eventId).future);
  return buildInvitationHubSnapshot(event: event, guests: guests, apiStats: apiStats);
});
