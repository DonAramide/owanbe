import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/money.dart';
import '../../../eos/eos.dart';
import '../../../eos/layout/workspace/commerce_engine.dart';
import '../../../eos/layout/workspace/entity_engine.dart';
import '../../../eos/layout/workspace/workspace_definition.dart';
import '../../../eos/layout/workspace/workspace_shell.dart';
import '../../../eos/layout/workspace/workspace_widgets.dart';
import '../../../eos/widgets/analytics/eos_time_series_chart.dart';
import '../super_admin_providers.dart';

class PlatformFinanceScreen extends ConsumerStatefulWidget {
  const PlatformFinanceScreen({super.key});

  @override
  ConsumerState<PlatformFinanceScreen> createState() => _PlatformFinanceScreenState();
}

class _PlatformFinanceScreenState extends ConsumerState<PlatformFinanceScreen> {
  String _selectedRange = '30d';
  String _selectedTimelineFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final isMobile = EosResponsive.isMobile(context);
    return EosPageScaffold(
      title: 'Platform Finance',
      subtitle: 'Executive billing center',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Zone 1: Executive Finance Ribbon
          _buildFinanceRibbon(context),
          const SizedBox(height: 24),

          // Zone 2: Revenue Intelligence Charts
          _buildRevenueIntelligence(context),
          const SizedBox(height: 24),

          // Zone 3: Financial Flow (Interactive Waterfall Lifecycle)
          _buildFinancialFlow(context),
          const SizedBox(height: 24),

          // Zone 4 & 5: Financial Operations Center & AI Attention Center
          if (isMobile) ...[
            _buildOperationsCenter(context),
            const SizedBox(height: 20),
            _buildExecutiveIntelligence(context),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 7,
                  child: _buildOperationsCenter(context),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 5,
                  child: _buildExecutiveIntelligence(context),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),

          // Zone 6: Executive Monitoring (Matrix, Timeline, Action Center)
          if (isMobile) ...[
            _buildLiveTimelineAndMap(context),
            const SizedBox(height: 20),
            _buildHealthMatrixAndActions(context),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 7,
                  child: _buildLiveTimelineAndMap(context),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 5,
                  child: _buildHealthMatrixAndActions(context),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFinanceRibbon(BuildContext context) {
    return EosSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Platform Finance Ledger Summary', style: context.eosText.titleMedium),
                TextButton.icon(
                  onPressed: () => context.go('/super-admin/commerce/global'),
                  icon: const Icon(Icons.open_in_new, size: 14),
                  label: const Text('Open Commerce 360'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildRibbonKpi(context, 'Revenue Today', '₦4.2M', '+12%', 'vs yesterday'),
                  _buildRibbonDivider(context),
                  _buildRibbonKpi(context, 'Revenue Month', '₦124.0M', '+18%', 'vs last month'),
                  _buildRibbonDivider(context),
                  _buildRibbonKpi(context, 'GMV', '₦450.0M', '+24%', 'vs prev period'),
                  _buildRibbonDivider(context),
                  _buildRibbonKpi(context, 'Pending Payouts', '₦12.5M', '5 batches', 'SLA nominal'),
                  _buildRibbonDivider(context),
                  _buildRibbonKpi(context, 'Escrow Balance', '₦19.5M', 'Held funds', 'Nominal status'),
                  _buildRibbonDivider(context),
                  _buildRibbonKpi(context, 'Success Rate', '98%', '-0.5%', 'PSP Paystack nominal'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRibbonKpi(BuildContext context, String label, String value, String change, String period) {
    return Container(
      width: 160,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: context.eosText.labelSmall?.copyWith(fontSize: 8)),
          const SizedBox(height: 4),
          Text(value, style: context.eosText.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(change, style: TextStyle(color: change.startsWith('+') ? Colors.green : Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
              const SizedBox(width: 4),
              Text(period, style: context.eosText.bodySmall?.copyWith(fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRibbonDivider(BuildContext context) {
    return Container(height: 36, width: 1, color: context.eosColors.outlineVariant);
  }

  Widget _buildRevenueIntelligence(BuildContext context) {
    return EosSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Revenue & Fees Intelligence', style: context.eosText.titleMedium),
                Row(
                  children: [
                    _buildRangeButton('7d'),
                    const SizedBox(width: 8),
                    _buildRangeButton('30d'),
                    const SizedBox(width: 8),
                    _buildRangeButton('90d'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 280,
              child: EosTimeSeriesChart(
                series: const [
                  EosTimeSeriesSeries(key: 'ticket', label: 'Ticket Commerce', color: Colors.purple),
                  EosTimeSeriesSeries(key: 'booking', label: 'Booking Commerce', color: Colors.blue),
                  EosTimeSeriesSeries(key: 'fees', label: 'Platform Fees', color: Colors.green),
                ],
                points: const [
                  EosTimeSeriesPoint(label: '30d ago', values: {'ticket': 12000000.0, 'booking': 2000000.0, 'fees': 800000.0}),
                  EosTimeSeriesPoint(label: '20d ago', values: {'ticket': 28000000.0, 'booking': 4000000.0, 'fees': 1600000.0}),
                  EosTimeSeriesPoint(label: '10d ago', values: {'ticket': 19000000.0, 'booking': 3000000.0, 'fees': 1200000.0}),
                  EosTimeSeriesPoint(label: 'Now', values: {'ticket': 124000000.0, 'booking': 15000000.0, 'fees': 6200000.0}),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRangeButton(String label) {
    final active = _selectedRange == label;
    return ChoiceChip(
      selected: active,
      label: Text(label),
      onSelected: (_) => setState(() => _selectedRange = label),
    );
  }

  Widget _buildFinancialFlow(BuildContext context) {
    return EosSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Financial Lifecycle Flow', style: context.eosText.titleMedium),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFlowStep(context, 'Ticket Sales', '₦124.0M', '100%'),
                  _buildFlowArrow(context),
                  _buildFlowStep(context, 'Platform Fees', '₦6.2M', '5% cut'),
                  _buildFlowArrow(context),
                  _buildFlowStep(context, 'Held Escrow', '₦19.5M', 'Pending'),
                  _buildFlowArrow(context),
                  _buildFlowStep(context, 'Organizer Payable', '₦94.0M', 'Split complete'),
                  _buildFlowArrow(context),
                  _buildFlowStep(context, 'Vendor Payable', '₦12.5M', 'Split complete'),
                  _buildFlowArrow(context),
                  _buildFlowStep(context, 'Settled payout', '₦106.5M', 'Disbursed'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlowStep(BuildContext context, String label, String amount, String share) {
    return InkWell(
      onTap: () => context.go('/super-admin/commerce/global'),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.eosColors.surfaceVariant.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.eosColors.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: context.eosText.labelSmall),
            const SizedBox(height: 4),
            Text(amount, style: context.eosText.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            Text(share, style: context.eosText.bodySmall?.copyWith(fontSize: 10, color: Colors.green)),
          ],
        ),
      ),
    );
  }

  Widget _buildFlowArrow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Icon(Icons.arrow_forward, color: context.eosColors.outline, size: 14),
    );
  }

  Widget _buildOperationsCenter(BuildContext context) {
    return EosSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Financial Operations Center', style: context.eosText.titleMedium),
            const SizedBox(height: 16),
            EosDataTable(
              columns: const [
                DataColumn(label: Text('Queue Name')),
                DataColumn(label: Text('Pending Count')),
                DataColumn(label: Text('Est. Amount')),
                DataColumn(label: Text('Priority')),
              ],
              rows: [
                _buildQueueRow(context, 'Pending Organizer Payouts', '12', '₦12.5M', 'HIGH', Colors.red),
                _buildQueueRow(context, 'Pending Vendor Payouts', '18', '₦4.8M', 'MEDIUM', Colors.orange),
                _buildQueueRow(context, 'Refund Requests Pending', '5', '₦750K', 'HIGH', Colors.red),
                _buildQueueRow(context, 'Reconciliation Exceptions', '2', '₦120K', 'CRITICAL', Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  DataRow _buildQueueRow(BuildContext context, String name, String count, String amount, String priority, Color pCol) {
    return DataRow(
      cells: [
        DataCell(Text(name, style: const TextStyle(fontWeight: FontWeight.bold))),
        DataCell(Text(count)),
        DataCell(Text(amount)),
        DataCell(Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: pCol.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
          child: Text(priority, style: TextStyle(color: pCol, fontSize: 9, fontWeight: FontWeight.bold)),
        )),
      ],
    );
  }

  Widget _buildExecutiveIntelligence(BuildContext context) {
    return EosSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('AI Commerce Insights', style: context.eosText.titleMedium),
                const Icon(Icons.psychology, color: Colors.purple),
              ],
            ),
            const SizedBox(height: 16),
            _buildAiInsight(
              context,
              'Refund Volume Trend Upward',
              'CRITICAL',
              'Est. impact ₦1.8M platform deviation.',
              'Verify payment success rate configurations.',
            ),
            _buildAiInsight(
              context,
              'Settlement Release Backlog',
              'WARNING',
              'Est. impact 12 hosts payout delays.',
              'Open global escrow release batch drawer.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiInsight(BuildContext context, String title, String severity, String impact, String rec) {
    final color = severity == 'CRITICAL' ? Colors.red : Colors.orange;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.04),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: context.eosText.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                child: Text(severity, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(impact, style: context.eosText.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
          Text(rec, style: context.eosText.bodySmall?.copyWith(color: Colors.blue)),
        ],
      ),
    );
  }

  Widget _buildLiveTimelineAndMap(BuildContext context) {
    return EosSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Live Financial activity timeline', style: context.eosText.titleMedium),
            const SizedBox(height: 16),
            WorkspaceTimeline(
              items: [
                WorkspaceTimelineItem(
                  title: 'Payment Captured',
                  description: 'ORD-76812 (₦15,000) processed Paystack rail.',
                  timestamp: '2m ago',
                  category: 'finance',
                  icon: Icons.check_circle_outline,
                  iconColor: Colors.green,
                ),
                WorkspaceTimelineItem(
                  title: 'Escrow Released',
                  description: 'PAY-091 completed split processing.',
                  timestamp: '2h ago',
                  category: 'finance',
                  icon: Icons.monetization_on,
                  iconColor: Colors.green,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthMatrixAndActions(BuildContext context) {
    return EosSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Executive Action Center', style: context.eosText.titleMedium),
            const SizedBox(height: 16),
            _buildActionItem(context, 'Approve pending refunds', '5 requests', Colors.red),
            _buildActionItem(context, 'Release pending escrow batches', '12 batches', Colors.orange),
            _buildActionItem(context, 'Resolve ledger exceptions', '2 anomalies', Colors.red),
            _buildActionItem(context, 'Investigate Paystack success drop', '1 alarm', Colors.orange),
          ],
        ),
      ),
    );
  }

  Widget _buildActionItem(BuildContext context, String action, String subtitle, Color pCol) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: pCol, width: 4)),
        color: context.eosColors.surfaceVariant.withOpacity(0.2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(action, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(subtitle, style: context.eosText.bodySmall),
            ],
          ),
          const Icon(Icons.arrow_forward_ios, size: 12),
        ],
      ),
    );
  }
}
