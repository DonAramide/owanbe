import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/admin_platform_api.dart';

final adminPlatformApiProvider = Provider<AdminPlatformApi>((ref) => AdminPlatformApi());

final launchOpsDashboardProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.read(adminPlatformApiProvider).getLaunchOpsDashboard();
});

final platformDashboardProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.read(adminPlatformApiProvider).getPlatformDashboard();
});

final adminOrganizersProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, query) async {
  return ref.read(adminPlatformApiProvider).listOrganizers(q: query.isEmpty ? null : query);
});

final adminOrganizerDetailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  return ref.read(adminPlatformApiProvider).getOrganizer(id);
});

final adminEventsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, query) async {
  return ref.read(adminPlatformApiProvider).listEvents(q: query.isEmpty ? null : query);
});

final adminEventDetailProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  return ref.read(adminPlatformApiProvider).getEvent(id);
});

final adminVendorsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, query) async {
  return ref.read(adminPlatformApiProvider).listVendors(q: query.isEmpty ? null : query);
});

final adminVendorDetailProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  return ref.read(adminPlatformApiProvider).getVendor(id);
});

final adminOperationsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.read(adminPlatformApiProvider).getOperationsOverview();
});

final adminFinanceSupervisionProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.read(adminPlatformApiProvider).getFinanceSupervision();
});

final adminAuditProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, category) async {
  return ref.read(adminPlatformApiProvider).getAuditTimeline(category: category == 'all' ? null : category);
});

final adminPlatformRevisionProvider = StateProvider<int>((ref) => 0);

void bumpAdminPlatformRevision(WidgetRef ref) {
  ref.read(adminPlatformRevisionProvider.notifier).state++;
}

final adminOrganizerSearchProvider = StateProvider<String>((ref) => '');
final adminEventSearchProvider = StateProvider<String>((ref) => '');
final adminVendorSearchProvider = StateProvider<String>((ref) => '');
final adminAuditCategoryProvider = StateProvider<String>((ref) => 'all');

final selectedAdminOrganizerIdProvider = StateProvider<String?>((ref) => null);
final selectedAdminEventIdProvider = StateProvider<String?>((ref) => null);
final selectedAdminVendorIdProvider = StateProvider<String?>((ref) => null);
