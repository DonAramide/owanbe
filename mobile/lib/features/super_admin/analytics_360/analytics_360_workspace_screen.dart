import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../eos/eos.dart';
import '../../../eos/layout/workspace/analytics_engine.dart';
import '../../../eos/layout/workspace/analytics_models.dart';
import '../../../eos/layout/workspace/entity_engine.dart';
import '../../../eos/layout/workspace/prediction_models.dart';
import '../../../eos/layout/workspace/report_definition.dart';
import '../../../eos/layout/workspace/workspace_definition.dart';
import '../../../eos/layout/workspace/workspace_shell.dart';
import '../../../eos/layout/workspace/workspace_widgets.dart';
import '../../../eos/widgets/analytics/eos_time_series_chart.dart';

class Analytics360WorkspaceScreen extends ConsumerStatefulWidget {
  const Analytics360WorkspaceScreen({super.key, required this.analyticsId});
  final String analyticsId;

  @override
  ConsumerState<Analytics360WorkspaceScreen> createState() => _Analytics360WorkspaceScreenState();
}

class _Analytics360WorkspaceScreenState extends ConsumerState<Analytics360WorkspaceScreen> {
  late WorkspaceDefinition _analyticsWorkspaceDefinition;
  TimeRange _selectedTimeRange = TimeRange.last30Days;

  @override
  void initState() {
    super.initState();
    _analyticsWorkspaceDefinition = WorkspaceDefinition(
      entityType: WorkspaceEntityType.analytics,
      title: 'Analytics 360 Workspace',
      icon: Icons.bar_chart,
      metrics: const [
        WorkspaceMetricDefinition(
          label: 'Platform Conversion Rate',
          valueResolver: _resolveConversion,
          subtitle: 'Visits to purchases ratio',
        ),
      ],
      quickActions: [
        WorkspaceActionDefinition(
          label: 'Run Aggregations',
          icon: Icons.play_arrow_outlined,
          onPressed: (context, id) async {
            // Action trigger
          },
        ),
      ],
      tabs: [
        WorkspaceTabDefinition(
          label: 'Overview',
          builder: (context, id) => _OverviewTabBridge(analyticsId: id, selectedRange: _selectedTimeRange),
        ),
        WorkspaceTabDefinition(
          label: 'Revenue',
          builder: (context, id) => _RevenueTabBridge(analyticsId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Growth',
          builder: (context, id) => _GrowthTabBridge(analyticsId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Commerce',
          builder: (context, id) => _CommerceTabBridge(analyticsId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Attendance',
          builder: (context, id) => _AttendanceTabBridge(analyticsId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Funnels',
          builder: (context, id) => _FunnelsTabBridge(analyticsId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Predictive',
          builder: (context, id) => _PredictiveTabBridge(analyticsId: id),
        ),
        WorkspaceTabDefinition(
          label: 'AI Briefings',
          builder: (context, id) => _AiBriefingsTabBridge(analyticsId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Reports',
          builder: (context, id) => _ReportsTabBridge(analyticsId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Settings',
          builder: (context, id) => _SettingsTabBridge(analyticsId: id),
        ),
      ],
    );
  }

  static String _resolveConversion(Map<String, dynamic> d) {
    return '4.8%';
  }

  @override
  Widget build(BuildContext context) {
    final healthScore = 95;
    const name = 'Owambe Analytics Center';

    return WorkspaceShell(
      definition: _analyticsWorkspaceDefinition,
      entityId: widget.analyticsId,
      name: name,
      logoText: '📊',
      healthScore: healthScore,
      environment: 'Production',
      region: 'NG-LAGOS',
      primaryContact: 'bi@owanbe.dev',
      createdDate: '2026-06-01',
      lastActivity: 'Aggregations running now',
      sidebarWidgets: [
        WorkspaceHealthPanel(
          healthScore: healthScore,
          factors: const [
            'Data streams: 100% sync',
            'SLA queries latency: <200ms',
            'AI Insights update index: Optimal',
          ],
        ),
      ],
    );
  }
}

// ==================== TABS CORRESPONDENCE BRIDGES ====================

class _OverviewTabBridge extends ConsumerWidget {
  const _OverviewTabBridge({required this.analyticsId, required this.selectedRange});
  final String analyticsId;
  final TimeRange selectedRange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        WorkspaceRelationshipGraph(currentType: WorkspaceEntityType.analytics, entityId: analyticsId),
        const SizedBox(height: 24),

        // Time Intelligence Selector Status
        Text('Time Intelligence status: ${selectedRange.name.toUpperCase()}', style: context.eosText.labelSmall),
        const SizedBox(height: 16),

        // AI Briefing highlights
        Text('AI Executive Briefings', style: context.eosText.titleMedium),
        const SizedBox(height: 12),
        for (final ins in AnalyticsEngine.insights)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.eosColors.surfaceVariant.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.eosColors.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(ins.title, style: context.eosText.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                    Text(ins.severity, style: TextStyle(color: ins.severity == 'WARNING' ? Colors.orange : Colors.green, fontWeight: FontWeight.bold, fontSize: 10)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(ins.reason, style: context.eosText.bodySmall),
                Text('Rec: ${ins.recommendation}', style: context.eosText.bodySmall?.copyWith(color: Colors.blue)),
              ],
            ),
          ),
      ],
    );
  }
}

class _RevenueTabBridge extends StatelessWidget {
  const _RevenueTabBridge({required this.analyticsId});
  final String analyticsId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Revenue Analytics Intelligence', style: context.eosText.titleMedium),
        const SizedBox(height: 16),
        SizedBox(
          height: 280,
          child: EosTimeSeriesChart(
            series: const [
              EosTimeSeriesSeries(key: 'rev', label: 'Platform Revenue', color: Colors.green),
            ],
            points: const [
              EosTimeSeriesPoint(label: '30d ago', values: {'rev': 12000000.0}),
              EosTimeSeriesPoint(label: '20d ago', values: {'rev': 28000000.0}),
              EosTimeSeriesPoint(label: '10d ago', values: {'rev': 19000000.0}),
              EosTimeSeriesPoint(label: 'Now', values: {'rev': 124000000.0}),
            ],
          ),
        ),
      ],
    );
  }
}

