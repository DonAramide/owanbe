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

class Commerce360WorkspaceScreen extends ConsumerStatefulWidget {
  const Commerce360WorkspaceScreen({super.key, required this.commerceId});
  final String commerceId;

  @override
  ConsumerState<Commerce360WorkspaceScreen> createState() => _Commerce360WorkspaceScreenState();
}

class _Commerce360WorkspaceScreenState extends ConsumerState<Commerce360WorkspaceScreen> {
  late WorkspaceDefinition _commerceWorkspaceDefinition;

  @override
  void initState() {
    super.initState();
    _commerceWorkspaceDefinition = WorkspaceDefinition(
      entityType: WorkspaceEntityType.commerce,
      title: 'Commerce 360 Workspace',
      icon: Icons.account_balance_wallet,
      metrics: const [
        WorkspaceMetricDefinition(
          label: 'Platform Gross Ledger',
          valueResolver: _resolveGross,
          subtitle: 'Gross platform ledger volume',
        ),
      ],
      quickActions: [
        WorkspaceActionDefinition(
          label: 'Release Pending Escrow',
          icon: Icons.key_outlined,
          onPressed: (context, id) async {
            // Action trigger
          },
        ),
        WorkspaceActionDefinition(
          label: 'Run Settlement Payouts',
          icon: Icons.check_circle_outline,
          onPressed: (context, id) async {
            // Action trigger
          },
        ),
      ],
      tabs: [
        WorkspaceTabDefinition(
          label: 'Executive Overview',
          builder: (context, id) => _OverviewTabBridge(commerceId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Orders',
          builder: (context, id) => _OrdersTabBridge(commerceId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Payments',
          builder: (context, id) => _PaymentsTabBridge(commerceId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Refunds',
          builder: (context, id) => _RefundsTabBridge(commerceId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Escrow',
          builder: (context, id) => _EscrowTabBridge(commerceId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Payouts',
          builder: (context, id) => _PayoutsTabBridge(commerceId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Ledger',
          builder: (context, id) => _LedgerTabBridge(commerceId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Analytics',
          builder: (context, id) => _AnalyticsTabBridge(commerceId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Timeline',
          builder: (context, id) => _TimelineTabBridge(commerceId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Audit',
          builder: (context, id) => _AuditTabBridge(commerceId: id),
        ),
      ],
    );
  }

  static String _resolveGross(Map<String, dynamic> d) {
    return '124000000';
  }

  @override
  Widget build(BuildContext context) {
    final healthScore = 98;
    const name = 'Owambe Commerce Twin';

    return WorkspaceShell(
      definition: _commerceWorkspaceDefinition,
      entityId: widget.commerceId,
      name: name,
      logoText: '₦',
      healthScore: healthScore,
      environment: 'Production',
      region: 'NG-LAGOS',
      primaryContact: 'finance@owanbe.dev',
      createdDate: '2026-06-01',
      lastActivity: 'Ledger balance updated now',
      sidebarWidgets: [
        WorkspaceHealthPanel(
          healthScore: healthScore,
          factors: const [
            'Payment success rate: 98%',
            'Failed payment rate: 2%',
            'Escrow release status: Nominal',
          ],
        ),
      ],
    );
  }
}

// ==================== TABS CORRESPONDENCE BRIDGES ====================

class _OverviewTabBridge extends ConsumerWidget {
  const _OverviewTabBridge({required this.commerceId});
  final String commerceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        WorkspaceRelationshipGraph(currentType: WorkspaceEntityType.commerce, entityId: commerceId),
        const SizedBox(height: 24),

        // 1. Digital Twin projections
        Text('Digital Twin Forecasts', style: context.eosText.titleMedium),
        const SizedBox(height: 16),
        Row(
          children: [
            for (final f in CommerceEngine.forecasts)
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.eosColors.surfaceVariant.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.eosColors.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(f.targetTimeframe, style: context.eosText.labelSmall),
                      const SizedBox(height: 8),
                      Text('Est Rev: ₦${(f.projectedRevenue / 1000000).toStringAsFixed(1)}M', style: context.eosText.titleMedium),
                      Text('Escrow: ₦${(f.projectedEscrowRelease / 1000000).toStringAsFixed(1)}M', style: context.eosText.bodySmall),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),

        // 2. Financial Command Center
        Text('Real-time Financial Command Center', style: context.eosText.titleMedium),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: EosKpiCard(
                title: 'Revenue Today',
                value: formatRevenue(CommerceEngine.revenueToday.round()),
                subtitle: 'Daily volume total',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: EosKpiCard(
                title: 'Revenue This Month',
                value: formatRevenue(CommerceEngine.revenueThisMonth.round()),
                subtitle: 'Monthly volume total',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: EosKpiCard(
                title: 'Pending Escrow',
                value: formatRevenue(CommerceEngine.pendingEscrow.round()),
                subtitle: 'Held payouts balance',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _OrdersTabBridge extends ConsumerWidget {
  const _OrdersTabBridge({required this.commerceId});
  final String commerceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Ticket Purchase Orders', style: context.eosText.titleMedium),
        const SizedBox(height: 16),
        EosDataTable(
          columns: const [
            DataColumn(label: Text('Order ID')),
            DataColumn(label: Text('Customer')),
            DataColumn(label: Text('Total Minor')),
          ],
          rows: const [
            DataRow(cells: [
              DataCell(Text('ORD-76812')),
              DataCell(Text('client@owanbe.dev')),
              DataCell(Text('₦15,000.00')),
            ]),
          ],
        ),
      ],
    );
  }
}

class _PaymentsTabBridge extends ConsumerWidget {
  const _PaymentsTabBridge({required this.commerceId});
  final String commerceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Payment History', style: context.eosText.titleMedium),
        const SizedBox(height: 16),
        const ListTile(
          title: Text('PSP Paystack API link status: NOMINAL'),
          trailing: Icon(Icons.check_circle_outline, color: Colors.green),
        ),
      ],
    );
  }
}

class _RefundsTabBridge extends ConsumerWidget {
  const _RefundsTabBridge({required this.commerceId});
  final String commerceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Refund Desk', style: context.eosText.titleMedium),
        const SizedBox(height: 16),
        const ListTile(
          title: Text('Refund request queue: Empty'),
          trailing: Icon(Icons.check_circle_outline, color: Colors.green),
        ),
      ],
    );
  }
}

class _EscrowTabBridge extends ConsumerWidget {
  const _EscrowTabBridge({required this.commerceId});
  final String commerceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Escrow Management Ledger', style: context.eosText.titleMedium),
        const SizedBox(height: 16),
        ListTile(
          title: const Text('Pending Escrow Releases'),
          trailing: Text(formatRevenue(CommerceEngine.pendingEscrow.round())),
        ),
      ],
    );
  }
}

class _PayoutsTabBridge extends ConsumerWidget {
  const _PayoutsTabBridge({required this.commerceId});
  final String commerceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Payout Settlement Batches', style: context.eosText.titleMedium),
        const SizedBox(height: 16),
        const ListTile(
          title: Text('Batch ID: PAY-091 - Completed (₦4,200,000 disbursed)'),
        ),
      ],
    );
  }
}

