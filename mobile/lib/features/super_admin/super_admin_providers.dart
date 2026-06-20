import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/super_admin_api.dart';

final superAdminApiProvider = Provider<SuperAdminApi>((ref) => SuperAdminApi());

final superAdminRevisionProvider = StateProvider<int>((ref) => 0);

void bumpSuperAdminRevision(WidgetRef ref) {
  ref.read(superAdminRevisionProvider.notifier).state++;
}

final superAdminOverviewProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  ref.watch(superAdminRevisionProvider);
  return ref.read(superAdminApiProvider).getPlatformOverview();
});

final superAdminTenantsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, q) async {
  ref.watch(superAdminRevisionProvider);
  return ref.read(superAdminApiProvider).listTenants(q: q.isEmpty ? null : q);
});

final superAdminTenantDetailProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  ref.watch(superAdminRevisionProvider);
  return ref.read(superAdminApiProvider).getTenant(id);
});

final superAdminFinanceProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  ref.watch(superAdminRevisionProvider);
  return ref.read(superAdminApiProvider).getPlatformFinance();
});

final superAdminSystemHealthProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  ref.watch(superAdminRevisionProvider);
  return ref.read(superAdminApiProvider).getSystemHealth();
});

final superAdminFeatureFlagsProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, tenantId) async {
  ref.watch(superAdminRevisionProvider);
  return ref.read(superAdminApiProvider).getFeatureFlags(tenantId);
});

final superAdminAuditProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, category) async {
  ref.watch(superAdminRevisionProvider);
  return ref.read(superAdminApiProvider).getAuditTimeline(category: category == 'all' ? null : category);
});

final superAdminAnalyticsProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, range) async {
  ref.watch(superAdminRevisionProvider);
  return ref.read(superAdminApiProvider).getAnalytics(range: range);
});

final superAdminSecurityProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  ref.watch(superAdminRevisionProvider);
  return ref.read(superAdminApiProvider).getSecurityCenter();
});

final superAdminTenantSearchProvider = StateProvider<String>((ref) => '');
final selectedSuperAdminTenantIdProvider = StateProvider<String?>((ref) => null);
final superAdminAuditCategoryProvider = StateProvider<String>((ref) => 'all');
final superAdminAnalyticsRangeProvider = StateProvider<String>((ref) => '30d');
final superAdminFeatureFlagTenantProvider = StateProvider<String>((ref) => '11111111-1111-4111-8111-111111111111');
final superAdminShellTabProvider = NotifierProvider<SuperAdminShellController, int>(SuperAdminShellController.new);

class SuperAdminShellController extends Notifier<int> {
  @override
  int build() => 0;
  void select(int tab) => state = tab;
}
