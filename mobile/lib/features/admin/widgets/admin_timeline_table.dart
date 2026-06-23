import 'package:flutter/material.dart';

import '../../../eos/eos.dart';

class AdminTimelineTable extends StatelessWidget {
  const AdminTimelineTable({super.key, required this.items});

  final List<AdminTimelineRow> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return EosSurfaceCard(
      elevated: true,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(context.eosColors.surfaceContainerHighest),
            columns: const [
              DataColumn(label: Text('Actor')),
              DataColumn(label: Text('Action')),
              DataColumn(label: Text('Entity')),
              DataColumn(label: Text('Date')),
            ],
            rows: [
              for (final item in items)
                DataRow(
                  cells: [
                    DataCell(Text(item.actor, style: context.eosText.bodyMedium)),
                    DataCell(Text(item.action, style: context.eosText.bodyMedium)),
                    DataCell(Text(item.entity, style: context.eosText.bodySmall)),
                    DataCell(Text(item.date, style: context.eosText.labelSmall)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminTimelineRow {
  const AdminTimelineRow({
    required this.actor,
    required this.action,
    required this.entity,
    required this.date,
  });

  final String actor;
  final String action;
  final String entity;
  final String date;
}

String formatAdminTimestamp(String raw) {
  final dt = DateTime.tryParse(raw);
  if (dt == null) return raw;
  return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

AdminTimelineRow timelineRowFromAudit(Map<String, dynamic> e) {
  return AdminTimelineRow(
    actor: (e['actorEmail'] ?? e['actorId'] ?? 'System').toString(),
    action: (e['action'] ?? '—').toString(),
    entity: '${e['resourceType'] ?? 'resource'} · ${e['resourceId'] ?? ''}',
    date: formatAdminTimestamp((e['timestamp'] ?? '').toString()),
  );
}
