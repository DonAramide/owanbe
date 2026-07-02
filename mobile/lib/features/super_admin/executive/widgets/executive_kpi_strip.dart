import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/money.dart';
import '../../../../eos/eos.dart';
import '../../super_admin_providers.dart';
import '../models/executive_dashboard_models.dart';

class ExecutiveKpiStrip extends ConsumerWidget {
  const ExecutiveKpiStrip({super.key, required this.kpis});

  final List<ExecutiveKpi> kpis;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: context.eos.spacing.md,
      runSpacing: context.eos.spacing.md,
      children: [
        for (final k in kpis)
          SizedBox(
            width: 220,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                EosKpiCard(
                  title: k.title,
                  value: k.formatAsMoney ? formatRevenue(k.current.toInt()) : '${k.current}',
                  subtitle: 'Prev: ${k.formatAsMoney ? formatRevenue(k.previous.toInt()) : k.previous}',
                  icon: k.icon,
                  trend: EosTrendBadge(deltaPercent: k.growthPercent, invertColors: k.invertTrend),
                  onTap: k.tabIndex == null ? null : () => ref.read(superAdminShellTabProvider.notifier).select(k.tabIndex!),
                  actionLabel: k.tabIndex != null ? 'View details' : null,
                ),
                Padding(
                  padding: EdgeInsets.only(top: context.eos.spacing.xs),
                  child: EosSparkline(values: k.sparkline, height: 32),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
