import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/money.dart';
import '../../../../eos/eos.dart';
import '../../super_admin_providers.dart';
import '../models/executive_dashboard_models.dart';

class ExecutiveTopEventsTable extends ConsumerWidget {
  const ExecutiveTopEventsTable({super.key, required this.rows});

  final List<ExecutiveEventRow> rows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return EosSection(
      title: 'Top events',
      subtitle: 'Most active by ticket revenue',
      child: EosDataTable(
        columns: const [
          DataColumn(label: Text('Event')),
          DataColumn(label: Text('Tenant')),
          DataColumn(label: Text('Revenue')),
          DataColumn(label: Text('Status')),
        ],
        rows: [
          for (final r in rows)
            DataRow(
              onSelectChanged: (_) => ref.read(superAdminShellTabProvider.notifier).select(1),
              cells: [
                DataCell(Text(r.title)),
                DataCell(Text(r.tenantName)),
                DataCell(Text(formatRevenue(r.revenueMinor))),
                DataCell(EosEventStatusBadge(status: r.status)),
              ],
            ),
        ],
        emptyMessage: 'No events with revenue data',
      ),
    );
  }
}

class ExecutiveTopOrganizersTable extends ConsumerWidget {
  const ExecutiveTopOrganizersTable({super.key, required this.rows});

  final List<ExecutiveOrganizerRow> rows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return EosSection(
      title: 'Top organizers',
      subtitle: 'Leaderboard by ticket commerce',
      child: EosDataTable(
        columns: const [
          DataColumn(label: Text('Organizer')),
          DataColumn(label: Text('Tenant')),
          DataColumn(label: Text('Revenue')),
          DataColumn(label: Text('Events')),
          DataColumn(label: Text('Growth')),
          DataColumn(label: Text('Status')),
        ],
        rows: [
          for (final r in rows)
            DataRow(
              onSelectChanged: (_) => ref.read(superAdminShellTabProvider.notifier).select(1),
              cells: [
                DataCell(Text(r.name)),
                DataCell(Text(r.tenantName)),
                DataCell(Text(formatRevenue(r.revenueMinor))),
                DataCell(Text('${r.eventCount}')),
                DataCell(EosTrendBadge(deltaPercent: r.growthPercent)),
                DataCell(EosFinanceChip(label: r.status, compact: true)),
              ],
            ),
        ],
        emptyMessage: 'No organizer revenue data',
      ),
    );
  }
}
