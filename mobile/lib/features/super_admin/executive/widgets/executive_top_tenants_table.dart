import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/money.dart';
import '../../../../eos/eos.dart';
import '../../super_admin_providers.dart';
import '../models/executive_dashboard_models.dart';

class ExecutiveTopTenantsTable extends ConsumerWidget {
  const ExecutiveTopTenantsTable({super.key, required this.rows});

  final List<ExecutiveTenantRow> rows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return EosSection(
      title: 'Top tenants',
      subtitle: 'Ranked by platform revenue',
      child: EosDataTable(
        columns: const [
          DataColumn(label: Text('Tenant')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Events')),
          DataColumn(label: Text('Revenue')),
          DataColumn(label: Text('Growth')),
          DataColumn(label: Text('Health')),
          DataColumn(label: Text('')),
        ],
        rows: [
          for (final r in rows)
            DataRow(
              onSelectChanged: (_) {
                ref.read(selectedSuperAdminTenantIdProvider.notifier).state = r.id;
                ref.read(superAdminShellTabProvider.notifier).select(1);
              },
              cells: [
                DataCell(Text(r.name)),
                DataCell(EosFinanceChip(label: r.status, compact: true)),
                DataCell(Text('${r.eventCount}')),
                DataCell(Text(formatRevenue(r.revenueMinor))),
                DataCell(EosTrendBadge(deltaPercent: r.growthPercent)),
                DataCell(Text(r.health)),
                const DataCell(Icon(Icons.open_in_new, size: 16)),
              ],
            ),
        ],
        emptyMessage: 'No tenants on platform',
      ),
    );
  }
}
