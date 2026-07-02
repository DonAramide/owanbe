import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../eos/eos.dart';
import '../../../eos/layout/workspace/entity_engine.dart';
import '../../../eos/layout/workspace/workspace_definition.dart';
import '../../../eos/layout/workspace/workspace_shell.dart';
import '../../../eos/layout/workspace/workspace_widgets.dart';

class Incident360WorkspaceScreen extends ConsumerStatefulWidget {
  const Incident360WorkspaceScreen({super.key, required this.incidentId});
  final String incidentId;

  @override
  ConsumerState<Incident360WorkspaceScreen> createState() => _Incident360WorkspaceScreenState();
}

class _Incident360WorkspaceScreenState extends ConsumerState<Incident360WorkspaceScreen> {
  late WorkspaceDefinition _incidentWorkspaceDefinition;
  String _incidentStatus = 'INVESTIGATING';

  @override
  void initState() {
    super.initState();
    _incidentWorkspaceDefinition = WorkspaceDefinition(
      entityType: WorkspaceEntityType.incident,
      title: 'Incident 360 Workspace',
      icon: Icons.error_outline,
      metrics: const [
        WorkspaceMetricDefinition(
          label: 'Duration (m)',
          valueResolver: _resolveDuration,
          subtitle: 'Active incident lifetime total',
        ),
      ],
      quickActions: [
        WorkspaceActionDefinition(
          label: 'Resolve Incident',
          icon: Icons.check_circle_outline,
          onPressed: (context, id) async {
            setState(() {
              _incidentStatus = 'RESOLVED';
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Incident $id has been resolved.')),
            );
          },
        ),
      ],
      tabs: [
        WorkspaceTabDefinition(
          label: 'Summary',
          builder: (context, id) => _SummaryTabBridge(incidentId: id, status: _incidentStatus),
        ),
        WorkspaceTabDefinition(
          label: 'Timeline',
          builder: (context, id) => _TimelineTabBridge(incidentId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Root Cause',
          builder: (context, id) => _RootCauseTabBridge(incidentId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Services',
          builder: (context, id) => _ServicesTabBridge(incidentId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Affected Users',
          builder: (context, id) => _AffectedUsersTabBridge(incidentId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Affected Tenants',
          builder: (context, id) => _AffectedTenantsTabBridge(incidentId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Logs',
          builder: (context, id) => _LogsTabBridge(incidentId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Evidence',
          builder: (context, id) => _EvidenceTabBridge(incidentId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Runbook',
          builder: (context, id) => _RunbookTabBridge(incidentId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Resolution',
          builder: (context, id) => _ResolutionTabBridge(incidentId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Audit',
          builder: (context, id) => _AuditTabBridge(incidentId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Relationships',
          builder: (context, id) => _RelationshipsTabBridge(incidentId: id),
        ),
      ],
    );
  }

  static String _resolveDuration(Map<String, dynamic> d) {
    return '14';
  }

  @override
  Widget build(BuildContext context) {
    final name = 'INC-891: DB Secondary Replica Latency';
    return WorkspaceShell(
      definition: _incidentWorkspaceDefinition,
      entityId: widget.incidentId,
      name: name,
      logoText: 'I',
      healthScore: _incidentStatus == 'RESOLVED' ? 100 : 45,
      environment: 'Production',
      region: 'NG-LAGOS',
      primaryContact: 'oncall@owanbe.dev',
      createdDate: '2026-06-28',
      lastActivity: 'Incident status: $_incidentStatus',
      sidebarWidgets: [
        WorkspaceHealthPanel(
          healthScore: _incidentStatus == 'RESOLVED' ? 100 : 45,
          factors: [
            'Severity: CRITICAL',
            'Affected Service: DB REPLICA',
            'Status: $_incidentStatus',
          ],
        ),
      ],
    );
  }
}

// ==================== INCIDENT TAB BRIDGES ====================

class _SummaryTabBridge extends StatelessWidget {
  const _SummaryTabBridge({required this.incidentId, required this.status});
  final String incidentId;
  final String status;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        EosSurfaceCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Active Incident Details', style: context.eosText.titleMedium),
                const Divider(height: 24),
                _buildField(context, 'Incident ID', incidentId),
                _buildField(context, 'Title', 'DB secondary node latency spikes causing read exceptions'),
                _buildField(context, 'Status', status),
                _buildField(context, 'Severity', 'CRITICAL / P0'),
                _buildField(context, 'Assignee', 'On-Call Engineer (Platform Ops)'),
                _buildField(context, 'SLA SLA Target', '4 Hours'),
                _buildField(context, 'Trigger Time', '2026-06-29 00:15:00'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildField(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Text('$label: ', style: context.eosText.labelMedium),
          Text(value, style: context.eosText.bodyMedium),
        ],
      ),
    );
  }
}

class _TimelineTabBridge extends StatelessWidget {
  const _TimelineTabBridge({required this.incidentId});
  final String incidentId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        WorkspaceTimeline(
          items: [
            WorkspaceTimelineItem(
              title: 'Incident Flagged',
              description: 'Auto paging system triggered to on-call engineer',
              timestamp: '14m ago',
              category: 'operations',
              icon: Icons.notifications_active,
              iconColor: Colors.red,
            ),
            WorkspaceTimelineItem(
              title: 'Anomaly Detected',
              description: 'DB Read Latency exceeded 1200ms threshold',
              timestamp: '20m ago',
              category: 'infrastructure',
              icon: Icons.warning,
              iconColor: Colors.orange,
            ),
          ],
        ),
      ],
    );
  }
}

class _RootCauseTabBridge extends StatelessWidget {
  const _RootCauseTabBridge({required this.incidentId});
  final String incidentId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        EosSurfaceCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Post-Mortem Root Cause Analysis', style: context.eosText.titleMedium),
                const Divider(height: 24),
                Text(
                  'Root Cause:\nSecondary database replica node ran out of ephemeral disk space due to unrotated temporary backup files, causing system queries to fall back to the primary and stall.',
                  style: context.eosText.bodyMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  'Prevention Action:\nConfigure automated disk alerts at 85% occupancy and auto-rotate temporary backup artifacts.',
                  style: context.eosText.bodySmall?.copyWith(color: Colors.blue),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ServicesTabBridge extends StatelessWidget {
  const _ServicesTabBridge({required this.incidentId});
  final String incidentId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        EosDataTable(
          columns: const [
            DataColumn(label: Text('Service')),
            DataColumn(label: Text('Tier')),
            DataColumn(label: Text('Type')),
            DataColumn(label: Text('Impact Level')),
          ],
          rows: const [
            DataRow(cells: [
              DataCell(Text('booking-db-replica')),
              DataCell(Text('Tier 0')),
              DataCell(Text('PostgreSQL Database')),
              DataCell(Text('HIGH - Secondary Stalled')),
            ]),
          ],
        ),
      ],
    );
  }
}

class _AffectedUsersTabBridge extends ConsumerWidget {
  const _AffectedUsersTabBridge({required this.incidentId});
  final String incidentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        EosDataTable(
          columns: const [
            DataColumn(label: Text('User ID')),
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Impacted Requests')),
            DataColumn(label: Text('Actions')),
          ],
          rows: [
            DataRow(cells: [
              const DataCell(Text('usr_1')),
              const DataCell(Text('Adenike Adebayo')),
              const DataCell(Text('12 read errors')),
              DataCell(TextButton(
                onPressed: () => EntityEngine.open(context, ref, 'usr_1', fallbackType: WorkspaceEntityType.user),
                child: const Text('Open User360'),
              )),
            ]),
          ],
        ),
      ],
    );
  }
}

class _AffectedTenantsTabBridge extends ConsumerWidget {
  const _AffectedTenantsTabBridge({required this.incidentId});
  final String incidentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        EosDataTable(
          columns: const [
            DataColumn(label: Text('Tenant ID')),
            DataColumn(label: Text('Tenant Name')),
            DataColumn(label: Text('Tier')),
            DataColumn(label: Text('Actions')),
          ],
          rows: [
            DataRow(cells: [
              const DataCell(Text('tenant_1')),
              const DataCell(Text('Gate Tenant Enterprise')),
              const DataCell(Text('Platinum')),
              DataCell(TextButton(
                onPressed: () => EntityEngine.open(context, ref, 'tenant_1', fallbackType: WorkspaceEntityType.tenant),
                child: const Text('Open Tenant360'),
              )),
            ]),
          ],
        ),
      ],
    );
  }
}

