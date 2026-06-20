import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money.dart';
import '../../../eos/eos.dart';
import '../super_admin_providers.dart';

class PlatformFinanceScreen extends ConsumerWidget {
  const PlatformFinanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finance = ref.watch(superAdminFinanceProvider);
    return EosPageScaffold(
      title: 'Platform finance',
      subtitle: 'Cross-tenant ticket and booking commerce',
      body: finance.when(
        data: (d) {
          final summary = d['summary'] as Map<String, dynamic>? ?? {};
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: context.eos.spacing.md,
                runSpacing: context.eos.spacing.md,
                children: [
                  _kpi(context, 'Ticket revenue', formatRevenue(int.tryParse((summary['ticketRevenueMinor'] ?? '0').toString()) ?? 0), Icons.confirmation_number_outlined),
                  _kpi(context, 'Booking revenue', formatRevenue(int.tryParse((summary['bookingRevenueMinor'] ?? '0').toString()) ?? 0), Icons.receipt_long_outlined),
                  _kpi(context, 'Platform fees', formatRevenue(int.tryParse((summary['platformFeesMinor'] ?? '0').toString()) ?? 0), Icons.account_balance_outlined),
                  _kpi(context, 'Refund volume', formatRevenue(int.tryParse((summary['refundVolumeMinor'] ?? '0').toString()) ?? 0), Icons.undo_outlined),
                  _kpi(context, 'Payout volume', formatRevenue(int.tryParse((summary['payoutVolumeMinor'] ?? '0').toString()) ?? 0), Icons.payments_outlined),
                ],
              ),
              SizedBox(height: context.eos.spacing.xl),
              EosSection(
                title: 'Drill-down',
                subtitle: 'Tenant · Event · Organizer · Vendor via API query params',
                child: EosSurfaceCard(
                  child: Text('Use finance API with drill=tenant|event|organizer|vendor and drillId', style: context.eosText.bodySmall),
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
