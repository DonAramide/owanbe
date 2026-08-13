@Deprecated(
  'Migrate to Customer Event OS providers in portals/customer/providers/customer_event_providers.dart.',
)
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/persistence_providers.dart';
import '../data/organizer_event_store.dart';
import '../models/organizer_models.dart';

export '../analytics/organizer_analytics_api.dart' show EventAnalyticsSnapshot;
export '../analytics/organizer_analytics_providers.dart'
    show
        organizerAnalyticsProvider,
        organizerAnalyticsDaysProvider,
        organizerAnalyticsPortfolioProvider,
        invalidateEventAnalytics;

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
      draftEvents: (stats['draftEvents'] as num?)?.toInt() ?? 0,
      liveEvents: (stats['liveEvents'] as num?)?.toInt() ?? 0,
      completedEvents: (stats['completedEvents'] as num?)?.toInt() ?? 0,
      ticketsSold: (stats['ticketsSold'] as num?)?.toInt() ?? 0,
      revenueMinor: int.tryParse((stats['revenueMinor'] ?? '0').toString()) ?? 0,
      vendorCount: (stats['vendorCount'] as num?)?.toInt() ?? 0,
      attendeeCount: (stats['attendeeCount'] as num?)?.toInt() ?? 0,
      registrations: (stats['registrations'] as num?)?.toInt() ?? (stats['attendeeCount'] as num?)?.toInt() ?? 0,
      checkIns: (stats['checkIns'] as num?)?.toInt() ?? 0,
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
    final draft = events.where((e) => e.status == OrganizerEventStatus.draft).length;
    final live = events.where((e) => e.status == OrganizerEventStatus.live).length;
    final completed = events.where((e) => e.status == OrganizerEventStatus.completed).length;
    return OrganizerDashboardStats(
      activeEvents: active,
      upcomingEvents: upcoming,
      draftEvents: draft,
      liveEvents: live,
      completedEvents: completed,
      ticketsSold: sold,
      revenueMinor: revenue,
      vendorCount: vendors,
      attendeeCount: attendees,
      registrations: attendees,
      checkIns: events.fold(0, (sum, e) => sum + e.checkedInCount),
    );
  }
});

class OrganizerDashboardStats {
  const OrganizerDashboardStats({
    required this.activeEvents,
    required this.upcomingEvents,
    required this.draftEvents,
    required this.liveEvents,
    required this.completedEvents,
    required this.ticketsSold,
    required this.revenueMinor,
    required this.vendorCount,
    required this.attendeeCount,
    required this.registrations,
    required this.checkIns,
  });

  final int activeEvents;
  final int upcomingEvents;
  final int draftEvents;
  final int liveEvents;
  final int completedEvents;
  final int ticketsSold;
  final int revenueMinor;
  final int vendorCount;
  final int attendeeCount;
  final int registrations;
  final int checkIns;
}
