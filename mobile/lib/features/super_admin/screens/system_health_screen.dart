import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../eos/eos.dart';
import '../../../eos/layout/workspace/operations_engine.dart';
import '../../../eos/layout/workspace/workspace_definition.dart';
import '../../../eos/layout/workspace/workspace_widgets.dart';

class SystemHealthScreen extends ConsumerStatefulWidget {
  const SystemHealthScreen({super.key});

  @override
  ConsumerState<SystemHealthScreen> createState() => _SystemHealthScreenState();
}

class _SystemHealthScreenState extends ConsumerState<SystemHealthScreen> {
  String _selectedTopologyNode = '';

  @override
  Widget build(BuildContext context) {
    final isMobile = EosResponsive.isMobile(context);
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Ribbon
          _buildHealthRibbon(context),
          const SizedBox(height: 24),

          // Digital Twin Topology Map
          _buildPlatformTopology(context),
          const SizedBox(height: 24),

          // Platform Operational Zones
          if (isMobile) ...[
            _buildServiceHealthGrid(context),
            const SizedBox(height: 20),
            _buildActiveIncidentsQueue(context),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 7,
                  child: _buildServiceHealthGrid(context),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 5,
                  child: _buildActiveIncidentsQueue(context),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),

          // Forecasts & Commands
          if (isMobile) ...[
            _buildOperationsTimeline(context),
            const SizedBox(height: 20),
            _buildHealthCommandsPanel(context),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 7,
                  child: _buildOperationsTimeline(context),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 5,
                  child: _buildHealthCommandsPanel(context),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHealthRibbon(BuildContext context) {
    return EosSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Platform Availability & Infrastructure Health', style: context.eosText.titleMedium),
                const Icon(Icons.settings_suggest, color: Colors.green),
              ],
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildRibbonItem(context, 'Availability Score', '99.98%', 'Nominal uptime', Colors.green),
                  _buildDivider(context),
                  _buildRibbonItem(context, 'Critical Incidents', '1 active', 'DB secondary replica', Colors.red),
                  _buildDivider(context),
                  _buildRibbonItem(context, 'API Latency P95', '45ms', 'Nominal response', Colors.green),
                  _buildDivider(context),
                  _buildRibbonItem(context, 'System Health Index', '92/100', 'Stability checked', Colors.green),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRibbonItem(BuildContext context, String label, String value, String desc, Color color) {
    return Container(
      width: 180,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: context.eosText.labelSmall?.copyWith(fontSize: 8)),
          const SizedBox(height: 4),
          Text(value, style: context.eosText.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(desc, style: context.eosText.bodySmall?.copyWith(fontSize: 9)),
        ],
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Container(height: 36, width: 1, color: context.eosColors.outlineVariant);
  }

  Widget _buildPlatformTopology(BuildContext context) {
    final nodes = [
      'Client',
      'API Gateway',
      'Auth Engine',
      'Core Service',
      'Workers Node',
      'Database Secondary',
    ];

    return EosSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Platform Digital Twin Topology Map', style: context.eosText.titleMedium),
            const SizedBox(height: 12),
            const Text('Select any node in the pipeline below to inspect its operational metrics or drill into its Service 360 workspace.'),
            const SizedBox(height: 20),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (int i = 0; i < nodes.length; i++) ...[
                    _buildTopologyNode(context, nodes[i]),
                    if (i < nodes.length - 1)
                      Icon(Icons.arrow_forward_ios, size: 14, color: context.eosColors.outline),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopologyNode(BuildContext context, String node) {
    final active = _selectedTopologyNode == node;
    final isFail = node.contains('Database');
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() => _selectedTopologyNode = node);
        OperationsEngine.open(context, ref, node.toLowerCase().replaceAll(' ', '-'));
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: active
              ? context.eosColors.primary
              : (isFail ? Colors.red.withOpacity(0.08) : context.eosColors.surfaceVariant.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? context.eosColors.primary : (isFail ? Colors.red : context.eosColors.outlineVariant)),
        ),
        child: Column(
          children: [
            Icon(
              node.contains('Database') ? Icons.storage : Icons.dns,
              color: active ? Colors.white : (isFail ? Colors.red : context.eosColors.primary),
            ),
            const SizedBox(height: 8),
            Text(
              node,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: active ? Colors.white : (isFail ? Colors.red : null),
              ),
            ),
            Text(
              isFail ? 'Spike (88ms)' : 'OK (4ms)',
              style: TextStyle(
                fontSize: 9,
                color: active ? Colors.white70 : (isFail ? Colors.red : Colors.green),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceHealthGrid(BuildContext context) {
    return EosSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Operational Services Status', style: context.eosText.titleMedium),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 2.2,
              children: [
                _buildServiceCard(context, 'api-gateway', 'v1.4.2', 98, 'LAGOS', '45ms'),
                _buildServiceCard(context, 'auth-service', 'v1.1.0', 99, 'LAGOS', '12ms'),
                _buildServiceCard(context, 'core-scheduler', 'v2.0.1', 94, 'LAGOS', '85ms'),
                _buildServiceCard(context, 'database-secondary', 'v1.0.0', 45, 'LAGOS', '8ms'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCard(BuildContext context, String serviceName, String version, int health, String region, String latency) {
    final isFail = health < 50;
    return InkWell(
      onTap: () => OperationsEngine.open(context, ref, serviceName),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.eosColors.surfaceVariant.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isFail ? Colors.red : context.eosColors.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(serviceName.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: isFail ? Colors.red : Colors.green, borderRadius: BorderRadius.circular(4)),
                  child: Text('$health%', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const Spacer(),
            Text('Lat: $latency | Reg: $region', style: context.eosText.bodySmall),
            Text('Version: $version', style: context.eosText.bodySmall?.copyWith(fontSize: 9, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveIncidentsQueue(BuildContext context) {
    return EosSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Live Incident Center', style: context.eosText.titleMedium),
            const SizedBox(height: 16),
            _buildIncidentItem(context, 'INC-891: DB secondary replica latency', 'CRITICAL', 'Started 14m ago', Colors.red),
            _buildIncidentItem(context, 'INC-890: Webhook scheduler lag', 'WARNING', 'Started 1h ago', Colors.orange),
          ],
        ),
      ),
    );
  }

  Widget _buildIncidentItem(BuildContext context, String title, String severity, String sub, Color pCol) {
    return InkWell(
      onTap: () => OperationsEngine.open(context, ref, 'inc-891', fallbackType: WorkspaceEntityType.incident),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: pCol.withOpacity(0.04),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: pCol.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(sub, style: context.eosText.bodySmall),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: pCol, borderRadius: BorderRadius.circular(4)),
              child: Text(severity, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOperationsTimeline(BuildContext context) {
    return EosSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Live operational activity stream', style: context.eosText.titleMedium),
            const SizedBox(height: 16),
            WorkspaceTimeline(
              items: [
                WorkspaceTimelineItem(
                  title: 'Core scheduler restarted',
                  description: 'Manual refresh executed successfully.',
                  timestamp: '1h ago',
                  category: 'operations',
                  icon: Icons.refresh,
                  iconColor: Colors.blue,
                ),
                WorkspaceTimelineItem(
                  title: 'Secondary DB Latency Spike',
                  description: 'Replica health drop from 98% -> 45%',
                  timestamp: '14m ago',
                  category: 'operations',
                  icon: Icons.error_outline,
                  iconColor: Colors.red,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthCommandsPanel(BuildContext context) {
    return EosSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Operations Command Center', style: context.eosText.titleMedium),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.refresh, color: Colors.blue),
              title: const Text('Restart Worker'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 12),
              onTap: () {
                // Command action
              },
            ),
            ListTile(
              leading: const Icon(Icons.cleaning_services, color: Colors.orange),
              title: const Text('Refresh Cache'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 12),
              onTap: () {
                // Command action
              },
            ),
            ListTile(
              leading: const Icon(Icons.dns, color: Colors.purple),
              title: const Text('Run Diagnostics'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 12),
              onTap: () {
                // Command action
              },
            ),
          ],
        ),
      ),
    );
  }
}
