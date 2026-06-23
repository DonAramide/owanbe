import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/auth_notifier.dart';
import '../../../features/organizer/finance/organizer_finance_api.dart';
import '../../../features/organizer/finance/organizer_finance_providers.dart';
import '../../../features/organizer/providers/organizer_providers.dart';
import '../models/budget_dashboard_models.dart';

final customerBudgetRefreshProvider = StateProvider<int>((ref) => 0);

void refreshEventBudget(WidgetRef ref) {
  ref.read(customerBudgetRefreshProvider.notifier).state++;
}

final customerEventBudgetProvider =
    FutureProvider.autoDispose.family<BudgetDashboardSnapshot, String>((ref, eventId) async {
  ref.watch(customerBudgetRefreshProvider);
  ref.watch(organizerRevisionProvider);

  final event = await ref.watch(organizerEventProvider(eventId).future);
  if (event == null) {
    throw StateError('Event not found');
  }

  OrganizerEventFinanceSummary? finance;
  var transactions = <OrganizerFinanceTransaction>[];

  try {
    final session = ref.read(authSessionProvider);
    finance = await ref
        .read(organizerFinanceApiProvider)
        .fetchEventSummary(eventId: eventId, session: session);
  } catch (_) {
    finance = null;
  }

  try {
    final session = ref.read(authSessionProvider);
    transactions = await ref
        .read(organizerFinanceApiProvider)
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