class _LogsTabBridge extends StatelessWidget {
  const _LogsTabBridge({required this.incidentId});
  final String incidentId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        EosSurfaceCard(
          child: Container(
            padding: const EdgeInsets.all(12),
            color: Colors.black,
            child: const Text(
              '2026-06-29 00:14:02.891 ERROR: [PostgresConnection] connection refused: no space left on device\n2026-06-29 00:14:04.102 FATAL: [ReplicaSynchronization] replication connection lost\n2026-06-29 00:15:00.000 WARN: [OpsTrigger] starting incident pager INC-891',
              style: TextStyle(color: Colors.lightGreen, fontFamily: 'monospace', fontSize: 11),
            ),
          ),
        ),
      ],
    );
  }
}

class _EvidenceTabBridge extends StatelessWidget {
  const _EvidenceTabBridge({required this.incidentId});
  final String incidentId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        EosSurfaceCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Incident Evidence Artifacts', style: context.eosText.titleMedium),
                const Divider(height: 24),
                const Text('1. Disk usage metric trace snapshot: booking-db-replica-disk.png (Hash: 8a9cf291)'),
                const Text('2. Replica heartbeat log export: database_heartbeat_error.json'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RunbookTabBridge extends StatelessWidget {
  const _RunbookTabBridge({required this.incidentId});
  final String incidentId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        EosSurfaceCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Active Runbook: [DB-REPLICA-DISK-FULL]', style: context.eosText.titleMedium),
                const Divider(height: 24),
                const Text('Step 1: Terminate unrotated diagnostic backups on node.\nStep 2: Run disk clean script via platform command interface.\nStep 3: Force replication resync command.'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ResolutionTabBridge extends StatelessWidget {
  const _ResolutionTabBridge({required this.incidentId});
  final String incidentId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        EosSurfaceCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mitigation & Resolution Summary', style: context.eosText.titleMedium),
                const Divider(height: 24),
                const Text('Resolved via Disk cleaning script & log partition rotation on PG nodes. Verified that health index restored to 100% and replica latency dropped below 15ms.'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AuditTabBridge extends StatelessWidget {
  const _AuditTabBridge({required this.incidentId});
  final String incidentId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        EosDataTable(
          columns: const [
            DataColumn(label: Text('Action')),
            DataColumn(label: Text('Operator')),
            DataColumn(label: Text('Timestamp')),
          ],
          rows: const [
            DataRow(cells: [
              DataCell(Text('Assigned to On-Call')),
              DataCell(Text('System AutoPager')),
              DataCell(Text('2026-06-29 00:15')),
            ]),
          ],
        ),
      ],
    );
  }
}

class _RelationshipsTabBridge extends ConsumerWidget {
  const _RelationshipsTabBridge({required this.incidentId});
  final String incidentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        WorkspaceRelationshipGraph(currentType: WorkspaceEntityType.incident, entityId: incidentId),
      ],
    );
  }
}
