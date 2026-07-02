import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/auth_notifier.dart';
import '../models/budget_dashboard_models.dart';
import '../models/customer_finance_models.dart';
import '../providers/customer_event_providers.dart';
import '../providers/customer_finance_providers.dart';

final customerBudgetRefreshProvider = StateProvider<int>((ref) => 0);

void refreshEventBudget(WidgetRef ref) {
  ref.read(customerBudgetRefreshProvider.notifier).state++;
}

final customerEventBudgetProvider =
    FutureProvider.autoDispose.family<BudgetDashboardSnapshot, String>((ref, eventId) async {
  ref.watch(customerBudgetRefreshProvider);
  ref.watch(customerEventRevisionProvider);

  final event = await ref.watch(customerEventProvider(eventId).future);
  if (event == null) {
    throw StateError('Event not found');
  }

  CustomerEventFinanceSummary? finance;
  var transactions = <CustomerFinanceTransaction>[];

  try {
    final session = ref.read(authSessionProvider);
    finance = await ref
        .read(customerFinanceApiProvider)
        .fetchEventSummary(eventId: eventId, session: session);
  } catch (_) {
    finance = null;
  }

  try {
    final session = ref.read(authSessionProvider);
    transactions = await ref
        .read(customerFinanceApiProvider)
        .fetchEventTransactions(eventId: eventId, session: session);
  } catch (_) {
    transactions = const [];
  }

  return buildBudgetDashboardSnapshot(
    event: event,
    finance: finance,
    transactions: transactions,
  );
});
