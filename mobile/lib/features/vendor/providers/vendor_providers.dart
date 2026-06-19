import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../organizer/providers/organizer_providers.dart';
import '../data/vendor_store.dart';
import '../models/vendor_models.dart';

final vendorStoreProvider = Provider<VendorStore>((ref) => VendorStore.instance);

final vendorRevisionProvider = StateProvider<int>((ref) => 0);

void bumpVendorRevision(WidgetRef ref) {
  ref.read(vendorRevisionProvider.notifier).state++;
}

final vendorShellTabProvider = NotifierProvider<VendorShellTabController, int>(
  VendorShellTabController.new,
);

class VendorShellTabController extends Notifier<int> {
  @override
  int build() => 0;
  void select(int tab) => state = tab;
}

final selectedVendorEventIdProvider = StateProvider<String?>((ref) => null);

final participationLifecycleFilterProvider =
    StateProvider<ParticipationLifecycle>((ref) => ParticipationLifecycle.invited);

final vendorOrdersViewModeProvider = StateProvider<VendorOrdersViewMode>(
  (ref) => VendorOrdersViewMode.cards,
);

enum VendorOrdersViewMode { cards, table }

final vendorProfileProvider = Provider<VendorProfile>((ref) {
  ref.watch(vendorRevisionProvider);
  return ref.read(vendorStoreProvider).profile;
});

final vendorParticipationsProvider = FutureProvider.autoDispose<List<VendorEventParticipation>>((ref) async {
  ref.watch(vendorRevisionProvider);
  ref.watch(organizerRevisionProvider);
  await Future<void>.delayed(const Duration(milliseconds: 60));
  return ref.read(vendorStoreProvider).participations;
});

final vendorParticipationsByLifecycleProvider =
    FutureProvider.autoDispose.family<List<VendorEventParticipation>, ParticipationLifecycle>((ref, stage) async {
  ref.watch(vendorRevisionProvider);
  ref.watch(organizerRevisionProvider);
  await Future<void>.delayed(const Duration(milliseconds: 60));
  return ref.read(vendorStoreProvider).participationsForLifecycle(stage);
});

final vendorDiscoverableEventsProvider = FutureProvider.autoDispose<List<VendorEventParticipation>>((ref) async {
  ref.watch(vendorRevisionProvider);
  ref.watch(organizerRevisionProvider);
  await Future<void>.delayed(const Duration(milliseconds: 60));
  return ref.read(vendorStoreProvider).discoverableEvents();
});

final vendorCatalogProvider = FutureProvider.autoDispose<List<VendorCatalogItem>>((ref) async {
  ref.watch(vendorRevisionProvider);
  await Future<void>.delayed(const Duration(milliseconds: 50));
  return ref.read(vendorStoreProvider).catalog;
});

final vendorOrdersProvider = FutureProvider.autoDispose<List<VendorOrder>>((ref) async {
  ref.watch(vendorRevisionProvider);
  await Future<void>.delayed(const Duration(milliseconds: 50));
  return ref.read(vendorStoreProvider).orders;
});

final vendorWalletProvider = FutureProvider.autoDispose<VendorWalletSnapshot>((ref) async {
  ref.watch(vendorRevisionProvider);
  await Future<void>.delayed(const Duration(milliseconds: 40));
  return ref.read(vendorStoreProvider).walletSnapshot();
});

final vendorWalletEntriesProvider = FutureProvider.autoDispose<List<VendorWalletEntry>>((ref) async {
  ref.watch(vendorRevisionProvider);
  await Future<void>.delayed(const Duration(milliseconds: 40));
  return ref.read(vendorStoreProvider).walletEntries;
});

final vendorPayoutsProvider = FutureProvider.autoDispose<List<VendorPayoutRequest>>((ref) async {
  ref.watch(vendorRevisionProvider);
  await Future<void>.delayed(const Duration(milliseconds: 40));
  return ref.read(vendorStoreProvider).payouts;
});

final vendorAnalyticsProvider = FutureProvider.autoDispose<VendorAnalyticsSnapshot>((ref) async {
  ref.watch(vendorRevisionProvider);
  await Future<void>.delayed(const Duration(milliseconds: 80));
  return ref.read(vendorStoreProvider).analytics();
});

final vendorDashboardStatsProvider = Provider<VendorDashboardStats>((ref) {
  ref.watch(vendorRevisionProvider);
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
});

class VendorDashboardStats {
  const VendorDashboardStats({
    required this.activeEvents,
    required this.totalBookings,
    required this.revenueMinor,
    required this.walletBalanceMinor,
    required this.pendingPayoutsMinor,
    required this.pendingSettlementMinor,
    required this.customerRating,
  });

  final int activeEvents;
  final int totalBookings;
  final int revenueMinor;
  final int walletBalanceMinor;
  final int pendingPayoutsMinor;
  final int pendingSettlementMinor;
  final double customerRating;
}
