import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../../core/utils/money.dart';
import '../../../eos/eos.dart';
import '../super_admin_providers.dart';

class SuperAdminOverviewScreen extends ConsumerWidget {
  const SuperAdminOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(superAdminOverviewProvider);
    return EosPageScaffold(
      title: 'Platform overview',
      subtitle: 'Executive KPIs across all Owanbe tenants',
      body: overview.when(
        data: (d) {
          final health = (d['platformHealth'] ?? 'healthy').toString();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EosAttentionBanner(
                headline: 'Platform health: ${health.toUpperCase()}',
                message: (d['healthSummary'] ?? '').toString(),
                severity: health == 'critical' ? 'CRITICAL' : health == 'warning' ? 'WARNING' : 'INFO',
              ),
              SizedBox(height: context.eos.spacing.lg),
              Wrap(
                spacing: context.eos.spacing.md,
                runSpacing: context.eos.spacing.md,
                children: [
                  _kpi(context, 'Total events', '${d['totalEvents']}', Icons.celebration_outlined),
                  _kpi(context, 'Organizers', '${d['totalOrganizers']}', Icons.groups_outlined),
                  _kpi(context, 'Vendors', '${d['totalVendors']}', Icons.storefront_outlined),
                  _kpi(context, 'Attendees', '${d['totalAttendees']}', Icons.people_outline),
                  _kpi(context, 'Platform revenue', formatRevenue(int.tryParse((d['platformRevenueMinor'] ?? '0').toString()) ?? 0), Icons.payments_outlined),
                  _kpi(context, 'Platform fees', formatRevenue(int.tryParse((d['platformFeesMinor'] ?? '0').toString()) ?? 0), Icons.account_balance_outlined),
                  _kpi(context, 'Active incidents', '${d['activeIncidents']}', Icons.warning_amber_outlined),
                  _kpi(context, 'Recon issues', '${d['reconciliationIssues']}', Icons.rule_folder_outlined),
                ],
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EosSurfaceCard(child: Text('$e')),
      ),
    );
  }

  Widget _kpi(BuildContext context, String title, String value, IconData icon) {
    return SizedBox(width: 220, child: EosKpiCard(title: title, value: value, icon: icon));
  }
}
