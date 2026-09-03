import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/persistence_providers.dart';
import '../../../core/providers/silent_refresh.dart';
import '../../../auth/user_role.dart';
import '../../../identity/owanbe_identity_config.dart';
import '../../../identity/workspace_providers.dart';
import '../../../router/portal_routes.dart';
import '../vendor_identity.dart';
import '../vendor_os_demo_mode.dart';
import '../../organizer/providers/organizer_providers.dart';
import '../finance/vendor_finance_providers.dart';
import '../models/vendor_models.dart';
import '../models/vendor_workspace_profile.dart';
import '../data/vendor_store.dart';
import 'vendor_profile_providers.dart';

bool _allowMockFinanceFallback() =>
    (dotenv.env['ALLOW_MOCK_FINANCE_FALLBACK'] ?? 'true').trim().toLowerCase() == 'true';


bool _isVendorSession(Ref ref) {
  if (OwanbeIdentityConfig.identityV2) {
    // Watch so vendor home rebuilds after identity refresh (read-only missed updates).
    if (ref.watch(isVendorWorkspaceProvider)) return true;
    // While identity is loading/refreshing, trust session role codes from /auth/me sync.
    final session = ref.watchSignedInUser();
    return session != null &&
        (session.hasRoleCode('vendor') || session.hasRoleCode('vendor_pending'));
  }
  final session = ref.watchSignedInUser();
  return session != null && PortalRoutes.canonicalRole(session) == UserRole.vendor;
}

bool _allowVendorMock(Ref ref) =>
    allowMockPersistenceFallback() && _isVendorSession(ref);

bool _allowVendorFinanceMock(Ref ref) =>
    _allowMockFinanceFallback() && _isVendorSession(ref);

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

/// Resolves the signed-in vendor's canonical CRM vendor ID (owned business row).
///
/// Chain: auth session user → GET /me/vendor-id → vendors.id for owner_user_id.
/// Never substitutes the seed demo Vendor ID for a different authenticated user.
final canonicalVendorIdProvider = FutureProvider.autoDispose<String>((ref) async {
  ref.watch(vendorRevisionProvider);
  final session = ref.watchSignedInUser();
  if (session == null) {
    throw StateError('Vendor session required');
  }
  try {
    final resolved = await ref.read(identityApiProvider).resolveVendorId(session);
    if (resolved != null && resolved.trim().isNotEmpty) {
      return VendorIdentity.resolveMarketplaceVendorId(resolved.trim());
    }
  } catch (_) {
    if (!allowMockPersistenceFallback()) rethrow;
  }
  throw StateError('Vendor workspace not activated — no vendor profile for this account');
});

VendorProfile _profileFromWorkspace({
  required String id,
  required VendorWorkspaceProfile? workspace,
  required VendorProfile storeFallback,
}) {
  final name = (workspace?.businessName.trim().isNotEmpty ?? false)
      ? workspace!.businessName.trim()
      : (storeFallback.businessName.trim().isNotEmpty
          ? storeFallback.businessName.trim()
          : 'Complete your business profile');
  final category = (workspace?.category.trim().isNotEmpty ?? false)
      ? workspace!.category.trim()
      : storeFallback.category;
  final city = (workspace?.city?.trim().isNotEmpty ?? false)
      ? workspace!.city!.trim()
      : storeFallback.city;
  final vendorType = VendorCatalogType.fromLabel(category) ?? storeFallback.vendorType;
  // Never invent PREMIUM — only show tier when demo mode seeded one.
  final tier = VendorOsDemoMode.isEnabled ? storeFallback.tier : '';
  return VendorProfile(
    id: id,
    businessName: name,
    category: category.isEmpty ? 'Vendor' : category,
    vendorType: vendorType,
    tier: tier,
    city: city,
    tagline: storeFallback.tagline,
    rating: VendorOsDemoMode.isEnabled ? storeFallback.rating : 0,
    completedEvents: VendorOsDemoMode.isEnabled ? storeFallback.completedEvents : 0,
  );
}

final vendorProfileProvider = Provider<VendorProfile>((ref) {
  ref.watch(vendorRevisionProvider);
  if (!_isVendorSession(ref)) {
    throw StateError('Vendor portal access required');
  }
  final store = ref.read(vendorStoreProvider);
  final workspace = ref.watch(vendorWorkspaceProfileProvider).valueOrNull;
  final canonicalAsync = ref.watch(canonicalVendorIdProvider);
  final canonicalId = canonicalAsync.valueOrNull;
  if (canonicalId == null) {
    if (canonicalAsync.hasError && !VendorOsDemoMode.isEnabled) {
      throw canonicalAsync.error!;
    }
    if (canonicalAsync.isLoading || VendorOsDemoMode.isEnabled) {
      return _profileFromWorkspace(
        id: '',
        workspace: workspace,
        storeFallback: store.profile,
      );
    }
    throw StateError('Vendor profile loading — activate Vendor workspace first');
  }
  return _profileFromWorkspace(
    id: canonicalId,
    workspace: workspace,
    storeFallback: store.profile,
  );
});

