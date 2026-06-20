import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/auth_notifier.dart';
import '../../../auth/auth_session.dart';
import 'organizer_finance_api.dart';
final organizerFinanceApiProvider = Provider<OrganizerFinanceApi>((ref) => OrganizerFinanceApi());

final organizerEventFinanceSummaryProvider =
    FutureProvider.autoDispose.family<OrganizerEventFinanceSummary, String>((ref, eventId) async {
  final session = ref.watch(authSessionProvider);
  return ref.read(organizerFinanceApiProvider).fetchEventSummary(eventId: eventId, session: session);
});

final organizerEventFinanceTransactionsProvider =
    FutureProvider.autoDispose.family<List<OrganizerFinanceTransaction>, String>((ref, eventId) async {
  final session = ref.watch(authSessionProvider);
  return ref.read(organizerFinanceApiProvider).fetchEventTransactions(eventId: eventId, session: session);
});

class OrganizerPayoutState {
  const OrganizerPayoutState({this.loading = false, this.error, this.lastSuccess});

  final bool loading;
  final String? error;
  final OrganizerPayoutResult? lastSuccess;

  OrganizerPayoutState copyWith({
    bool? loading,
    String? error,
    OrganizerPayoutResult? lastSuccess,
  }) {
    return OrganizerPayoutState(
      loading: loading ?? this.loading,
      error: error,
      lastSuccess: lastSuccess ?? this.lastSuccess,
    );
  }
}

class OrganizerPayoutController extends Notifier<OrganizerPayoutState> {
  @override
  OrganizerPayoutState build() => const OrganizerPayoutState();

  Future<void> submit({
    required String organizerId,
    required String amountMinor,
    AuthSession? session,
  }) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final out = await ref
          .read(organizerFinanceApiProvider)
          .createPayout(organizerId: organizerId, amountMinor: amountMinor, session: session);
      state = state.copyWith(loading: false, lastSuccess: out, error: null);
    } on OrganizerFinanceApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }
}

final organizerPayoutControllerProvider =
    NotifierProvider<OrganizerPayoutController, OrganizerPayoutState>(OrganizerPayoutController.new);
