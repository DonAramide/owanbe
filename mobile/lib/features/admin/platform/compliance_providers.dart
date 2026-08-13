import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/compliance_api.dart';

final complianceApiProvider = Provider<ComplianceApi>((ref) => ComplianceApi());

final complianceDashboardProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.read(complianceApiProvider).dashboard();
});

final complianceRetentionProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.read(complianceApiProvider).retention();
});

final complianceExportsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.read(complianceApiProvider).listExports();
});

final complianceDeletionsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.read(complianceApiProvider).listDeletions();
});

final complianceActivityProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.read(complianceApiProvider).activity();
});
