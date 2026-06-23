import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money.dart';
import '../../../eos/eos.dart';
import '../finance/admin_finance_models.dart';
import '../finance/admin_finance_providers.dart';
import '../finance/admin_payouts_screen.dart';
import '../finance/admin_reconciliation_screen.dart';
import '../finance/admin_review_screen.dart';
import '../finance/admin_transactions_screen.dart';
import '../platform/admin_platform_providers.dart';
import '../widgets/admin_async_body.dart';
import '../widgets/admin_error_states.dart';
import '../widgets/admin_line_chart.dart';
import '../widgets/admin_page_layout.dart';
import '../../disputes/admin_disputes_screen.dart';

class AdminFinanceScreen extends ConsumerWidget {
  const AdminFinanceScreen({super.key, this.subView});

  /// 1=transactions, 2=payouts, 3=review, 4=reconciliation, 5=disputes
  final int? subView;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (subView != null) {
      return switch (subView) {
        1 => const AdminTransactionsScreen(),
        2 => const AdminPayoutsScreen(),
        3 => const AdminReviewScreen(),
        4 => const AdminReconciliationScreen(),
        5 => const AdminDisputesScreen(),
        _ => const AdminFinanceScreen(),
      };
    }

    ref.watch(adminPlatformRevisionProvider);
    final supervision = ref.watch(adminFinanceSupervisionProvider);
    final summary = ref.watch(adminSummaryProvider);
    final transactions = ref.watch(adminTransactionsProvider);
    final vendors = ref.watch(adminVendorsProvider(''));

    return AdminPageLayout(
      title: 'Finance',
      subtitle: 'Revenue, settlements, payouts, and vendor exposure',
      header: Wrap(
        spacing: EosSpacing.sm,
        runSpacing: EosSpacing.sm,
        children: [
          OutlinedButton(onPressed: () => ref.read(adminShellTabProvider.notifier).selectFinanceSub(1), child: const Text('Transactions')),
          OutlinedButton(onPressed: () => ref.read(adminShellTabProvider.notifier).selectFinanceSub(2), child: const Text('Payouts')),
          OutlinedButton(onPressed: () => ref.read(adminShellTabProvider.notifier).selectFinanceSub(3), child: const Text('Under review')),
          OutlinedButton(onPressed: () => ref.read(adminShellTabProvider.notifier).selectFinanceSub(4), child: const Text('Reconciliation')),
          OutlinedButton(onPressed: () => ref.read(adminShellTabProvider.notifier).selectFinanceSub(5), child: const Text('Disputes')),
        ],
      ),
      body: AdminAsyncBody(
        value: supervision,
        onRetry: () => ref.invalidate(adminFinanceSupervisionProvider),
        skeletonCount: 4,
        builder: (d) {
          final ticket = d['ticketRail'] as Map<String, dynamic>? ?? {};
          final booking = d['bookingRail'] as Map<String, dynamic>? ?? {};
          final recon = d['reconciliation'] as Map<String, dynamic>? ?? {};
          final totalVolume = int.tryParse((d['totalVolumeMinor'] ?? '0').toString()) ?? 0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AdminKpiGrid(
                children: [
                  _financeCard(context, 'Revenue', formatRevenue(totalVolume), Icons.trending_up),
                  _financeCard(context, 'Settlement', formatRevenue(int.tryParse((ticket['volumeMinor'] ?? '0').toString()) ?? 0), Icons.account_balance_wallet_outlined),
                  _financeCard(context, 'Payouts pending', '${ticket['pendingOrganizerPayouts'] ?? 0} + ${booking['pendingVendorPayouts'] ?? 0}', Icons.payments_outlined),
                  _financeCard(context, 'Chargebacks / recon', '${recon['openIssues'] ?? 0} open', Icons.rule_folder_outlined),
                ],
              ),
              SizedBox(height: context.eos.spacing.xl),
              summary.when(
                data: (s) => AdminLineChart(
                  label: 'Finance trend',
                  points: syntheticTrend(int.tryParse(s.totalVolumeMinor) ?? totalVolume),
                  color: const Color(0xFF0D9488),
                ),
                loading: () => const AdminLoadingSkeleton(cardCount: 1),
                error: (_, _) => AdminLineChart(label: 'Finance trend', points: syntheticTrend(totalVolume)),
              ),
              SizedBox(height: context.eos.spacing.xl),
              AdminSectionHeader(title: 'Recent transactions', subtitle: 'Latest ledger activity'),
              AdminAsyncBody(
                value: transactions,
                onRetry: () => ref.invalidate(adminTransactionsProvider),
                skeletonCount: 1,
                isEmpty: (page) => page.items.isEmpty,
                empty: const EmptyStateCard(title: 'No transactions yet'),
                builder: (page) => _TransactionsTable(items: page.items.take(10).toList()),
              ),
              SizedBox(height: context.eos.spacing.xl),
              AdminSectionHeader(title: 'Vendor exposure', subtitle: 'Top vendors by platform activity'),
              AdminAsyncBody(
                value: vendors,
                skeletonCount: 1,
                isEmpty: (items) => items.isEmpty,
                empty: const EmptyStateCard(title: 'No vendor exposure data'),
                builder: (items) => _VendorExposureTable(vendors: items.take(10).toList()),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _financeCard(BuildContext context, String title, String value, IconData icon) {
    return EosKpiCard(title: title, value: value, icon: icon);
  }
}

class _TransactionsTable extends StatelessWidget {
  const _TransactionsTable({required this.items});

  final List<AdminTxItem> items;

  @override
  Widget build(BuildContext context) {
    return EosSurfaceCard(
      elevated: true,
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Type')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Amount')),
            DataColumn(label: Text('Created')),
          ],
          rows: [
            for (final t in items)
              DataRow(cells: [
                DataCell(Text(t.type)),
                DataCell(Text(t.status)),
                DataCell(Text(formatRevenue(int.tryParse(t.amountMinor) ?? t.amount))),
                DataCell(Text(t.createdAt.toIso8601String().substring(0, 16))),
              ]),
          ],
        ),
      ),
    );
  }
}

class _VendorExposureTable extends StatelessWidget {
  const _VendorExposureTable({required this.vendors});

  final List<Map<String, dynamic>> vendors;

  @override
  Widget build(BuildContext context) {
    return EosSurfaceCard(
      elevated: true,
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Vendor')),
            DataColumn(label: Text('Category')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Orders')),
          ],
          rows: [
            for (final v in vendors)
              DataRow(cells: [
                DataCell(Text(v['businessName'] as String? ?? '')),
                DataCell(Text(v['category'] as String? ?? '')),
                DataCell(Text(v['status'] as String? ?? '')),
                DataCell(Text('${v['ordersCount'] ?? 0}')),
              ]),
          ],
        ),
      ),
    );
  }
}
