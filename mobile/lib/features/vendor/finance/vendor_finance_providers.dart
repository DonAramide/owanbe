import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'vendor_finance_api.dart';
import 'vendor_finance_models.dart';

final vendorFinanceApiProvider = Provider<VendorFinanceApi>((ref) => VendorFinanceApi());

final vendorSummaryProvider = FutureProvider.autoDispose<VendorSummaryResponse>((ref) async {
  return ref.read(vendorFinanceApiProvider).getSummary();
});

final vendorTransactionsProvider = FutureProvider.autoDispose<VendorTransactionsResponse>((ref) async {
  return ref.read(vendorFinanceApiProvider).getTransactions(limit: 100);
});

class WithdrawState {
  const WithdrawState({
    this.loading = false,
    this.error,
    this.lastSuccess,
    this.suggestionsMinor = const [],
  });

  final bool loading;
  final String? error;
  final VendorPayoutResult? lastSuccess;
  final List<String> suggestionsMinor;

  WithdrawState copyWith({
    bool? loading,
    String? error,
    VendorPayoutResult? lastSuccess,
    List<String>? suggestionsMinor,
  }) {
    return WithdrawState(
      loading: loading ?? this.loading,
      error: error,
      lastSuccess: lastSuccess ?? this.lastSuccess,
      suggestionsMinor: suggestionsMinor ?? this.suggestionsMinor,
    );
  }
}

class WithdrawController extends Notifier<WithdrawState> {
  @override
  WithdrawState build() => const WithdrawState();

  Future<void> submit({required String amountMinor}) async {
    state = state.copyWith(loading: true, error: null, suggestionsMinor: const []);
    try {
      final out = await ref.read(vendorFinanceApiProvider).createPayout(amountMinor: amountMinor);
      state = state.copyWith(loading: false, lastSuccess: out, error: null, suggestionsMinor: const []);
    } on VendorFinanceApiException catch (e) {
      state = state.copyWith(
        loading: false,
        error: e.message,
        suggestionsMinor: e.code == 'AMOUNT_NOT_ALLOCATABLE' ? e.suggestionsMinor : const [],
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString(), suggestionsMinor: const []);
    }
  }
}

final withdrawControllerProvider =
    NotifierProvider<WithdrawController, WithdrawState>(WithdrawController.new);
