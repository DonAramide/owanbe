import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/events_api.dart';
import '../../../core/api/persistence_providers.dart';
import '../data/organizer_event_store.dart';
import '../models/organizer_models.dart';

final organizerStoreProvider = Provider<OrganizerEventStore>((ref) => OrganizerEventStore.instance);

final organizerShellTabProvider = NotifierProvider<OrganizerShellTabController, int>(
  OrganizerShellTabController.new,
);

class OrganizerShellTabController extends Notifier<int> {
  @override
  int build() => 0;
  void select(int tab) => state = tab;
}

final eventWorkspaceTabProvider = StateProvider<int>((ref) => 0);

final selectedOrganizerEventIdProvider = StateProvider<String?>((ref) => null);

final attendeeSearchQueryProvider = StateProvider<String>((ref) => '');

final organizerEventsProvider = FutureProvider.autoDispose<List<OrganizerEvent>>((ref) async {
  ref.watch(organizerRevisionProvider);
  try {
    return await ref.read(eventsApiProvider).listOrganizerEvents();
  } catch (e) {
    if (!allowMockPersistenceFallback()) rethrow;
    return ref.read(organizerStoreProvider).all;
  }
});

final organizerEventProvider = FutureProvider.autoDispose.family<OrganizerEvent?, String>((ref, id) async {
  ref.watch(organizerRevisionProvider);
  try {
    return await ref.read(eventsApiProvider).getOrganizerEvent(id);
  } catch (e) {
    if (!allowMockPersistenceFallback()) rethrow;
    return ref.read(organizerStoreProvider).byId(id);
  }
});

final organizerAnalyticsProvider =
    FutureProvider.autoDispose.family<EventAnalyticsSnapshot, String>((ref, eventId) async {
  ref.watch(organizerRevisionProvider);
  final event = await ref.watch(organizerEventProvider(eventId).future);
  if (event == null) {
    return EventAnalyticsSnapshot(
      eventId: eventId,
      pageViews: 0,
      ticketsSold: 0,
      revenueMinor: 0,
      checkInRate: 0,
      registrations: 0,
      checkIns: 0,
      noShows: 0,
      dailySales: const [0, 0, 0, 0, 0, 0, 0],
      weeklySales: const [0, 0, 0, 0],
      monthlySales: const [0, 0, 0],
      salesTrend: const [0, 0, 0, 0, 0, 0, 0],
      tierBreakdown: const {},
      tierTypeBreakdown: const {},
    );
  }
  if (allowMockPersistenceFallback()) {
    try {
      return ref.read(organizerStoreProvider).analyticsFor(eventId);
    } catch (_) {}
  }
  final sold = event.ticketsSold;
  final checkIn = event.attendees.isEmpty ? 0.0 : event.checkedInCount / event.attendees.length;
  final breakdown = {for (final t in event.ticketTiers) t.name: t.capacity - t.remaining};
  final typeBreakdown = <TicketTierType, int>{};
  for (final t in event.ticketTiers) {
    typeBreakdown[t.tierType] = (typeBreakdown[t.tierType] ?? 0) + (t.capacity - t.remaining);
  }
  final trend = List.generate(7, (i) => sold == 0 ? 0.0 : sold / 7 * (i + 1));
  return EventAnalyticsSnapshot(
    eventId: eventId,
    pageViews: sold * 3,
    ticketsSold: sold,
    revenueMinor: event.revenueMinor,
    checkInRate: checkIn,
    registrations: event.attendees.length,
    checkIns: event.checkedInCount,
    noShows: event.noShowCount,
    dailySales: trend,
    weeklySales: [trend[1], trend[3], trend[5], trend[6]],
    monthlySales: [sold * 0.4, sold * 0.7, sold.toDouble()],
    salesTrend: trend,
    tierBreakdown: breakdown,
    tierTypeBreakdown: typeBreakdown,
  );
});

final organizerAttentionProvider = FutureProvider.autoDispose<List<OrganizerAttentionItem>>((ref) async {
  ref.watch(organizerRevisionProvider);
  try {
    final events = await ref.read(organizerEventsProvider.future);
    final items = <OrganizerAttentionItem>[];
    for (final e in events) {
      if (e.status == OrganizerEventStatus.draft) {
        items.add(OrganizerAttentionItem(
          type: OrganizerAttentionType.unpublishedDraft,
          headline: 'Unpublished draft',
          message: '${e.title} is ready to publish',
          eventId: e.id,
          severity: 'INFO',
        ));
      }
      if (e.status == OrganizerEventStatus.published && e.sellThroughRate < 0.15 && e.totalCapacity > 0) {
        items.add(OrganizerAttentionItem(
          type: OrganizerAttentionType.lowTicketSales,
          headline: 'Low ticket sales',
          message: '${e.title} · ${(e.sellThroughRate * 100).toStringAsFixed(0)}% sold',
          eventId: e.id,
        ));
      }
    }
    return items;
  } catch (e) {
    if (!allowMockPersistenceFallback()) rethrow;
    return ref.read(organizerStoreProvider).attentionItems();
  }
});

final organizerRevisionProvider = StateProvider<int>((ref) => 0);

void bumpOrganizerRevision(WidgetRef ref) {
  ref.read(organizerRevisionProvider.notifier).state++;
}

final eventWizardDraftProvider = StateProvider<EventWizardDraft>((ref) => EventWizardDraft());

final organizerDashboardStatsProvider = FutureProvider.autoDispose<OrganizerDashboardStats>((ref) async {
  ref.watch(organizerRevisionProvider);
  try {
    final stats = await ref.read(eventsApiProvider).fetchDashboard();
    return OrganizerDashboardStats(
      activeEvents: (stats['activeEvents'] as num?)?.toInt() ?? 0,
      upcomingEvents: (stats['upcomingEvents'] as num?)?.toInt() ?? 0,
      ticketsSold: (stats['ticketsSold'] as num?)?.toInt() ?? 0,
      revenueMinor: int.tryParse((stats['revenueMinor'] ?? '0').toString()) ?? 0,
      vendorCount: (stats['vendorCount'] as num?)?.toInt() ?? 0,
      attendeeCount: (stats['attendeeCount'] as num?)?.toInt() ?? 0,
    );
  } catch (e) {
    if (!allowMockPersistenceFallback()) rethrow;
    final events = ref.read(organizerStoreProvider).all;
    final active = events
        .where((e) => e.status == OrganizerEventStatus.published || e.status == OrganizerEventStatus.live)
        .length;
    final upcoming = events.where((e) => e.isUpcoming).length;
    final revenue = events.fold(0, (sum, e) => sum + e.revenueMinor);
    final sold = events.fold(0, (sum, e) => sum + e.ticketsSold);
    final vendors = events.fold(0, (sum, e) => sum + e.vendors.length);
    final attendees = events.fold(0, (sum, e) => sum + e.attendees.length);
    return OrganizerDashboardStats(
      activeEvents: active,
      upcomingEvents: upcoming,
      ticketsSold: sold,
      revenueMinor: revenue,
      vendorCount: vendors,
      attendeeCount: attendees,
    );
  }
});

class OrganizerDashboardStats {
  const OrganizerDashboardStats({
    required this.activeEvents,
    required this.upcomingEvents,
    required this.ticketsSold,
    required this.revenueMinor,
    required this.vendorCount,
    required this.attendeeCount,
  });

  final int activeEvents;
  final int upcomingEvents;
  final int ticketsSold;
  final int revenueMinor;
  final int vendorCount;
  final int attendeeCount;
}
