import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/auth_notifier.dart';
import '../../organizer/data/organizer_event_store.dart';
import '../models/attendee_event_models.dart';
import '../models/public_models.dart';
import '../providers/public_providers.dart';
import '../providers/ticket_commerce_providers.dart';

final attendeeTicketsSyncProvider = FutureProvider.autoDispose<List<AttendeeTicket>>((ref) async {
  final session = ref.watch(authSessionProvider);
  if (session == null) return ref.watch(attendeeTicketsProvider);

  try {
    final api = ref.read(ticketCommerceApiProvider);
    final remote = await api.fetchMyEntitlements(session);
    return remote
        .map(
          (e) => AttendeeTicket(
            id: e.id,
            eventId: e.eventId,
            eventTitle: e.eventTitle,
            tierName: e.tierName,
            venue: e.eventVenue,
            city: e.eventCity,
            startsAt: e.startsAt,
            qrPayload: e.qrPayload,
            purchasedAt: e.issuedAt ?? DateTime.now(),
          ),
        )
        .toList();
  } catch (_) {
    return ref.watch(attendeeTicketsProvider);
  }
});

final attendeeEventsProvider = FutureProvider.autoDispose<List<AttendeeEventView>>((ref) async {
  final tickets = await ref.watch(attendeeTicketsSyncProvider.future);
  final views = <AttendeeEventView>[];

  for (final ticket in tickets) {
    PublicEvent? event;
    try {
      event = await ref.read(publicEventProvider(ticket.eventId).future);
    } catch (_) {
      event = null;
    }
    views.add(AttendeeEventView.fromTicket(ticket, event));
  }

  views.sort((a, b) => a.startsAt.compareTo(b.startsAt));
  return views;
});

final attendeeDashboardStatsProvider = Provider.autoDispose<AsyncValue<AttendeeDashboardStats>>((ref) {
  return ref.watch(attendeeEventsProvider).whenData(summarizeAttendeeEvents);
});

final attendeeHasTicketProvider = Provider.autoDispose.family<bool, String>((ref, eventId) {
  final tickets = ref.watch(attendeeTicketsSyncProvider);
  return tickets.when(
    data: (list) => list.any((t) => t.eventId == eventId),
    loading: () => ref.watch(attendeeTicketsProvider).any((t) => t.eventId == eventId),
    error: (_, _) => ref.watch(attendeeTicketsProvider).any((t) => t.eventId == eventId),
  );
});

/// Demo tickets when API returns empty (development).
void seedDemoAttendeeTicketsIfEmpty(WidgetRef ref) {
  if (ref.read(attendeeTicketsProvider).isNotEmpty) return;

  final published = OrganizerEventStore.instance.publishedForPublic();
  if (published.isEmpty) return;

  final event = published.first;
  ref.read(attendeeTicketsProvider.notifier).addAll([
    AttendeeTicket(
      id: 'demo_ticket_${event.id}',
      eventId: event.id,
      eventTitle: event.title,
      tierName: event.ticketTiers.isNotEmpty ? event.ticketTiers.first.name : 'General Admission',
      venue: event.venue,
      city: event.city,
      startsAt: event.startsAt,
      qrPayload: 'OWANBE:${event.id}:DEMO',
      purchasedAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
  ]);
}
