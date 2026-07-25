import 'package:flutter_riverpod/flutter_riverpod.dart';



import '../../../auth/auth_notifier.dart';

import '../../../core/api/persistence_providers.dart';

import '../../../core/api/vendors_api.dart';

import '../../../features/organizer/models/organizer_models.dart';

import '../../../features/organizer/providers/organizer_providers.dart';

import '../../../features/public/models/attendee_event_models.dart';

import '../../../features/public/providers/attendee_events_provider.dart';

import '../../../features/public/providers/public_providers.dart';

import '../../../features/public/data/discover_recommendation_engine.dart';

import '../../../features/vendor/finance/vendor_finance_providers.dart';

import '../../../identity/identity_provider.dart';

import '../../../features/vendor/models/vendor_models.dart';

import '../../../features/vendor/providers/vendor_providers.dart';

import '../../../identity/user_identity.dart';

import '../../../identity/workspace_models.dart';

import '../../../identity/workspace_providers.dart';

import '../../../portals/customer/data/customer_event_dev_store.dart';

import '../../../portals/customer/models/customer_event_models.dart';

import '../../../portals/customer/models/home_hub_models.dart';

import '../../../portals/customer/providers/customer_event_providers.dart';

import '../../../portals/customer/providers/customer_home_providers.dart';
import '../../../portals/customer/providers/vendor_crm_providers.dart';

import '../models/living_home_models.dart';



final livingHomeRefreshProvider = StateProvider<int>((ref) => 0);



void refreshLivingHome(WidgetRef ref) {

  ref.read(livingHomeRefreshProvider.notifier).state++;

  refreshCustomerHome(ref);

  bumpOrganizerRevision(ref);

  bumpVendorRevision(ref);

}



/// Hub-scoped organizer events — independent section provider.

final hubOrganizerEventsProvider = FutureProvider.autoDispose<List<CustomerEvent>>((ref) async {

  ref.watch(livingHomeRefreshProvider);

  if (!ref.watch(canAccessWorkspaceProvider(ExperienceWorkspace.organizer))) {

    return const [];

  }

  final session = ref.watch(authSessionProvider);

  if (session == null) return const [];

  try {

    return await ref.read(customerEventsApiProvider).listEvents(session: session);

  } catch (_) {

    if (!allowMockPersistenceFallback()) rethrow;

    return CustomerEventDevStore.instance.all;

  }

});



final hubOrganizerDashboardProvider =

    FutureProvider.autoDispose<OrganizerDashboardStats?>((ref) async {

  ref.watch(livingHomeRefreshProvider);

  if (!ref.watch(canAccessWorkspaceProvider(ExperienceWorkspace.organizer))) {

    return null;

  }

  try {

    return await ref.watch(organizerDashboardStatsProvider.future);

  } catch (_) {

    return null;

  }

});



final hubOrganizerAlertsProvider =

    FutureProvider.autoDispose<List<OrganizerAttentionItem>>((ref) async {

  ref.watch(livingHomeRefreshProvider);

  if (!ref.watch(canAccessWorkspaceProvider(ExperienceWorkspace.organizer))) {

    return const [];

  }

  try {

    final base = await ref.watch(organizerAttentionProvider.future);
    final vendorCrm = await ref.watch(organizerVendorCrmAlertsProvider.future);
    return [...vendorCrm, ...base];

  } catch (_) {

    return const [];

  }

});



final hubVendorDashboardProvider =

    FutureProvider.autoDispose<VendorDashboardStats?>((ref) async {

  ref.watch(livingHomeRefreshProvider);

  if (!ref.watch(canAccessWorkspaceProvider(ExperienceWorkspace.vendor))) {

    return null;

  }

  try {

    final summary = await ref.read(vendorFinanceApiProvider).getSummary();

    final t = summary.totals;

    List<VendorEventParticipation> parts;

    try {

      parts = await ref.read(vendorEventsApiProvider).listEvents();

    } catch (_) {

      if (!allowMockPersistenceFallback()) rethrow;

      parts = ref.read(vendorStoreProvider).participations;

    }

    final activeEvents = parts

        .where((p) =>

            p.status == VendorParticipationStatus.confirmed ||

            p.status == VendorParticipationStatus.live)

        .length;

    final store = ref.read(vendorStoreProvider);

    return VendorDashboardStats(

      activeEvents: activeEvents,

      totalBookings: store.totalBookings,

      revenueMinor: int.tryParse(t.totalEarningsMinor) ?? 0,

      walletBalanceMinor: int.tryParse(t.availableBalanceMinor) ?? 0,

      pendingPayoutsMinor: store.pendingPayoutsMinor,

      pendingSettlementMinor: int.tryParse(t.pendingEarningsMinor) ?? 0,

      customerRating: store.profile.rating,

    );

  } catch (_) {

    if (!allowMockPersistenceFallback()) return null;

    final store = ref.read(vendorStoreProvider);

    final wallet = store.walletSnapshot();

    final activeEvents = store.participations

        .where((p) =>

            p.status == VendorParticipationStatus.confirmed ||

            p.status == VendorParticipationStatus.live)

        .length;

    return VendorDashboardStats(

      activeEvents: activeEvents,

      totalBookings: store.totalBookings,

      revenueMinor: store.lifetimeRevenueMinor,

      walletBalanceMinor: wallet.availableMinor,

      pendingPayoutsMinor: store.pendingPayoutsMinor,

      pendingSettlementMinor: wallet.pendingMinor,

      customerRating: store.profile.rating,

    );

  }

});