class _GrowthTabBridge extends StatelessWidget {
  const _GrowthTabBridge({required this.analyticsId});
  final String analyticsId;

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Tenant, Organizer, and Vendor growth curves.'));
  }
}

class _CommerceTabBridge extends StatelessWidget {
  const _CommerceTabBridge({required this.analyticsId});
  final String analyticsId;

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Average order values, ticket splits, and escrow latency trends.'));
  }
}

class _AttendanceTabBridge extends StatelessWidget {
  const _AttendanceTabBridge({required this.analyticsId});
  final String analyticsId;

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Active attendees mapping and retention matrices.'));
  }
}

class _FunnelsTabBridge extends StatelessWidget {
  const _FunnelsTabBridge({required this.analyticsId});
  final String analyticsId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Customer Lifecycle Funnel', style: context.eosText.titleMedium),
        const SizedBox(height: 16),
        _buildFunnelStage(context, 'Visitors', '100k views', '100% conversion'),
        _buildArrow(context),
        _buildFunnelStage(context, 'Registrations', '45k users', '45% conversion'),
        _buildArrow(context),
        _buildFunnelStage(context, 'Purchases', '12k orders', '26% conversion'),
        _buildArrow(context),
        _buildFunnelStage(context, 'Attendance', '10.5k checkins', '87% conversion'),
      ],
    );
  }

  Widget _buildFunnelStage(BuildContext context, String stage, String count, String rate) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.eosColors.surfaceVariant.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(stage, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text('$count ($rate)'),
        ],
      ),
    );
  }

  Widget _buildArrow(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8.0),
      child: Center(child: Icon(Icons.arrow_downward, size: 14)),
    );
  }
}

class _PredictiveTabBridge extends StatelessWidget {
  const _PredictiveTabBridge({required this.analyticsId});
  final String analyticsId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('AI Operational Projections', style: context.eosText.titleMedium),
        const SizedBox(height: 16),
        for (final f in AnalyticsEngine.forecasts)
          ListTile(
            title: Text(f.target),
            subtitle: Text(f.prediction),
            trailing: Text('Conf: ${(f.confidence * 100).toStringAsFixed(0)}%'),
          ),
      ],
    );
  }
}

class _AiBriefingsTabBridge extends StatelessWidget {
  const _AiBriefingsTabBridge({required this.analyticsId});
  final String analyticsId;

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Platform-wide AI recommendations logs.'));
  }
}

class _ReportsTabBridge extends StatelessWidget {
  const _ReportsTabBridge({required this.analyticsId});
  final String analyticsId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Executive Reporting Center', style: context.eosText.titleMedium),
        const SizedBox(height: 16),
        for (final rep in AnalyticsEngine.reports)
          ListTile(
            title: Text(rep.title),
            subtitle: Text(rep.description),
            trailing: ElevatedButton(
              onPressed: () {},
              child: const Text('Export PDF'),
            ),
          ),
      ],
    );
  }
}

class _SettingsTabBridge extends StatelessWidget {
  const _SettingsTabBridge({required this.analyticsId});
  final String analyticsId;

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Data extract schedules settings.'));
  }
}
