import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/auth_notifier.dart';
import '../../../portals/attendee/data/attendee_pass_cache.dart';
import '../../../portals/attendee/providers/attendee_pass_providers.dart';
import '../../../core/providers/silent_refresh.dart';
import '../models/attendee_event_models.dart';
import '../models/public_models.dart';
import '../providers/public_providers.dart';
import '../providers/ticket_commerce_providers.dart';

final attendeeTicketsSyncProvider = FutureProvider.autoDispose<List<AttendeeTicket>>((ref) async {
  final session = ref.watchSignedInUser();
  if (session == null) return ref.watch(attendeeTicketsProvider);

  final cache = ref.read(attendeePassCacheProvider);
  final userId = session.userId;

  try {
    final api = ref.read(ticketCommerceApiProvider);
    final remote = await api.fetchMyEntitlements(session);
    await cache.write(userId, remote);
    return remote.map(mapEntitlementToTicket).toList();
  } catch (_) {
    final cached = cache.read(userId);
    if (cached.isNotEmpty) {
      return cached.map(mapEntitlementToTicket).toList();
    }
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
@Deprecated('Removed in v1.0.1 — use ticket entitlements API')
void seedDemoAttendeeTicketsIfEmpty(WidgetRef ref) {}