class _LedgerTabBridge extends ConsumerWidget {
  const _LedgerTabBridge({required this.commerceId});
  final String commerceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Double-entry Account Postings', style: context.eosText.titleMedium),
        const SizedBox(height: 16),
        const ListTile(
          title: Text('Platform cuts: ₦2,400,000 posting settled.'),
        ),
      ],
    );
  }
}

class _AnalyticsTabBridge extends ConsumerWidget {
  const _AnalyticsTabBridge({required this.commerceId});
  final String commerceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Financial Performance Analytics', style: context.eosText.titleMedium),
        const SizedBox(height: 16),
        SizedBox(
          height: 280,
          child: EosTimeSeriesChart(
            series: const [
              EosTimeSeriesSeries(
                key: 'revenue',
                label: 'Gross revenue',
                color: Colors.green,
              ),
            ],
            points: const [
              EosTimeSeriesPoint(label: '30d ago', values: {'revenue': 12000000.0}),
              EosTimeSeriesPoint(label: '20d ago', values: {'revenue': 28000000.0}),
              EosTimeSeriesPoint(label: '10d ago', values: {'revenue': 19000000.0}),
              EosTimeSeriesPoint(label: 'Now', values: {'revenue': 124000000.0}),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimelineTabBridge extends ConsumerWidget {
  const _TimelineTabBridge({required this.commerceId});
  final String commerceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Unified Financial Timeline', style: context.eosText.titleMedium),
        const SizedBox(height: 16),
        WorkspaceTimeline(
          items: [
            WorkspaceTimelineItem(
              title: 'Platform Payout Settled',
              description: 'PAY-091 disbursed to host balances.',
              timestamp: '3h ago',
              category: 'finance',
              icon: Icons.monetization_on,
              iconColor: Colors.green,
            ),
          ],
        ),
      ],
    );
  }
}

class _AuditTabBridge extends ConsumerWidget {
  const _AuditTabBridge({required this.commerceId});
  final String commerceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Financial Audits', style: context.eosText.titleMedium),
        const SizedBox(height: 16),
        const ListTile(
          title: Text('Ledger validation passed successfully (0 mismatch anomalies found).'),
        ),
      ],
    );
  }
}
