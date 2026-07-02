import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';
import '../../../eos/layout/workspace/entity_engine.dart';
import '../../../eos/layout/workspace/workspace_widgets.dart';
import '../../../eos/layout/workspace/workspace_definition.dart';
import '../../../eos/security/security_engine.dart';

class SecurityCenterScreen extends ConsumerWidget {
  const SecurityCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = EosResponsive.isMobile(context);
    return EosPageScaffold(
      title: 'Security Operations Center',
      subtitle: 'Real-time platform telemetry, WAF controls, and security posture enforcement',
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Executive Security Ribbon
            _buildExecutiveRibbon(context),
            const SizedBox(height: 24),

            // 2. Twin Interactive Map & Threat Map Grid
            if (isMobile) ...[
              _buildAttackMap(context),
              const SizedBox(height: 20),
              _buildThreatHeatMap(context),
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 6,
                    child: _buildAttackMap(context),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 6,
                    child: _buildThreatHeatMap(context),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),

            // 3. Telemetry feeds (Auth & Fraud Feeds)
            if (isMobile) ...[
              _buildLiveAuthFeed(context, ref),
              const SizedBox(height: 20),
              _buildFraudFeed(context),
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 6,
                    child: _buildLiveAuthFeed(context, ref),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 6,
                    child: _buildFraudFeed(context),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),

            // 4. Incident Queue & Top Attackers Grid
            if (isMobile) ...[
              _buildIncidentQueue(context, ref),
              const SizedBox(height: 20),
              _buildTopAttackers(context),
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 7,
                    child: _buildIncidentQueue(context, ref),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 5,
                    child: _buildTopAttackers(context),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),

            // 5. Compliance, AI Briefing, and Matrix
            if (isMobile) ...[
              _buildComplianceStatus(context),
              const SizedBox(height: 20),
              _buildSecurityHealthMatrix(context),
              const SizedBox(height: 20),
              _buildAiBriefing(context),
              const SizedBox(height: 16),
              _buildQuickActions(context),
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: _buildComplianceStatus(context),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 4,
                    child: _buildSecurityHealthMatrix(context),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 4,
                    child: Column(
                      children: [
                        _buildAiBriefing(context),
                        const SizedBox(height: 16),
                        _buildQuickActions(context),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExecutiveRibbon(BuildContext context) {
    return EosSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('SOC Executive Posture Indicators', style: context.eosText.titleMedium),
                TextButton.icon(
                  onPressed: () => context.go('/super-admin/security/global'),
                  icon: const Icon(Icons.open_in_new, size: 14),
                  label: const Text('Open Security 360'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildRibbonKpi(context, 'Security Score', '96%', '+1.2%', Colors.green),
                  _buildRibbonKpi(context, 'Threat Level', 'LOW', 'STABLE', Colors.blue),
                  _buildRibbonKpi(context, 'Blocked Attacks', '2,492', '+4%', Colors.green),
                  _buildRibbonKpi(context, 'Rate Limit Triggers', '18', '-12%', Colors.orange),
                  _buildRibbonKpi(context, 'Open Incidents', '1', 'ACTIVE', Colors.red),
                  _buildRibbonKpi(context, 'Compromised Sess.', '0', 'STABLE', Colors.green),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRibbonKpi(BuildContext context, String label, String value, String sub, Color color) {
    return Container(
      width: 160,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.eosColors.surfaceVariant.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.eosColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: context.eosText.labelSmall),
          const SizedBox(height: 6),
          Text(value, style: context.eosText.titleMedium?.copyWith(color: color, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(sub, style: context.eosText.bodySmall),
        ],
      ),
    );
  }

  Widget _buildAttackMap(BuildContext context) {
    return EosSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Attack Ingestion World Map (Telemetry)', style: context.eosText.titleMedium),
                const Icon(Icons.map, size: 16, color: Colors.blue),
              ],
            ),
            const Divider(height: 24),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.radar, color: Colors.green, size: 40),
                    const SizedBox(height: 8),
                    Text('Active Ingestion Geolocation Sensors', style: context.eosText.labelMedium?.copyWith(color: Colors.white)),
                    const SizedBox(height: 4),
                    Text('Lagos, NG (89%)  ·  London, UK (4%)  ·  Other (7%)', style: context.eosText.bodySmall?.copyWith(color: Colors.grey)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThreatHeatMap(BuildContext context) {
    return EosSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Threat Heat Map & Attack Vector Matrix', style: context.eosText.titleMedium),
                const Icon(Icons.grid_on, size: 16, color: Colors.orange),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildHeatGrid(context, 'SQLi', 'LOW', Colors.green),
                _buildHeatGrid(context, 'XSS', 'LOW', Colors.green),
                _buildHeatGrid(context, 'Brute Force', 'MEDIUM', Colors.orange),
                _buildHeatGrid(context, 'DDoS', 'LOW', Colors.green),
                _buildHeatGrid(context, 'Replay', 'MEDIUM', Colors.orange),
              ],
            ),
            const SizedBox(height: 24),
            Text('Blocked Requests (Last 1 hour): 142 requests', style: context.eosText.bodySmall?.copyWith(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeatGrid(BuildContext context, String vector, String risk, Color riskColor) {
    return Container(
      width: 80,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: riskColor.withOpacity(0.12),
        border: Border.all(color: riskColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(vector, style: context.eosText.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Text(risk, style: TextStyle(color: riskColor, fontWeight: FontWeight.bold, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildLiveAuthFeed(BuildContext context, WidgetRef ref) {
    return EosSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Live Authentication Feed', style: context.eosText.titleMedium),
            const Divider(height: 24),
            for (final sess in SecurityEngine.sessions)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(child: Icon(Icons.person, size: 14)),
                title: Text('User ${sess.userId} session creation'),
                subtitle: Text('IP: ${sess.ipAddress} · Device: ${sess.device}'),
                trailing: TextButton(
                  onPressed: () => EntityEngine.open(context, ref, sess.userId, fallbackType: WorkspaceEntityType.user),
                  child: const Text('Open User360'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFraudFeed(BuildContext context) {
    return EosSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Live Platform Fraud Feed', style: context.eosText.titleMedium),
            const Divider(height: 24),
            for (final f in SecurityEngine.fraudRisks)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.warning_amber, color: Colors.orange),
                title: Text(f.type),
                subtitle: Text('Risk Score: ${f.riskScore}/100 · Amt: ₦${(f.amountMinor / 100).toStringAsFixed(2)}'),
                trailing: EosFinanceChip(label: f.status, compact: true),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncidentQueue(BuildContext context, WidgetRef ref) {
    return EosSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SOC Active Incident Queue', style: context.eosText.titleMedium),
            const SizedBox(height: 16),
            EosDataTable(
              columns: const [
                DataColumn(label: Text('ID')),
                DataColumn(label: Text('Title')),
                DataColumn(label: Text('Severity')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Actions')),
              ],
              onRowTap: (idx) {
                final inc = SecurityEngine.incidents[idx];
                EntityEngine.open(context, ref, inc.id, fallbackType: WorkspaceEntityType.incident);
              },
              rows: [
                for (final inc in SecurityEngine.incidents)
                  DataRow(cells: [
                    DataCell(Text(inc.id)),
                    DataCell(Text(inc.title)),
                    DataCell(Text(inc.severity, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                    DataCell(EosFinanceChip(label: inc.status, compact: true)),
                    DataCell(TextButton(
                      onPressed: () => EntityEngine.open(context, ref, inc.id, fallbackType: WorkspaceEntityType.incident),
                      child: const Text('Open Incident360'),
                    )),
                  ]),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopAttackers(BuildContext context) {
    return EosSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Top Platform Attack Sources', style: context.eosText.titleMedium),
            const SizedBox(height: 16),
            EosDataTable(
              columns: const [
                DataColumn(label: Text('Source IP')),
                DataColumn(label: Text('Region')),
                DataColumn(label: Text('Reputation')),
              ],
              rows: const [
                DataRow(cells: [
                  DataCell(Text('192.168.12.44')),
                  DataCell(Text('Nigeria')),
                  DataCell(Text('SUSPICIOUS')),
                ]),
                DataRow(cells: [
                  DataCell(Text('89.207.132.55')),
                  DataCell(Text('Russia')),
                  DataCell(Text('MALICIOUS')),
                ]),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComplianceStatus(BuildContext context) {
    return EosSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Regulatory Compliance', style: context.eosText.titleMedium),
            const Divider(height: 24),
            for (final c in SecurityEngine.complianceMetrics)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(c.standard, style: context.eosText.labelMedium),
                    Text('${c.score}% Align', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityHealthMatrix(BuildContext context) {
    return EosSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Security Health Matrix', style: context.eosText.titleMedium),
            const Divider(height: 24),
            _buildMatrixItem(context, 'SSL Certificate Validity', 'VALID', Colors.green),
            _buildMatrixItem(context, 'Secrets Vault Encrypted', 'DECRYPTED', Colors.green),
            _buildMatrixItem(context, 'OAuth Provider Health', 'ONLINE', Colors.green),
            _buildMatrixItem(context, 'Intrusion Detection Nodes', 'ACTIVE', Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _buildMatrixItem(BuildContext context, String label, String status, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: context.eosText.bodySmall),
          Text(status, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildAiBriefing(BuildContext context) {
    return EosSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('AI Briefing Note', style: context.eosText.titleMedium),
            const Divider(height: 16),
            for (final ins in SecurityEngine.insights)
              Text(ins.reason, style: context.eosText.bodyMedium),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return EosSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quick SOC Actions', style: context.eosText.titleMedium),
            const Divider(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Global MFA enforcement successfully initialized.')),
                    );
                  },
                  icon: const Icon(Icons.lock, size: 14),
                  label: const Text('Enforce Global MFA'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('API Keys rotation sequence started.')),
                    );
                  },
                  icon: const Icon(Icons.rotate_right, size: 14),
                  label: const Text('Rotate API Keys'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