final vendorParticipationsProvider = FutureProvider.autoDispose<List<VendorEventParticipation>>((ref) async {
  ref.watch(vendorRevisionProvider);
  ref.watch(organizerRevisionProvider);
  if (!_isVendorSession(ref)) return const [];
  try {
    return await ref.read(vendorEventsApiProvider).listEvents();
  } catch (e) {
    if (!_allowVendorMock(ref)) rethrow;
    return ref.read(vendorStoreProvider).participations;
  }
});

final vendorParticipationsByLifecycleProvider =
    FutureProvider.autoDispose.family<List<VendorEventParticipation>, ParticipationLifecycle>((ref, stage) async {
  ref.watch(vendorRevisionProvider);
  ref.watch(organizerRevisionProvider);
  if (!_isVendorSession(ref)) return const [];
  List<VendorEventParticipation> all;
  try {
    all = await ref.read(vendorEventsApiProvider).listEvents();
  } catch (e) {
    if (!_allowVendorMock(ref)) rethrow;
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
  if (!_isVendorSession(ref)) return const [];
  try {
    final all = await ref.read(vendorEventsApiProvider).listEvents();
    return all.where((p) => p.lifecycleStage == ParticipationLifecycle.invited).toList();
  } catch (e) {
    if (!_allowVendorMock(ref)) rethrow;
    return ref.read(vendorStoreProvider).discoverableEvents();
  }
});

final vendorCatalogProvider = FutureProvider.autoDispose<List<VendorCatalogItem>>((ref) async {
  ref.watch(vendorRevisionProvider);
  if (!_isVendorSession(ref)) return const [];
  try {
    return await ref.read(vendorCatalogApiProvider).listPackages();
  } catch (e) {
    if (!_allowVendorMock(ref)) rethrow;
    return ref.read(vendorStoreProvider).catalog;
  }
});

final vendorOrdersProvider = FutureProvider.autoDispose<List<VendorOrder>>((ref) async {
  ref.watch(vendorRevisionProvider);
  if (!_isVendorSession(ref)) return const [];
  try {
    return await ref.read(vendorBookingsApiProvider).listOrders();
  } catch (e) {
    if (!_allowVendorMock(ref)) rethrow;
    return ref.read(vendorStoreProvider).orders;
  }
});

final vendorWalletProvider = FutureProvider.autoDispose<VendorWalletSnapshot>((ref) async {
  ref.watch(vendorRevisionProvider);
  if (!_isVendorSession(ref)) {
    throw StateError('Vendor portal access required');
  }
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
    if (!_allowVendorFinanceMock(ref)) rethrow;
    await Future<void>.delayed(const Duration(milliseconds: 40));
    return ref.read(vendorStoreProvider).walletSnapshot();
  }
});

final vendorWalletEntriesProvider = FutureProvider.autoDispose<List<VendorWalletEntry>>((ref) async {
  ref.watch(vendorRevisionProvider);
  if (!_isVendorSession(ref)) return const [];
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
    if (!_allowVendorFinanceMock(ref)) rethrow;
    await Future<void>.delayed(const Duration(milliseconds: 40));
    return ref.read(vendorStoreProvider).walletEntries;
  }
});

final vendorPayoutsProvider = FutureProvider.autoDispose<List<VendorPayoutRequest>>((ref) async {
  ref.watch(vendorRevisionProvider);
  if (!_isVendorSession(ref)) return const [];
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
    if (!_allowVendorFinanceMock(ref)) rethrow;
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
  if (!_isVendorSession(ref)) {
    throw StateError('Vendor portal access required');
  }
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
    if (!_allowVendorFinanceMock(ref)) rethrow;
    await Future<void>.delayed(const Duration(milliseconds: 80));
    return ref.read(vendorStoreProvider).analytics();
  }
});

final vendorDashboardStatsProvider = FutureProvider.autoDispose<VendorDashboardStats>((ref) async {
  ref.watch(vendorRevisionProvider);
  if (!_isVendorSession(ref)) {
    throw StateError('Vendor portal access required');
  }
  try {
    final summary = await ref.read(vendorFinanceApiProvider).getSummary();
    final t = summary.totals;
    List<VendorEventParticipation> parts;
    try {
      parts = await ref.read(vendorEventsApiProvider).listEvents();
    } catch (_) {
      if (!_allowVendorMock(ref)) rethrow;
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
      totalBookings: VendorOsDemoMode.isEnabled ? store.totalBookings : 0,
      revenueMinor: int.tryParse(t.totalEarningsMinor) ?? 0,
      walletBalanceMinor: int.tryParse(t.availableBalanceMinor) ?? 0,
      pendingPayoutsMinor: VendorOsDemoMode.isEnabled ? store.pendingPayoutsMinor : 0,
      pendingSettlementMinor: int.tryParse(t.pendingEarningsMinor) ?? 0,
      customerRating: VendorOsDemoMode.isEnabled ? store.profile.rating : 0,
    );
  } catch (e) {
    if (!_allowVendorFinanceMock(ref)) rethrow;
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
