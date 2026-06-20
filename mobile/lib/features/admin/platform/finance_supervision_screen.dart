import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money.dart';
import '../../../eos/eos.dart';
import '../finance/admin_finance_providers.dart';
import 'admin_platform_providers.dart';

class FinanceSupervisionScreen extends ConsumerWidget {
  const FinanceSupervisionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(adminPlatformRevisionProvider);
    final supervision = ref.watch(adminFinanceSupervisionProvider);
    return EosPageScaffold(
      title: 'Finance supervision',
      subtitle: 'Unified ticket commerce and booking rails',
      body: supervision.when(
        data: (d) {
          final ticket = d['ticketRail'] as Map<String, dynamic>? ?? {};
          final booking = d['bookingRail'] as Map<String, dynamic>? ?? {};
          final recon = d['reconciliation'] as Map<String, dynamic>? ?? {};
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: context.eos.spacing.md,
                runSpacing: context.eos.spacing.md,
                children: [
                  _kpi(context, 'Total volume', formatRevenue(int.tryParse((d['totalVolumeMinor'] ?? '0').toString()) ?? 0), Icons.account_balance_outlined),
                  _kpi(context, 'Ticket orders', '${ticket['orderCount']}', Icons.confirmation_number_outlined),
                  _kpi(context, 'Booking payments', '${booking['paymentCount']}', Icons.receipt_long_outlined),
                  _kpi(context, 'Open recon', '${recon['openIssues']}', Icons.rule_folder_outlined),
                ],
              ),
              SizedBox(height: context.eos.spacing.xl),
              EosSection(
                title: 'Ticket rail',
                child: EosSurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Volume: ${formatRevenue(int.tryParse((ticket['volumeMinor'] ?? '0').toString()) ?? 0)}', style: context.eosText.bodyMedium),
                      Text('Open refunds: ${ticket['openRefunds']}', style: context.eosText.bodySmall),
                      Text('Pending organizer payouts: ${ticket['pendingOrganizerPayouts']}', style: context.eosText.bodySmall),
                    ],
                  ),
                ),
              ),
              SizedBox(height: context.eos.spacing.lg),
              EosSection(
                title: 'Booking rail',
                child: EosSurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Volume: ${formatRevenue(int.tryParse((booking['volumeMinor'] ?? '0').toString()) ?? 0)}', style: context.eosText.bodyMedium),
                      Text('Pending vendor payouts: ${booking['pendingVendorPayouts']}', style: context.eosText.bodySmall),
                    ],
                  ),
                ),
              ),
              SizedBox(height: context.eos.spacing.xl),
              EosSection(
                title: 'Finance operations',
                subtitle: 'Deep-dive queues',
                child: Wrap(
                  spacing: context.eos.spacing.sm,
                  children: [
                    FilledButton(onPressed: () => ref.read(adminShellTabProvider.notifier).selectFinanceSub(1), child: const Text('Transactions')),
                    FilledButton(onPressed: () => ref.read(adminShellTabProvider.notifier).selectFinanceSub(2), child: const Text('Payouts')),
                    FilledButton(onPressed: () => ref.read(adminShellTabProvider.notifier).selectFinanceSub(3), child: const Text('Under review')),
                    FilledButton(onPressed: () => ref.read(adminShellTabProvider.notifier).selectFinanceSub(4), child: const Text('Reconciliation')),
                    FilledButton(onPressed: () => ref.read(adminShellTabProvider.notifier).selectFinanceSub(5), child: const Text('Disputes')),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('$e'),
      ),
    );
  }

  Widget _kpi(BuildContext context, String title, String value, IconData icon) {
    return SizedBox(width: 220, child: EosKpiCard(title: title, value: value, icon: icon));
  }
}
