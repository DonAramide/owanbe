import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../auth/auth_notifier.dart';
import '../../../../core/utils/money.dart';
import '../../../../eos/eos.dart';
import '../../finance/organizer_finance_api.dart';
import '../../finance/organizer_finance_providers.dart';
import '../providers/event_command_center_v3_providers.dart';
import '../widgets/cc_v3_finance_charts.dart';
import '../widgets/cc_v3_health_cards.dart';

class FinanceTabV3 extends ConsumerWidget {
  const FinanceTabV3({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapAsync = ref.watch(eventCommandCenterV3Provider(eventId));
    final summary = ref.watch(organizerEventFinanceSummaryProvider(eventId));
    final txs = ref.watch(organizerEventFinanceTransactionsProvider(eventId));

    return snapAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (snap) {
        final chartData = BudgetChartData.fromSnapshot(snap);
        final fin = summary.valueOrNull;

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(eventCommandCenterV3Provider(eventId));
            ref.invalidate(organizerEventFinanceSummaryProvider(eventId));
            ref.invalidate(organizerEventFinanceTransactionsProvider(eventId));
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(context.eos.spacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CcV3BudgetLandscapeChart(data: chartData),
                SizedBox(height: context.eos.spacing.lg),
                CcV3VendorSpendChart(data: chartData),
                SizedBox(height: context.eos.spacing.lg),
                CcV3ExpenseBreakdownChart(data: chartData),
                SizedBox(height: context.eos.spacing.lg),
                const CcV3SectionHeader(
                  title: 'Celebration wallet',
                  subtitle: 'Live balance, releases, and reserves',
                ),
                CcV3HealthCard(
                  title: 'Wallet overview',
                  progressPercent: snap.financial.utilizationPercent,
                  metrics: [
                    CcV3MetricItem(
                      label: 'Budget',
                      value: formatRevenue(snap.financial.budgetMinor),
                    ),
                    CcV3MetricItem(
                      label: 'Balance',
                      value: formatRevenue(
                        fin != null
                            ? int.tryParse(fin.availableForPayoutMinor) ?? snap.financial.walletBalanceMinor
                            : snap.financial.walletBalanceMinor,
                      ),
                    ),
                    CcV3MetricItem(
                      label: 'Vendor spend',
                      value: formatRevenue(chartData.vendorSpendMinor),
                    ),
                    CcV3MetricItem(
                      label: 'Remaining',
                      value: formatRevenue(snap.financial.remainingBudgetMinor),
                    ),
                  ],
                ),
                SizedBox(height: context.eos.spacing.lg),
                for (final insight in snap.financeInsights)
                  Padding(
                    padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                    child: EosAttentionBanner(
                      headline: insight.headline,
                      message: insight.detail,
                      severity: 'INFO',
                    ),
                  ),
                if (summary.hasError)
                  Padding(
                    padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                    child: EosAttentionBanner(
                      headline: 'Wallet API offline',
                      message: 'Charts use your event budget and vendor contracts. Connect finance API for live payouts.',
                      severity: 'INFO',
                    ),
                  ),
                SizedBox(height: context.eos.spacing.lg),
                const CcV3SectionHeader(title: 'Payment timeline'),
                txs.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => EosSurfaceCard(
                    child: Text('Payment history unavailable', style: context.eosText.bodyMedium),
                  ),
                  data: (items) {
                    if (items.isEmpty) {
                      return EosSurfaceCard(
                        child: Text('No payments recorded yet', style: context.eosText.bodyMedium),
                      );
                    }
                    return Column(
                      children: items
                          .map(
                            (t) => Padding(
                              padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                              child: EosSurfaceCard(
                                child: ListTile(
                                  leading: Icon(_txIcon(t.type)),
                                  title: Text(_txLabel(t.type)),
                                  subtitle: Text(
                                    DateTime.fromMillisecondsSinceEpoch(t.timestampMs).toString(),
                                  ),
                                  trailing: Text(formatRevenue(int.tryParse(t.amountMinor) ?? 0)),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
                if (fin != null && fin.payoutEligible && (int.tryParse(fin.availableForPayoutMinor) ?? 0) > 0)
                  Padding(
                    padding: EdgeInsets.only(top: context.eos.spacing.lg),
                    child: FilledButton.icon(
                      onPressed: () => _requestPayout(context, ref, fin),
                      icon: const Icon(Icons.payments_outlined),
                      label: const Text('Request payout'),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _txLabel(String type) => switch (type) {
        'ticket_sale' => 'Ticket sale',
        'platform_fee' => 'Platform fee',
        'payout' => 'Payout',
        'refund_request' => 'Refund',
        'vendor_payment' => 'Vendor payment',
        _ => type,
      };

  IconData _txIcon(String type) => switch (type) {
        'payout' => Icons.payments_outlined,
        'refund_request' => Icons.undo_outlined,
        'vendor_payment' => Icons.storefront_outlined,
        _ => Icons.receipt_long_outlined,
      };

  Future<void> _requestPayout(BuildContext context, WidgetRef ref, OrganizerEventFinanceSummary fin) async {
    final available = int.tryParse(fin.availableForPayoutMinor) ?? 0;
    final session = ref.read(authSessionProvider);
    await ref.read(organizerPayoutControllerProvider.notifier).submit(
          organizerId: fin.organizerId,
          amountMinor: available.toString(),
          session: session,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payout requested')));
  }
}