final livingHomeInvitationsProvider =

    FutureProvider.autoDispose<List<CustomerInvitationCard>>((ref) async {

  ref.watch(livingHomeRefreshProvider);

  final identity = ref.watch(userIdentityProvider).valueOrNull;

  if (identity == null ||

      !(identity.canAccess(ExperienceWorkspace.attendee) ||

          identity.canEnter(ExperienceWorkspace.attendee))) {

    return const [];

  }

  try {

    return await ref.watch(customerTicketInvitationsProvider.future);

  } catch (_) {

    return const [];

  }

});



final livingHomeAttendeeStatsProvider =

    FutureProvider.autoDispose<AttendeeDashboardStats?>((ref) async {

  ref.watch(livingHomeRefreshProvider);

  final identity = ref.watch(userIdentityProvider).valueOrNull;

  if (identity == null ||

      !(identity.canAccess(ExperienceWorkspace.attendee) ||

          identity.canEnter(ExperienceWorkspace.attendee))) {

    return null;

  }

  return ref.watch(attendeeDashboardStatsProvider).valueOrNull;

});



final livingHomeOrganizerSummariesProvider =

    FutureProvider.autoDispose<LivingHomeOrganizerSection>((ref) async {

  ref.watch(livingHomeRefreshProvider);

  final identity = ref.watch(userIdentityProvider).valueOrNull;

  if (identity == null || !identity.canAccess(ExperienceWorkspace.organizer)) {

    return const LivingHomeOrganizerSection();

  }

  final stats = await ref.watch(hubOrganizerDashboardProvider.future);

  final alerts = await ref.watch(hubOrganizerAlertsProvider.future);

  final events = await ref.watch(hubOrganizerEventsProvider.future);

  final draftEventSummaries = events

      .where((e) => e.status == CustomerEventStatus.draft)

      .map(CustomerEventSummary.fromEvent)

      .toList();

  final organizerEventSummaries = events

      .where(

        (e) =>

            e.status != CustomerEventStatus.completed &&

            e.status != CustomerEventStatus.cancelled &&

            e.status != CustomerEventStatus.draft,

      )

      .map(CustomerEventSummary.fromEvent)

      .toList()

    ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

  return LivingHomeOrganizerSection(

    stats: stats,

    alerts: alerts,

    events: organizerEventSummaries,

    draftEvents: draftEventSummaries,

    nearestEvent: _pickNearest(organizerEventSummaries),

  );

});



final livingHomeTrendingEventsProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  ref.watch(livingHomeRefreshProvider);
  try {
    final public = await ref.watch(publicEventCatalogProvider.future);
    final trending = const HeuristicDiscoverRecommendationEngine().trending(catalog: public, limit: 4);
    return trending.map((e) => e.title).toList();
  } catch (_) {
    return const [];
  }
});



final livingHomeTrendingVendorsProvider =

    FutureProvider.autoDispose<List<MarketplaceVendor>>((ref) async {

  ref.watch(livingHomeRefreshProvider);

  try {

    final vendors = await ref.watch(customerMarketplaceVendorsProvider.future);

    return vendors.take(8).toList();

  } catch (_) {

    return const [];

  }

});



/// Messages tab — independent of home feed aggregation.

final homeMessagePreviewsProvider =

    FutureProvider.autoDispose<List<LivingHomeMessagePreview>>((ref) async {

  ref.watch(livingHomeRefreshProvider);

  final previews = <LivingHomeMessagePreview>[];



  final organizer = await ref.watch(livingHomeOrganizerSummariesProvider.future);

  if (organizer.stats != null && organizer.stats!.vendorCount > 0) {

    previews.add(LivingHomeMessagePreview(

      sender: 'Vendor pipeline',

      preview: '${organizer.stats!.vendorCount} vendors connected to your events',

      sentAt: DateTime.now().subtract(const Duration(hours: 2)),

    ));

  }



  final vendorStats = await ref.watch(hubVendorDashboardProvider.future);

  if (vendorStats != null && vendorStats.totalBookings > 0) {

    previews.add(LivingHomeMessagePreview(

      sender: 'Booking requests',

      preview: '${vendorStats.totalBookings} bookings in your pipeline',

      sentAt: DateTime.now().subtract(const Duration(minutes: 45)),

      unread: true,

    ));

  }



  final invitations = await ref.watch(livingHomeInvitationsProvider.future);

  if (invitations.isNotEmpty) {

    previews.add(LivingHomeMessagePreview(

      sender: 'Event invitations',

      preview: 'Reminder: ${invitations.first.eventTitle} is coming up',

      sentAt: DateTime.now().subtract(const Duration(hours: 5)),

    ));

  }



  return previews;

});



