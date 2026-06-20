import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money.dart';
import '../../../eos/eos.dart';
import 'admin_platform_providers.dart';

class PlatformDashboardScreen extends ConsumerWidget {
  const PlatformDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(adminPlatformRevisionProvider);
    final dash = ref.watch(platformDashboardProvider);
    return EosPageScaffold(
      title: 'Platform dashboard',
      subtitle: 'Executive operational KPIs across Owanbe',
      body: dash.when(
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
                  _kpi(context, 'Active events', '${d['activeEvents']}', Icons.celebration_outlined),
                  _kpi(context, 'Live events', '${d['liveEvents']}', Icons.sensors, attention: (d['liveEvents'] as num? ?? 0) > 0 ? EosKpiAttention.info : EosKpiAttention.none),
                  _kpi(context, 'Organizers', '${d['organizers']}', Icons.groups_outlined),
                  _kpi(context, 'Vendors', '${d['vendors']}', Icons.storefront_outlined),
                  _kpi(context, 'Attendees', '${d['attendees']}', Icons.people_outline),
                  _kpi(context, 'Revenue', formatRevenue(int.tryParse((d['revenueMinor'] ?? '0').toString()) ?? 0), Icons.payments_outlined),
                  _kpi(context, 'Open incidents', '${d['openIncidents']}', Icons.warning_amber_outlined, attention: (d['openIncidents'] as num? ?? 0) > 0 ? EosKpiAttention.warning : EosKpiAttention.none),
                  _kpi(context, 'Recon issues', '${d['reconciliationIssues']}', Icons.rule_folder_outlined, attention: (d['reconciliationIssues'] as num? ?? 0) > 0 ? EosKpiAttention.warning : EosKpiAttention.none),
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

  Widget _kpi(BuildContext context, String title, String value, IconData icon, {EosKpiAttention attention = EosKpiAttention.none}) {
    return SizedBox(
      width: 240,
      child: EosKpiCard(title: title, value: value, icon: icon, attention: attention),
    );
  }
}
