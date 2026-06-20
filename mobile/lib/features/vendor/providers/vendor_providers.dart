import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/persistence_providers.dart';
import '../../organizer/providers/organizer_providers.dart';
import '../finance/vendor_finance_providers.dart';
import '../models/vendor_models.dart';
import '../data/vendor_store.dart';

bool _allowMockFinanceFallback() =>
    (dotenv.env['ALLOW_MOCK_FINANCE_FALLBACK'] ?? 'false').trim().toLowerCase() == 'true';

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
  try {
    return await ref.read(vendorEventsApiProvider).listEvents();
  } catch (e) {
    if (!allowMockPersistenceFallback()) rethrow;
    return ref.read(vendorStoreProvider).participations;
  }
});

final vendorParticipationsByLifecycleProvider =
    FutureProvider.autoDispose.family<List<VendorEventParticipation>, ParticipationLifecycle>((ref, stage) async {
  ref.watch(vendorRevisionProvider);
  ref.watch(organizerRevisionProvider);
  List<VendorEventParticipation> all;
  try {
    all = await ref.read(vendorEventsApiProvider).listEvents();
  } catch (e) {
    if (!allowMockPersistenceFallback()) rethrow;
    return ref.read(vendorStoreProvider).participationsForLifecycle(stage);
  }
  if (stage == ParticipationLifecycle.invited) {
    return all.where((p) => p.lifecycleStage == ParticipationLifecycle.invited).toList();
  }
  return all.where((p) => p.lifecycleStage == stage).toList();
});

final vendorDiscoverableEventsProvider = FutureProvider.autoDispose<List<VendorEventParticipation>>((ref) async {
  ref.watch(vendorRevisionProvider);
  ref.watch(organizerRevisionProvider);
  try {
    final all = await ref.read(vendorEventsApiProvider).listEvents();
    return all.where((p) => p.lifecycleStage == ParticipationLifecycle.invited).toList();
  } catch (e) {
    if (!allowMockPersistenceFallback()) rethrow;
    return ref.read(vendorStoreProvider).discoverableEvents();
  }
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
  try {
    final summary = await ref.read(vendorFinanceApiProvider).getSummary();
    final t = summary.totals;
    return VendorWalletSnapshot(
      availableMinor: int.tryParse(t.availableBalanceMinor) ?? 0,
      pendingMinor: int.tryParse(t.pendingEarningsMinor) ?? 0,
      totalEarnedMinor: int.tryParse(t.totalEarningsMinor) ?? 0,
      underReviewMinor: int.tryParse(t.underReviewAmountMinor) ?? 0,
    );
  } catch (e) {
    if (!_allowMockFinanceFallback()) rethrow;
    await Future<void>.delayed(const Duration(milliseconds: 40));
    return ref.read(vendorStoreProvider).walletSnapshot();
  }
});

final vendorWalletEntriesProvider = FutureProvider.autoDispose<List<VendorWalletEntry>>((ref) async {
  ref.watch(vendorRevisionProvider);
  try {
    final txs = await ref.read(vendorFinanceApiProvider).getTransactions(limit: 100);
    return txs.items
        .where((t) => t.type != 'payout')
        .map(
          (t) => VendorWalletEntry(
            id: '${t.timestampMs}-${t.bookingReference}',
            type: t.type == 'refund' || t.type == 'chargeback'
                ? VendorWalletEntryType.refund
                : VendorWalletEntryType.earning,
            amountMinor: int.tryParse(t.amountMinor) ?? 0,
            label: t.type,
            reference: t.bookingReference,
            timestamp: DateTime.fromMillisecondsSinceEpoch(t.timestampMs),
            status: t.status,
          ),
        )
        .toList();
  } catch (e) {
    if (!_allowMockFinanceFallback()) rethrow;
    await Future<void>.delayed(const Duration(milliseconds: 40));
    return ref.read(vendorStoreProvider).walletEntries;
  }
});

final vendorPayoutsProvider = FutureProvider.autoDispose<List<VendorPayoutRequest>>((ref) async {
  ref.watch(vendorRevisionProvider);
  try {
    final txs = await ref.read(vendorFinanceApiProvider).getTransactions(limit: 100);
    return txs.items
        .where((t) => t.type == 'payout')
        .map(
          (t) => VendorPayoutRequest(
            id: t.bookingReference,
            amountMinor: (int.tryParse(t.amountMinor) ?? 0).abs(),
            status: _mapPayoutStatus(t.status),
            requestedAt: DateTime.fromMillisecondsSinceEpoch(t.timestampMs),
            destinationLabel: t.reason ?? 'Bank transfer',
          ),
        )
        .toList();
  } catch (e) {
    if (!_allowMockFinanceFallback()) rethrow;
    await Future<void>.delayed(const Duration(milliseconds: 40));
    return ref.read(vendorStoreProvider).payouts;
  }
});

VendorPayoutStatus _mapPayoutStatus(String status) => switch (status) {
      'pending' => VendorPayoutStatus.pending,
      'processing' => VendorPayoutStatus.processing,
      'completed' => VendorPayoutStatus.completed,
      'failed' => VendorPayoutStatus.failed,
      _ => VendorPayoutStatus.pending,
    };

final vendorAnalyticsProvider = FutureProvider.autoDispose<VendorAnalyticsSnapshot>((ref) async {
  ref.watch(vendorRevisionProvider);
  try {
    final summary = await ref.read(vendorFinanceApiProvider).getSummary();
    final snap = ref.read(vendorStoreProvider).analytics();
    return VendorAnalyticsSnapshot(
      revenueMinor: int.tryParse(summary.totals.totalEarningsMinor) ?? snap.revenueMinor,
      ordersCount: snap.ordersCount,
      fulfillmentRate: snap.fulfillmentRate,
      avgOrderMinor: snap.avgOrderMinor,
      revenueTrend: snap.revenueTrend,
      ordersByEvent: snap.ordersByEvent,
    );
  } catch (e) {
    if (!_allowMockFinanceFallback()) rethrow;
    await Future<void>.delayed(const Duration(milliseconds: 80));
    return ref.read(vendorStoreProvider).analytics();
  }
});

final vendorDashboardStatsProvider = FutureProvider.autoDispose<VendorDashboardStats>((ref) async {
  ref.watch(vendorRevisionProvider);
  try {
    final summary = await ref.read(vendorFinanceApiProvider).getSummary();
    final t = summary.totals;
    List<VendorEventParticipation> parts;
    try {
      parts = await ref.read(vendorEventsApiProvider).listEvents();
    } catch (_) {
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
  } catch (e) {
    if (!_allowMockFinanceFallback()) rethrow;
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
