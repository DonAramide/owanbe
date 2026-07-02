import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/auth_notifier.dart';
import '../api/customer_finance_api.dart';
import '../models/customer_finance_models.dart';

final customerFinanceApiProvider = Provider<CustomerFinanceApi>((ref) => CustomerFinanceApi());

final customerEventFinanceSummaryProvider =
    FutureProvider.autoDispose.family<CustomerEventFinanceSummary, String>((ref, eventId) async {
  final session = ref.watch(authSessionProvider);
  return ref.read(customerFinanceApiProvider).fetchEventSummary(eventId: eventId, session: session);
});

final customerEventFinanceTransactionsProvider =
    FutureProvider.autoDispose.family<List<CustomerFinanceTransaction>, String>((ref, eventId) async {
  final session = ref.watch(authSessionProvider);
  return ref.read(customerFinanceApiProvider).fetchEventTransactions(eventId: eventId, session: session);
});
