import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/disputes_api.dart';
import '../admin/finance/admin_finance_models.dart';
import 'dispute_models.dart';

final disputesApiProvider = Provider<DisputesApi>((ref) => DisputesApi());

final adminDisputesPageProvider = StateProvider<int>((ref) => 1);
final adminDisputesProvider = FutureProvider.autoDispose<PaginatedResponse<DisputeItem>>((ref) async {
  final page = ref.watch(adminDisputesPageProvider);
  return ref.read(disputesApiProvider).listAdmin(page: page, limit: 50);
});

final myDisputesProvider = FutureProvider.autoDispose<PaginatedResponse<DisputeItem>>((ref) async {
  return ref.read(disputesApiProvider).listMine(limit: 50);
});

final selectedAdminDisputeIdProvider = StateProvider<String?>((ref) => null);

final adminDisputeDetailProvider = FutureProvider.autoDispose<DisputeDetail?>((ref) async {
  final id = ref.watch(selectedAdminDisputeIdProvider);
  if (id == null) return null;
  return ref.read(disputesApiProvider).getDetail(id, admin: true);
});
