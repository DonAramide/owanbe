import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/admin_finance_api.dart';
import 'admin_finance_models.dart';

final adminFinanceApiProvider = Provider<AdminFinanceApi>(
  (ref) => AdminFinanceApi(),
);
final adminPollTickProvider = StreamProvider.autoDispose<int>(
  (ref) => Stream<int>.periodic(const Duration(seconds: 15), (i) => i),
);

final adminSummaryProvider = FutureProvider.autoDispose<AdminFinanceSummary>((
  ref,
) async {
  ref.watch(adminPollTickProvider);
  return ref.read(adminFinanceApiProvider).getSummary();
});

final adminAlertsProvider = FutureProvider.autoDispose<List<AdminAlertItem>>((
  ref,
) async {
  ref.watch(adminPollTickProvider);
  final page = await ref.read(adminFinanceApiProvider).getAlerts(limit: 20);
  return page.items;
});

class TableQuery {
  const TableQuery({
    this.page = 1,
    this.limit = 20,
    this.sortBy = 'created_at',
    this.sortDir = 'desc',
    this.type,
    this.status,
    this.fromDate,
    this.toDate,
  });
  final int page;
  final int limit;
  final String sortBy;
  final String sortDir;
  final String? type;
  final String? status;
  final DateTime? fromDate;
  final DateTime? toDate;

  TableQuery copyWith({
    int? page,
    int? limit,
    String? sortBy,
    String? sortDir,
    String? type,
    String? status,
    DateTime? fromDate,
    DateTime? toDate,
    bool clearType = false,
    bool clearStatus = false,
    bool clearFromDate = false,
    bool clearToDate = false,
  }) {
    return TableQuery(
      page: page ?? this.page,
      limit: limit ?? this.limit,
      sortBy: sortBy ?? this.sortBy,
      sortDir: sortDir ?? this.sortDir,
      type: clearType ? null : (type ?? this.type),
      status: clearStatus ? null : (status ?? this.status),
      fromDate: clearFromDate ? null : (fromDate ?? this.fromDate),
      toDate: clearToDate ? null : (toDate ?? this.toDate),
    );
  }
}

class TableQueryController extends Notifier<TableQuery> {
  @override
  TableQuery build() => const TableQuery();

  void setPage(int page) => state = state.copyWith(page: page);
  void setSort(String col) {
    final next = state.sortBy == col && state.sortDir == 'asc' ? 'desc' : 'asc';
    state = state.copyWith(sortBy: col, sortDir: next, page: 1);
  }

  void setType(String? value) => state = value == null || value.isEmpty
      ? state.copyWith(clearType: true, page: 1)
      : state.copyWith(type: value, page: 1);
  void setStatus(String? value) => state = value == null || value.isEmpty
      ? state.copyWith(clearStatus: true, page: 1)
      : state.copyWith(status: value, page: 1);
  void setRange(DateTime? from, DateTime? to) =>
      state = state.copyWith(fromDate: from, toDate: to, page: 1);
}

final txQueryProvider = NotifierProvider<TableQueryController, TableQuery>(
  TableQueryController.new,
);
final payoutQueryProvider = NotifierProvider<TableQueryController, TableQuery>(
  TableQueryController.new,
);
final reviewQueryProvider = NotifierProvider<TableQueryController, TableQuery>(
  TableQueryController.new,
);
final reconQueryProvider = NotifierProvider<TableQueryController, TableQuery>(
  TableQueryController.new,
);

final adminTransactionsProvider =
    FutureProvider.autoDispose<AdminPage<AdminTxItem>>((ref) async {
      final q = ref.watch(txQueryProvider);
      return ref
          .read(adminFinanceApiProvider)
          .getTransactions(
            page: q.page,
            limit: q.limit,
            type: q.type,
            status: q.status,
            sortBy: q.sortBy,
            sortDir: q.sortDir,
            fromDate: q.fromDate?.toIso8601String(),
            toDate: q.toDate?.toIso8601String(),
          );
    });

final adminPayoutsProvider =
    FutureProvider.autoDispose<AdminPage<AdminPayoutItem>>((ref) async {
      final q = ref.watch(payoutQueryProvider);
      return ref
          .read(adminFinanceApiProvider)
          .getPayouts(page: q.page, limit: q.limit, status: q.status);
    });

final adminReviewsProvider =
    FutureProvider.autoDispose<AdminPage<AdminReviewItem>>((ref) async {
      final q = ref.watch(reviewQueryProvider);
      return ref
          .read(adminFinanceApiProvider)
          .getReviews(page: q.page, limit: q.limit);
    });

final adminReconciliationProvider =
    FutureProvider.autoDispose<AdminPage<AdminReconItem>>((ref) async {
      final q = ref.watch(reconQueryProvider);
      return ref
          .read(adminFinanceApiProvider)
          .getReconciliation(page: q.page, limit: q.limit, status: q.status);
    });

final financeStateProvider = FutureProvider.autoDispose<String>((ref) async {
  ref.watch(adminPollTickProvider);
  return ref.read(adminFinanceApiProvider).getFinanceState();
});

final resolvedAlertTypesProvider = StateProvider.autoDispose<Set<String>>(
  (ref) => <String>{},
);

/// Admin shell tab index (Dashboard=0 … Settings=6). KPI cards set this for drill-down.
final adminShellTabProvider = NotifierProvider<AdminShellTabController, int>(
  AdminShellTabController.new,
);

class AdminShellTabController extends Notifier<int> {
  @override
  int build() => 0;

  void select(int tab) => state = tab;
}

class RowActionState {
  const RowActionState({this.loadingIds = const {}, this.busy = false});
  final Set<String> loadingIds;
  final bool busy;

  RowActionState copyWith({Set<String>? loadingIds, bool? busy}) {
    return RowActionState(
      loadingIds: loadingIds ?? this.loadingIds,
      busy: busy ?? this.busy,
    );
  }
}

class RowActionController extends Notifier<RowActionState> {
  @override
  RowActionState build() => const RowActionState();

  void start(String id) =>
      state = state.copyWith(loadingIds: {...state.loadingIds, id});
  void stop(String id) {
    final next = {...state.loadingIds}..remove(id);
    state = state.copyWith(loadingIds: next);
  }

  void setBusy(bool value) => state = state.copyWith(busy: value);
}

final payoutRowActionProvider =
    NotifierProvider<RowActionController, RowActionState>(
      RowActionController.new,
    );
final reviewRowActionProvider =
    NotifierProvider<RowActionController, RowActionState>(
      RowActionController.new,
    );
final reconRowActionProvider =
    NotifierProvider<RowActionController, RowActionState>(
      RowActionController.new,
    );