/// Lightweight recent activity for the launcher — summary only, no dashboards.
final hubLauncherActivityProvider =
    FutureProvider.autoDispose<List<LivingHomeActivityItem>>((ref) async {
  ref.watch(livingHomeRefreshProvider);
  final items = <LivingHomeActivityItem>[];

  final organizer = await ref.watch(livingHomeOrganizerSummariesProvider.future);
  for (final alert in organizer.alerts.take(2)) {
    items.add(LivingHomeActivityItem(
      title: alert.headline,
      subtitle: alert.message,
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      icon: 'organizer',
      workspace: ExperienceWorkspace.organizer,
    ));
  }

  final vendorStats = await ref.watch(hubVendorDashboardProvider.future);
  if (vendorStats != null && vendorStats.totalBookings > 0) {
    items.add(LivingHomeActivityItem(
      title: 'Vendor bookings',
      subtitle: '${vendorStats.totalBookings} bookings need attention',
      timestamp: DateTime.now().subtract(const Duration(minutes: 45)),
      icon: 'vendor',
      workspace: ExperienceWorkspace.vendor,
    ));
  }

  final invitations = await ref.watch(livingHomeInvitationsProvider.future);
  if (invitations.isNotEmpty) {
    items.add(LivingHomeActivityItem(
      title: 'Event invitation',
      subtitle: invitations.first.eventTitle,
      timestamp: DateTime.now().subtract(const Duration(hours: 5)),
      icon: 'ticket',
      workspace: ExperienceWorkspace.attendee,
    ));
  }

  return items;
});

/// Alert badge count — independent provider.

final homeAlertCountProvider = Provider.autoDispose<int>((ref) {

  ref.watch(livingHomeRefreshProvider);

  final organizerAlerts = ref.watch(hubOrganizerAlertsProvider).valueOrNull ?? const [];

  final vendorStats = ref.watch(hubVendorDashboardProvider).valueOrNull;

  return organizerAlerts.length + ((vendorStats?.totalBookings ?? 0) > 0 ? 1 : 0);

});



List<LivingHomeOnboardingCard> livingHomeOnboardingCards(OwanbeUserIdentity identity) {

  final cards = <LivingHomeOnboardingCard>[];

  for (final ws in ExperienceWorkspace.values) {

    final state = identity.workspaceState(ws);

    if (state.status == WorkspaceStatus.inProgress) {

      cards.add(LivingHomeOnboardingCard(

        workspace: ws,

        title: 'Continue ${ws.title} setup',

        subtitle: 'Pick up where you left off — no need to sign in again.',

        actionLabel: 'Continue',

      ));

    } else if (state.status == WorkspaceStatus.notActivated) {

      cards.add(LivingHomeOnboardingCard(

        workspace: ws,

        title: 'Activate ${ws.title}',

        subtitle: ws.subtitle,

        actionLabel: 'Get started',

      ));

    }

  }

  return cards;

}



const livingHomeAnnouncements = [

  LivingHomeAnnouncement(

    title: 'Owanbe Operating System',

    body: 'Your workspaces now share one intelligent home. Switch instantly without signing out.',

    severity: 'INFO',

  ),

];



CustomerEventSummary? _pickNearest(List<CustomerEventSummary> events) {

  if (events.isEmpty) return null;

  final now = DateTime.now();

  final live = events.where((e) => e.isLive).toList();

  if (live.isNotEmpty) return live.first;

  final upcoming = events.where((e) => e.startsAt.isAfter(now.subtract(const Duration(hours: 12)))).toList()

    ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

  if (upcoming.isNotEmpty) return upcoming.first;

  final sorted = [...events]..sort((a, b) => b.startsAt.compareTo(a.startsAt));

  return sorted.first;

}



/// Organizer section payload — each home tab loads this independently.

class LivingHomeOrganizerSection {

  const LivingHomeOrganizerSection({

    this.stats,

    this.alerts = const [],

    this.events = const [],

    this.draftEvents = const [],

    this.nearestEvent,

  });



  final OrganizerDashboardStats? stats;

  final List<OrganizerAttentionItem> alerts;

  final List<CustomerEventSummary> events;

  final List<CustomerEventSummary> draftEvents;

  final CustomerEventSummary? nearestEvent;

}


