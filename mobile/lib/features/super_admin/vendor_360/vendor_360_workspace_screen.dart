import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../eos/eos.dart';
import '../../../eos/layout/workspace/workspace_definition.dart';
import '../../../eos/layout/workspace/workspace_shell.dart';
import '../../../eos/layout/workspace/workspace_widgets.dart';
import '../../vendor/providers/vendor_intelligence_engine.dart';

class Vendor360WorkspaceScreen extends ConsumerStatefulWidget {
  const Vendor360WorkspaceScreen({super.key, required this.vendorId});
  final String vendorId;

  @override
  ConsumerState<Vendor360WorkspaceScreen> createState() => _Vendor360WorkspaceScreenState();
}

class _Vendor360WorkspaceScreenState extends ConsumerState<Vendor360WorkspaceScreen> {
  late WorkspaceDefinition _vendorWorkspaceDefinition;
  String _currentStatus = 'Active';

  @override
  void initState() {
    super.initState();
    _vendorWorkspaceDefinition = WorkspaceDefinition(
      entityType: WorkspaceEntityType.vendor,
      title: 'Vendor Operating Workspace 360',
      icon: Icons.handshake_outlined,
      metrics: [
        WorkspaceMetricDefinition(
          label: 'Health Index',
          valueResolver: (d) => '92%',
          subtitle: 'System heartbeat',
        ),
        WorkspaceMetricDefinition(
          label: 'SLA Score',
          valueResolver: (d) => '99.2%',
          subtitle: 'Fulfillment compliance',
        ),
      ],
      quickActions: [
        WorkspaceActionDefinition(
          label: 'Approve Listing',
          icon: Icons.check_circle_outline,
          onPressed: (context, id) async {
            setState(() {
              _currentStatus = 'Approved';
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Vendor service listing approved.')),
            );
          },
        ),
        WorkspaceActionDefinition(
          label: 'Suspend Vendor',
          icon: Icons.block,
          onPressed: (context, id) async {
            setState(() {
              _currentStatus = 'Suspended';
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Vendor profile suspended successfully.')),
            );
          },
        ),
      ],
      tabs: [
        WorkspaceTabDefinition(
          label: 'Overview',
          builder: (context, id) => _OverviewTab(vendorId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Active Events',
          builder: (context, id) => _ActiveEventsTab(vendorId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Conversations',
          builder: (context, id) => _ConversationsTab(vendorId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Negotiations',
          builder: (context, id) => _NegotiationsTab(vendorId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Contracts',
          builder: (context, id) => _ContractsTab(vendorId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Finance',
          builder: (context, id) => _FinanceTab(vendorId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Inventory',
          builder: (context, id) => _InventoryTab(vendorId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Calendar',
          builder: (context, id) => _CalendarTab(vendorId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Customers (CRM)',
          builder: (context, id) => _CustomersTab(vendorId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Performance',
          builder: (context, id) => _PerformanceTab(vendorId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Timeline',
          builder: (context, id) => _TimelineTab(vendorId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Audit',
          builder: (context, id) => _AuditTab(vendorId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Settings',
          builder: (context, id) => _SettingsTab(vendorId: id),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final intel = ref.watch(vendorIntelligenceProvider);

    return WorkspaceShell(
      definition: _vendorWorkspaceDefinition,
      entityId: widget.vendorId,
      name: 'Jollof & Co Catering Ltd',
      logoText: 'V',
      healthScore: intel.healthScore,
      environment: 'Production',
      region: 'NG-LAGOS',
      primaryContact: 'info@jollofandco.owanbe',
      createdDate: '2026-06-01',
      lastActivity: 'Workspace synced now',
      sidebarWidgets: [
        WorkspaceHealthPanel(
          healthScore: intel.healthScore,
          factors: [
            'CAC Registration: VERIFIED',
            'SLA rating index: Optimal',
            'Risk Score: ${intel.riskScore} (Low)',
            'Status: $_currentStatus',
          ],
        ),
      ],
    );
  }
}

// ==================== OPERATIONAL TABS ====================

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab({required this.vendorId});
  final String vendorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final intel = ref.watch(vendorIntelligenceProvider);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        WorkspaceRelationshipGraph(currentType: WorkspaceEntityType.vendor, entityId: vendorId),
        const SizedBox(height: 24),
        EosSurfaceCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Vendor Profile Assessment', style: context.eosText.titleMedium),
                const SizedBox(height: 12),
                Text('Business Health Score: ${intel.healthScore}%'),
                Text('SLA Performance: ${intel.slaCompliance}%'),
                Text('Customer Rating: ${intel.performanceScore} / 5.0'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ActiveEventsTab extends StatelessWidget {
  const _ActiveEventsTab({required this.vendorId});
  final String vendorId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        EosSurfaceCard(
          child: ListTile(
            leading: const Icon(Icons.celebration, color: EosColors.plum),
            title: const Text('Wale & Shade Wedding Feast'),
            subtitle: const Text('Lagos Oriental Hotel • Today at 12 PM'),
            trailing: TextButton(onPressed: () {}, child: const Text('View')),
          ),
        ),
      ],
    );
  }
}

class _ConversationsTab extends StatelessWidget {
  const _ConversationsTab({required this.vendorId});
  final String vendorId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        EosSurfaceCard(
          child: const ListTile(
            leading: Icon(Icons.chat_outlined, color: EosColors.plum),
            title: Text('Segun (Organizer)'),
            subtitle: Text('Arrival confirmed at Lagos Oriental Hotel'),
          ),
        ),
      ],
    );
  }
}

class _NegotiationsTab extends ConsumerWidget {
  const _NegotiationsTab({required this.vendorId});
  final String vendorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final intel = ref.watch(vendorIntelligenceProvider);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        for (final n in intel.negotiations)
          EosSurfaceCard(
            child: ListTile(
              leading: const Icon(Icons.gavel, color: EosColors.plum),
              title: Text(n.eventName),
              subtitle: Text('Client: ${n.clientName} • Quote: ₦${(n.counterQuoteMinor / 100).toStringAsFixed(0)}'),
              trailing: Text(n.status.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            ),
          ),
      ],
    );
  }
}

class _ContractsTab extends ConsumerWidget {
  const _ContractsTab({required this.vendorId});
  final String vendorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final intel = ref.watch(vendorIntelligenceProvider);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        for (final c in intel.contracts)
          EosSurfaceCard(
            child: ListTile(
              leading: const Icon(Icons.feed, color: EosColors.plum),
              title: Text(c.eventName),
              subtitle: Text('Total Value: ₦${(c.totalValueMinor / 100).toStringAsFixed(0)} • Milestones: ${(c.milestoneProgress * 100).toStringAsFixed(0)}% Approved'),
            ),
          ),
      ],
    );
  }
}

class _FinanceTab extends ConsumerWidget {
  const _FinanceTab({required this.vendorId});
  final String vendorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final intel = ref.watch(vendorIntelligenceProvider);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        EosSurfaceCard(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Commerce360 Ledger Oversight', style: context.eosText.titleMedium),
                const SizedBox(height: 12),
                Text('Total Available Funds: ₦${(intel.availableBalanceMinor / 100).toStringAsFixed(2)}'),
                Text('Total Escrow Locked: ₦${(intel.escrowBalanceMinor / 100).toStringAsFixed(2)}'),
                Text('Released Funds: ₦${(intel.releasedFundsMinor / 100).toStringAsFixed(2)}'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InventoryTab extends StatelessWidget {
  const _InventoryTab({required this.vendorId});
  final String vendorId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        EosSurfaceCard(
          child: const ListTile(
            leading: Icon(Icons.inventory, color: EosColors.plum),
            title: Text('Standard Catering package (100 guests)'),
            subtitle: Text('Stock levels: 4 kits available • Base price: ₦150,000'),
          ),
        ),
      ],
    );
  }
}

class _CalendarTab extends StatelessWidget {
  const _CalendarTab({required this.vendorId});
  final String vendorId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        EosSurfaceCard(
          child: const ListTile(
            leading: Icon(Icons.calendar_month, color: EosColors.plum),
            title: Text('Wale & Shade Wedding setup'),
            subtitle: Text('Reserved July 2nd 10:00 AM - 18:00 PM'),
          ),
        ),
      ],
    );
  }
}

class _CustomersTab extends ConsumerWidget {
  const _CustomersTab({required this.vendorId});
  final String vendorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final intel = ref.watch(vendorIntelligenceProvider);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        for (final c in intel.crmClients)
          EosSurfaceCard(
            child: ListTile(
              leading: const Icon(Icons.person, color: EosColors.plum),
              title: Text(c.name),
              subtitle: Text('Lifetime Spend: ₦${(c.lifetimeSpendMinor / 100).toStringAsFixed(0)} • Segment: ${c.segment}'),
            ),
          ),
      ],
    );
  }
}

class _PerformanceTab extends ConsumerWidget {
  const _PerformanceTab({required this.vendorId});
  final String vendorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final intel = ref.watch(vendorIntelligenceProvider);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        EosSurfaceCard(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SLA Performance Overview', style: context.eosText.titleMedium),
                const SizedBox(height: 12),
                Text('Response Rate compliance: ${intel.slaCompliance}%'),
                Text('SLA Violations count: 0 (Optimal)'),
                Text('Risk Assessment score: ${intel.riskScore} (Low Risk)'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelineTab extends StatelessWidget {
  const _TimelineTab({required this.vendorId});
  final String vendorId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        EosSurfaceCard(
          child: const ListTile(
            leading: Icon(Icons.timeline, color: EosColors.plum),
            title: Text('Account Setup and Verification'),
            subtitle: Text('Completed June 1st 08:30 AM'),
          ),
        ),
      ],
    );
  }
}

class _AuditTab extends StatelessWidget {
  const _AuditTab({required this.vendorId});
  final String vendorId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        EosSurfaceCard(
          child: const ListTile(
            leading: Icon(Icons.history, color: EosColors.plum),
            title: Text('Vendor Profile Status changed to Approved'),
            subtitle: Text('By Administrator on June 1st 08:45 AM'),
          ),
        ),
      ],
    );
  }
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab({required this.vendorId});
  final String vendorId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        EosSurfaceCard(
          child: const ListTile(
            leading: Icon(Icons.settings, color: EosColors.plum),
            title: Text('Platform configuration rules overrides'),
            subtitle: Text('Fee rules: default (5% Platform commission)'),
          ),
        ),
      ],
    );
  }
}
