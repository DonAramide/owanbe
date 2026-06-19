import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  await Future<void>.delayed(const Duration(milliseconds: 80));
  return ref.read(organizerStoreProvider).all;
});

final organizerEventProvider = FutureProvider.autoDispose.family<OrganizerEvent?, String>((ref, id) async {
  ref.watch(organizerRevisionProvider);
  await Future<void>.delayed(const Duration(milliseconds: 50));
  return ref.read(organizerStoreProvider).byId(id);
});

final organizerAnalyticsProvider =
    FutureProvider.autoDispose.family<EventAnalyticsSnapshot, String>((ref, eventId) async {
  ref.watch(organizerRevisionProvider);
  await Future<void>.delayed(const Duration(milliseconds: 100));
  return ref.read(organizerStoreProvider).analyticsFor(eventId);
});

final organizerAttentionProvider = Provider<List<OrganizerAttentionItem>>((ref) {
  ref.watch(organizerRevisionProvider);
  return ref.read(organizerStoreProvider).attentionItems();
});

final organizerRevisionProvider = StateProvider<int>((ref) => 0);

void bumpOrganizerRevision(WidgetRef ref) {
  ref.read(organizerRevisionProvider.notifier).state++;
}

final eventWizardDraftProvider = StateProvider<EventWizardDraft>((ref) => EventWizardDraft());

final organizerDashboardStatsProvider = Provider<OrganizerDashboardStats>((ref) {
  ref.watch(organizerRevisionProvider);
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
