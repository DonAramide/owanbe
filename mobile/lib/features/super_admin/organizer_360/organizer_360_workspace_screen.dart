import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money.dart';
import '../../../eos/eos.dart';
import '../../../eos/layout/workspace/commerce_engine.dart';
import '../../../eos/layout/workspace/entity_engine.dart';
import '../../../eos/layout/workspace/workspace_definition.dart';
import '../../../eos/layout/workspace/workspace_shell.dart';
import '../../../eos/layout/workspace/workspace_widgets.dart';
import '../../../eos/widgets/analytics/eos_time_series_chart.dart';
import 'organizer_intelligence_engine.dart';

class Organizer360WorkspaceScreen extends ConsumerStatefulWidget {
  const Organizer360WorkspaceScreen({super.key, required this.organizerId, this.isOversightMode = true});
  final String organizerId;
  final bool isOversightMode;

  @override
  ConsumerState<Organizer360WorkspaceScreen> createState() => _Organizer360WorkspaceScreenState();
}

class _Organizer360WorkspaceScreenState extends ConsumerState<Organizer360WorkspaceScreen> {
  late WorkspaceDefinition _organizerWorkspaceDefinition;

  @override
  void initState() {
    super.initState();
    _organizerWorkspaceDefinition = WorkspaceDefinition(
      entityType: WorkspaceEntityType.organizer,
      title: widget.isOversightMode ? 'Organizer 360 Oversight' : 'Organizer Mission Control',
      icon: Icons.portrait,
      metrics: const [
        WorkspaceMetricDefinition(
          label: 'Organizer Net Earnings',
          valueResolver: _resolveEarnings,
          subtitle: 'Available available payout',
        ),
      ],
      quickActions: [
        WorkspaceActionDefinition(
          label: 'Create Event',
          icon: Icons.add,
          onPressed: (context, id) async {
            // Action trigger
          },
        ),
        WorkspaceActionDefinition(
          label: 'Disburse Payout',
          icon: Icons.payments_outlined,
          onPressed: (context, id) async {
            // Action trigger
          },
        ),
      ],
      tabs: [
        WorkspaceTabDefinition(
          label: 'Overview',
          builder: (context, id) => _OverviewTabBridge(organizerId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Events Portfolio',
          builder: (context, id) => _PortfolioTabBridge(organizerId: id),
        ),
        WorkspaceTabDefinition(
          label: 'CRM Insights',
          builder: (context, id) => _CRMTabBridge(organizerId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Finance',
          builder: (context, id) => _FinanceTabBridge(organizerId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Vendors Hub',
          builder: (context, id) => _VendorsTabBridge(organizerId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Operations',
          builder: (context, id) => _OperationsTabBridge(organizerId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Timeline',
          builder: (context, id) => _TimelineTabBridge(organizerId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Audit Records',
          builder: (context, id) => _AuditTabBridge(organizerId: id),
        ),
      ],
    );
  }

  static String _resolveEarnings(Map<String, dynamic> d) {
    return '12500000';
  }

  @override
  Widget build(BuildContext context) {
    final ops = OrganizerIntelligenceEngine.resolveOrganizerEntity(widget.organizerId);

    return WorkspaceShell(
      definition: _organizerWorkspaceDefinition,
      entityId: widget.organizerId,
      name: ops.name,
      logoText: 'A',
      healthScore: ops.healthScore,
      environment: widget.isOversightMode ? 'Admin Oversight' : 'Production',
      region: ops.region,
      primaryContact: ops.primaryContact,
      createdDate: ops.createdDate,
      lastActivity: ops.lastActivity,
      sidebarWidgets: [
        WorkspaceHealthPanel(
          healthScore: ops.healthScore,
          factors: ops.factors,
        ),
      ],
    );
  }
}

// ==================== TABS CORRESPONDENCE BRIDGES ====================

class _OverviewTabBridge extends ConsumerWidget {
  const _OverviewTabBridge({required this.organizerId});
  final String organizerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        WorkspaceRelationshipGraph(currentType: WorkspaceEntityType.organizer, entityId: organizerId),
        const SizedBox(height: 24),

        // 1. Digital Twin projections
        Text('Operations & Marketing Scoreboard', style: context.eosText.titleMedium),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildScorecardItem(context, 'Revenue Performance', OrganizerIntelligenceEngine.scorecard.revenueScore),
            const SizedBox(width: 12),
            _buildScorecardItem(context, 'Attendance Rate', OrganizerIntelligenceEngine.scorecard.attendanceScore),
            const SizedBox(width: 12),
            _buildScorecardItem(context, 'Operations SLA', OrganizerIntelligenceEngine.scorecard.operationsScore),
          ],
        ),
        const SizedBox(height: 24),

        // 2. AI Intelligence briefs
        Text('AI Executive Recommendations', style: context.eosText.titleMedium),
        const SizedBox(height: 16),
        const ListTile(
          leading: Icon(Icons.lightbulb_outline, color: Colors.amber),
          title: Text('Weekend VIP ticket demand likely to spike.'),
          subtitle: Text('Confidence: 91% | Recommended: Optimize ticketing configurations'),
        ),
      ],
    );
  }

  Widget _buildScorecardItem(BuildContext context, String label, int score) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.eosColors.surfaceVariant.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.eosColors.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: context.eosText.labelSmall),
            const SizedBox(height: 8),
            Text('$score/100', style: context.eosText.titleMedium?.copyWith(color: score > 90 ? Colors.green : Colors.orange)),
          ],
        ),
      ),
    );
  }
}

class _PortfolioTabBridge extends ConsumerWidget {
  const _PortfolioTabBridge({required this.organizerId});
  final String organizerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Managed Events Portfolio', style: context.eosText.titleMedium),
        const SizedBox(height: 16),
        EosDataTable(
          columns: const [
            DataColumn(label: Text('Event Title')),
            DataColumn(label: Text('Availability')),
            DataColumn(label: Text('Actions')),
          ],
          rows: [
            DataRow(cells: [
              const DataCell(Text('Owambe Staging Gala')),
              DataCell(EosFinanceChip(label: 'ACTIVE', compact: true)),
              DataCell(TextButton(
                onPressed: () => EntityEngine.open(context, ref, 'evt_gala', fallbackType: WorkspaceEntityType.event),
                child: const Text('Open Event 360'),
              )),
            ]),
          ],
        ),
      ],
    );
  }
}

class _CRMTabBridge extends StatelessWidget {
  const _CRMTabBridge({required this.organizerId});
  final String organizerId;

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('CRM Guest Cohort Lists.'));
  }
}

class _FinanceTabBridge extends StatelessWidget {
  const _FinanceTabBridge({required this.organizerId});
  final String organizerId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            Expanded(
              child: EosKpiCard(
                title: 'Available Payout',
                value: formatRevenue(12500000),
                subtitle: 'Disbursable reserves',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: EosKpiCard(
                title: 'Escrow Volume',
                value: formatRevenue(19500000),
                subtitle: 'Held transaction volume',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _VendorsTabBridge extends StatelessWidget {
  const _VendorsTabBridge({required this.organizerId});
  final String organizerId;

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Vendor partner bookings index.'));
  }
}

class _OperationsTabBridge extends StatelessWidget {
  const _OperationsTabBridge({required this.organizerId});
  final String organizerId;

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Operational desk logs.'));
  }
}

class _TimelineTabBridge extends StatelessWidget {
  const _TimelineTabBridge({required this.organizerId});
  final String organizerId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Timeline history stream', style: context.eosText.titleMedium),
        const SizedBox(height: 16),
        WorkspaceTimeline(
          items: [
            WorkspaceTimelineItem(
              title: 'Portfolio updated',
              description: 'Gala parameters updated.',
              timestamp: '2h ago',
              category: 'operations',
              icon: Icons.update,
              iconColor: Colors.blue,
            ),
          ],
        ),
      ],
    );
  }
}

class _AuditTabBridge extends StatelessWidget {
  const _AuditTabBridge({required this.organizerId});
  final String organizerId;

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Organizer change audit logs.'));
  }
}
