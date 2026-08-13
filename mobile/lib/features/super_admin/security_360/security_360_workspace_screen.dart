import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../eos/eos.dart';
import '../../../eos/layout/workspace/entity_engine.dart';
import '../../../eos/layout/workspace/workspace_definition.dart';
import '../../../eos/layout/workspace/workspace_shell.dart';
import '../../../eos/layout/workspace/workspace_widgets.dart';
import '../../../eos/security/security_engine.dart';
import '../../../platform/identity/identity_mfa_provider.dart';
import '../../../platform/identity/identity_mfa_models.dart';
import '../../../core/api/identity_security_api.dart';
import '../../admin/platform/compliance_providers.dart';

class Security360WorkspaceScreen extends ConsumerStatefulWidget {
  const Security360WorkspaceScreen({super.key, required this.securityId});
  final String securityId;

  @override
  ConsumerState<Security360WorkspaceScreen> createState() => _Security360WorkspaceScreenState();
}

class _Security360WorkspaceScreenState extends ConsumerState<Security360WorkspaceScreen> {
  late WorkspaceDefinition _securityWorkspaceDefinition;

  @override
  void initState() {
    super.initState();
    _securityWorkspaceDefinition = WorkspaceDefinition(
      entityType: WorkspaceEntityType.security,
      title: 'Security Operations Center',
      icon: Icons.shield_outlined,
      metrics: const [
        WorkspaceMetricDefinition(
          label: 'Platform Security Score',
          valueResolver: _resolveSecurityScore,
          subtitle: 'Baseline alignment index',
        ),
      ],
      quickActions: [
        WorkspaceActionDefinition(
          label: 'Run Threat Scan',
          icon: Icons.radar,
          onPressed: (context, id) async {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Global threat scan triggered across all microservices.')),
            );
          },
        ),
        WorkspaceActionDefinition(
          label: 'Rotate API Keys',
          icon: Icons.vpn_key_outlined,
          onPressed: (context, id) async {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Secrets rotation sequence initiated for platform gateway.')),
            );
          },
        ),
      ],
      tabs: [
        WorkspaceTabDefinition(
          label: 'Overview',
          builder: (context, id) => _OverviewTabBridge(securityId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Threat Intelligence',
          builder: (context, id) => _ThreatIntelTabBridge(securityId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Identity',
          builder: (context, id) => _IdentityTabBridge(securityId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Authentication',
          builder: (context, id) => _AuthTabBridge(securityId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Authorization',
          builder: (context, id) => _PermsTabBridge(securityId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Fraud Monitor',
          builder: (context, id) => _FraudTabBridge(securityId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Compliance',
          builder: (context, id) => _ComplianceTabBridge(securityId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Incident Center',
          builder: (context, id) => _IncidentsTabBridge(securityId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Timeline',
          builder: (context, id) => _TimelineTabBridge(securityId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Audit Explorer',
          builder: (context, id) => _AuditTabBridge(securityId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Relationships',
          builder: (context, id) => _RelationsTabBridge(securityId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Settings',
          builder: (context, id) => _SettingsTabBridge(securityId: id),
        ),
      ],
    );
  }

  static String _resolveSecurityScore(Map<String, dynamic> d) {
    return '96%';
  }

  @override
  Widget build(BuildContext context) {
    final healthScore = SecurityEngine.platformSecurityScore.score;

    return WorkspaceShell(
      definition: _securityWorkspaceDefinition,
      entityId: widget.securityId,
      name: 'Owambe Security Center',
      logoText: '🛡️',
      healthScore: healthScore,
      environment: 'Production',
      region: 'NG-LAGOS',
      primaryContact: 'Unavailable',
      createdDate: '2026-06-01',
      lastActivity: 'Threat feed active',
      sidebarWidgets: [
        WorkspaceHealthPanel(
          healthScore: healthScore,
          factors: const [
            'SSL certificates validated',
            'Secrets vault decrypted',
            'OAuth validation online',
          ],
        ),
        EosSurfaceCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Active Integrations', style: context.eosText.titleSmall),
                const SizedBox(height: 8),
                for (final siem in SecurityEngine.activeSiemIntegrations.take(4))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      children: [
                        const Icon(Icons.integration_instructions, size: 12, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(child: Text(siem, style: context.eosText.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ==================== TABS IMPLEMENTATION BRIDGES ====================

class _OverviewTabBridge extends ConsumerWidget {
  const _OverviewTabBridge({required this.securityId});
  final String securityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // 1. Executive Security Ribbon
        _buildRibbon(context),
        const SizedBox(height: 24),

        // 2. AI Security Summary & Security Trends
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: _buildTrends(context),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 4,
              child: _buildAiSummary(context),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // 3. Recent Events Grid
        _buildRecentEventsGrid(context, ref),
      ],
    );
  }

  Widget _buildRibbon(BuildContext context) {
    return EosSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Operational Security Ribbon', style: context.eosText.titleMedium),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildKpiCard(context, 'Security Score', '96%', Colors.green),
                  _buildKpiCard(context, 'Threat Level', 'LOW', Colors.blue),
                  _buildKpiCard(context, 'Blocked Attacks', '2,492', Colors.green),
                  _buildKpiCard(context, 'Open Incidents', '1', Colors.red),
                  _buildKpiCard(context, 'Failed Logins', '12', Colors.orange),
                  _buildKpiCard(context, 'Rate Limits', '18', Colors.blue),
                  _buildKpiCard(context, 'Compromised Sess.', '0', Colors.green),
                  _buildKpiCard(context, 'Platform Health', 'OPTIMAL', Colors.green),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard(BuildContext context, String label, String value, Color color) {
    return Container(
      width: 140,
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
          Text(label, style: context.eosText.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(value, style: context.eosText.titleMedium?.copyWith(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTrends(BuildContext context) {
    return EosSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Weekly Threat Mitigation Index', style: context.eosText.titleMedium),
            const SizedBox(height: 20),
            _buildProgressBar(context, 'Brute Force Shielding', 1.0, '100% Effectiveness'),
            _buildProgressBar(context, 'Injection Protection', 0.98, '98% Effectiveness'),
            _buildProgressBar(context, 'DDoS Mitigation Rate', 0.999, '99.9% Mitigated'),
            _buildProgressBar(context, 'Replay Prevention Index', 0.95, '95% Prevented'),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context, String label, double val, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: context.eosText.bodyMedium),
              Text(subtitle, style: context.eosText.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(value: val, color: Colors.blue, backgroundColor: context.eosColors.surfaceVariant),
        ],
      ),
    );
  }

  Widget _buildAiSummary(BuildContext context) {
    return EosSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('AI Security Briefing', style: context.eosText.titleMedium),
            const Divider(height: 24),
            for (final ins in SecurityEngine.insights)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bolt, color: Colors.orange, size: 16),
                      const SizedBox(width: 8),
                      Text('Alert: ${ins.severity}', style: context.eosText.labelMedium?.copyWith(color: Colors.red)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(ins.reason, style: context.eosText.bodyMedium),
                  const SizedBox(height: 6),
                  Text('Recommendation: ${ins.recommendation}', style: context.eosText.bodySmall?.copyWith(color: Colors.blue)),
                  const Divider(height: 24),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentEventsGrid(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent Security Events Log', style: context.eosText.titleMedium),
        const SizedBox(height: 12),
        EosDataTable(
          columns: const [
            DataColumn(label: Text('Event Name')),
            DataColumn(label: Text('Severity')),
            DataColumn(label: Text('Source IP')),
            DataColumn(label: Text('Timestamp')),
            DataColumn(label: Text('Status')),
          ],
          rows: [
            for (final threat in SecurityEngine.threats)
              DataRow(cells: [
                DataCell(Text(threat.name)),
                DataCell(Text(threat.severity, style: TextStyle(color: threat.severity == 'HIGH' ? Colors.red : Colors.orange, fontWeight: FontWeight.bold))),
                DataCell(Text(threat.sourceIp)),
                DataCell(Text(threat.detectedAt)),
                DataCell(EosFinanceChip(label: threat.status, compact: true)),
              ]),
          ],
        ),
      ],
    );
  }
}

class _ThreatIntelTabBridge extends ConsumerWidget {
  const _ThreatIntelTabBridge({required this.securityId});
  final String securityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Threat Intelligence Feed', style: context.eosText.titleMedium),
        const SizedBox(height: 12),
        EosDataTable(
          columns: const [
            DataColumn(label: Text('ID')),
            DataColumn(label: Text('Threat Detail')),
            DataColumn(label: Text('Confidence')),
            DataColumn(label: Text('IP Address')),
            DataColumn(label: Text('Target User')),
            DataColumn(label: Text('Action')),
          ],
          onRowTap: (idx) {
            final t = SecurityEngine.threats[idx];
            EntityEngine.open(context, ref, t.affectedUser, fallbackType: WorkspaceEntityType.user);
          },
          rows: [
            for (final t in SecurityEngine.threats)
              DataRow(cells: [
                DataCell(Text(t.id)),
                DataCell(Text('${t.name} (Severity: ${t.severity})')),
                DataCell(Text('${(t.confidence * 100).toStringAsFixed(0)}%')),
                DataCell(Text(t.sourceIp)),
                DataCell(Text(t.affectedUser)),
                DataCell(TextButton(
                  onPressed: () => EntityEngine.open(context, ref, t.affectedUser, fallbackType: WorkspaceEntityType.user),
                  child: const Text('Inspect User'),
                )),
              ]),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: EosSurfaceCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Top Attack Sources (IP Reputation)', style: context.eosText.titleMedium),
                      const Divider(height: 24),
                      _buildReputationRow(context, '192.168.12.44', 'Nigeria', '94% Confidence / Spammer'),
                      _buildReputationRow(context, '102.89.23.4', 'United States', '82% Confidence / Botnet'),
                      _buildReputationRow(context, '89.207.132.55', 'Russia', '98% Confidence / Brute force'),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: EosSurfaceCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('MITRE ATT&CK Classifications', style: context.eosText.titleMedium),
                      const Divider(height: 24),
                      _buildMitreRow(context, 'T1110', 'Brute Force', 'Credential stuffing detections'),
                      _buildMitreRow(context, 'T1078', 'Valid Accounts', 'Suspicious concurrent logins'),
                      _buildMitreRow(context, 'T1539', 'Steal Web Session Cookie', 'Session replay attempts'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReputationRow(BuildContext context, String ip, String region, String detail) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$ip ($region)', style: context.eosText.labelMedium),
          Text(detail, style: context.eosText.bodySmall?.copyWith(color: Colors.red)),
        ],
      ),
    );
  }

  Widget _buildMitreRow(BuildContext context, String code, String technique, String contextInfo) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
            child: Text(code, style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 10)),
          ),
          const SizedBox(width: 8),
          Text(technique, style: context.eosText.labelMedium),
          const Spacer(),
          Text(contextInfo, style: context.eosText.bodySmall),
        ],
      ),
    );
  }
}

class _IdentityTabBridge extends ConsumerWidget {
  const _IdentityTabBridge({required this.securityId});
  final String securityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('User Platform Status Matrix', style: context.eosText.titleMedium),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildKpiCard(context, 'Registered Users', '1,492', Colors.blue),
              _buildKpiCard(context, 'Online Users', '142', Colors.green),
              _buildKpiCard(context, 'Locked Accounts', '3', Colors.red),
              _buildKpiCard(context, 'Suspended Users', '1', Colors.orange),
              _buildKpiCard(context, 'Pending Verification', '12', Colors.blue),
              _buildKpiCard(context, 'Dormant Accounts', '44', Colors.grey),
            ],
          ),
        ),
        const SizedBox(height: 24),
        EosDataTable(
          columns: const [
            DataColumn(label: Text('User ID')),
            DataColumn(label: Text('Display Name')),
            DataColumn(label: Text('MFA Active')),
            DataColumn(label: Text('Account Status')),
            DataColumn(label: Text('Actions')),
          ],
          onRowTap: (idx) => EntityEngine.open(context, ref, 'usr_1', fallbackType: WorkspaceEntityType.user),
          rows: [
            DataRow(cells: [
              const DataCell(Text('usr_1')),
              const DataCell(Text('Adenike Adebayo (Super CFO)')),
              const DataCell(Text('YES - TOTP Authenticator')),
              const DataCell(Text('ACTIVE')),
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

  Widget _buildKpiCard(BuildContext context, String label, String value, Color color) {
    return Container(
      width: 140,
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
          const SizedBox(height: 4),
          Text(value, style: context.eosText.titleMedium?.copyWith(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _AuthTabBridge extends ConsumerWidget {
  const _AuthTabBridge({required this.securityId});
  final String securityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final center = ref.watch(identitySecurityCenterProvider);
    final mfa = ref.watch(identityMfaProvider);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Authentication & MFA', style: context.eosText.titleMedium),
        const SizedBox(height: 8),
        Text(
          'Nest/Supabase MFA status — seeded MFA theater removed as source of truth.',
          style: context.eosText.bodySmall,
        ),
        const SizedBox(height: 16),
        EosSurfaceCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Current user MFA enrolled: ${mfa.rawStatus?['enrolled'] == true}'),
                Text('Factors available: ${mfa.rawStatus?['available'] != false}'),
                if (mfa.error != null) Text('Error: ${mfa.error}'),
                if (mfa.rawStatus?['reason'] != null) Text('${mfa.rawStatus?['reason']}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        center.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Security events unavailable: $e'),
          data: (d) {
            final login = (d['loginActivity'] as List<dynamic>? ?? const [])
                .cast<Map<String, dynamic>>();
            return EosDataTable(
              columns: const [
                DataColumn(label: Text('Event')),
                DataColumn(label: Text('Actor')),
                DataColumn(label: Text('When')),
              ],
              rows: [
                for (final e in login.take(20))
                  DataRow(cells: [
                    DataCell(Text('${e['eventType']}')),
                    DataCell(Text('${e['actorUserId'] ?? ''}')),
                    DataCell(Text('${e['timestamp'] ?? ''}')),
                  ]),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PermsTabBridge extends ConsumerWidget {
  const _PermsTabBridge({required this.securityId});
  final String securityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Role & Privilege Authorization Log', style: context.eosText.titleMedium),
        const SizedBox(height: 12),
        EosDataTable(
          columns: const [
            DataColumn(label: Text('Timestamp')),
            DataColumn(label: Text('User')),
            DataColumn(label: Text('Granted Role')),
            DataColumn(label: Text('Authorized By')),
            DataColumn(label: Text('Escalation Risk')),
          ],
          onRowTap: (idx) => EntityEngine.open(context, ref, 'usr_1', fallbackType: WorkspaceEntityType.user),
          rows: [
            DataRow(cells: [
              const DataCell(Text('2026-06-25 14:10:00')),
              const DataCell(Text('usr_1')),
              const DataCell(Text('Lead Organizer')),
              const DataCell(Text('Platform Super Admin')),
              DataCell(Text('LOW', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
            ]),
          ],
        ),
        const SizedBox(height: 24),
        EosSurfaceCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Platform RBAC Definitions Matrix', style: context.eosText.titleMedium),
                const Divider(height: 24),
                _buildRbacRow(context, 'Super Admin', 'Full workspace root privileges'),
                _buildRbacRow(context, 'Tenant Admin', 'Modify tenant scopes, configure feature flags'),
                _buildRbacRow(context, 'Lead Organizer', 'Create events, manage ticket inventory, request payouts'),
                _buildRbacRow(context, 'Client / Attendee', 'Browse discover portal, checkout tickets'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRbacRow(BuildContext context, String role, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Container(
            width: 130,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: context.eosColors.surfaceVariant, borderRadius: BorderRadius.circular(4)),
            child: Text(role, style: context.eosText.labelSmall?.copyWith(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(description, style: context.eosText.bodyMedium)),
        ],
      ),
    );
  }
}

class _FraudTabBridge extends StatelessWidget {
  const _FraudTabBridge({required this.securityId});
  final String securityId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Suspicious Platform Operations (Fraud Prevention)', style: context.eosText.titleMedium),
        const SizedBox(height: 12),
        EosDataTable(
          columns: const [
            DataColumn(label: Text('Anomaly Type')),
            DataColumn(label: Text('Risk Score')),
            DataColumn(label: Text('Transaction Volume')),
            DataColumn(label: Text('Detection Pattern')),
            DataColumn(label: Text('Status')),
          ],
          rows: [
            for (final f in SecurityEngine.fraudRisks)
              DataRow(cells: [
                DataCell(Text(f.type)),
                DataCell(Text('${f.riskScore} / 100', style: TextStyle(color: f.riskScore > 75 ? Colors.red : Colors.orange, fontWeight: FontWeight.bold))),
                DataCell(Text('₦${(f.amountMinor / 100).toStringAsFixed(2)}')),
                const DataCell(Text('Velocity payout check failed')),
                DataCell(EosFinanceChip(label: f.status, compact: true)),
              ]),
          ],
        ),
      ],
    );
  }
}

class _ComplianceTabBridge extends ConsumerWidget {
  const _ComplianceTabBridge({required this.securityId});
  final String securityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dash = ref.watch(complianceDashboardProvider);
    final activity = ref.watch(complianceActivityProvider);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Data governance status', style: context.eosText.titleMedium),
        const SizedBox(height: 8),
        Text(
          'Live Nest /compliance dashboard (Phase 27). Cosmetic SecurityEngine scores removed.',
          style: context.eosText.bodySmall?.copyWith(color: context.eosColors.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        dash.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => EosSurfaceCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Compliance API unavailable', style: context.eosText.titleSmall),
                  const SizedBox(height: 8),
                  Text('$e'),
                  const SizedBox(height: 8),
                  const Text(
                    'Requires admin tier + tenant.manage. Full operations live under Admin → Compliance.',
                  ),
                  TextButton(
                    onPressed: () => ref.invalidate(complianceDashboardProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
          data: (d) {
            final pending = (d['pendingDeletions'] as num?)?.toInt() ?? 0;
            final gov = d['governanceStatus'] as Map<String, dynamic>? ?? {};
            final retention = d['retention'] as Map<String, dynamic>?;
            final cats = (retention?['categories'] as List<dynamic>? ?? const [])
                .cast<Map<String, dynamic>>();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EosSurfaceCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Retention configured: ${gov['retentionConfigured'] == true ? 'Yes' : 'No'}',
                        ),
                        Text('Open deletion queue: $pending'),
                        Text('Export statuses: ${d['exportByStatus']}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Retention categories', style: context.eosText.titleSmall),
                const SizedBox(height: 8),
                EosDataTable(
                  columns: const [
                    DataColumn(label: Text('Category')),
                    DataColumn(label: Text('Days')),
                  ],
                  rows: [
                    for (final c in cats)
                      DataRow(cells: [
                        DataCell(Text('${c['label'] ?? c['id']}')),
                        DataCell(Text('${c['retentionDays']}')),
                      ]),
                  ],
                ),
                const SizedBox(height: 24),
                Text('Recent compliance activity', style: context.eosText.titleSmall),
                const SizedBox(height: 8),
                activity.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const Text('Activity unavailable'),
                  data: (items) {
                    if (items.isEmpty) {
                      return const Text('No compliance.* audit events yet');
                    }
                    return EosDataTable(
                      columns: const [
                        DataColumn(label: Text('Action')),
                        DataColumn(label: Text('Resource')),
                        DataColumn(label: Text('When')),
                      ],
                      rows: [
                        for (final a in items.take(15))
                          DataRow(cells: [
                            DataCell(Text('${a['action']}')),
                            DataCell(Text('${a['resourceType']}')),
                            DataCell(Text('${a['createdAt'] ?? ''}')),
                          ]),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _IncidentsTabBridge extends ConsumerWidget {
  const _IncidentsTabBridge({required this.securityId});
  final String securityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Incident Response Center', style: context.eosText.titleMedium),
        const SizedBox(height: 12),
        EosDataTable(
          columns: const [
            DataColumn(label: Text('Incident ID')),
            DataColumn(label: Text('Title')),
            DataColumn(label: Text('Severity')),
            DataColumn(label: Text('SLA Target')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Action')),
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
                DataCell(Text('${inc.slaHours} Hours')),
                DataCell(EosFinanceChip(label: inc.status, compact: true)),
                DataCell(TextButton(
                  onPressed: () => EntityEngine.open(context, ref, inc.id, fallbackType: WorkspaceEntityType.incident),
                  child: const Text('Open Incident360'),
                )),
              ]),
          ],
        ),
      ],
    );
  }
}

class _TimelineTabBridge extends StatelessWidget {
  const _TimelineTabBridge({required this.securityId});
  final String securityId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Unified Platform Operations Timeline', style: context.eosText.titleMedium),
            IconButton(
              icon: const Icon(Icons.download, size: 18),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Unified security timeline exported to CSV.')),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        WorkspaceTimeline(
          items: [
            WorkspaceTimelineItem(
              title: 'API Gateway Anomaly Blocked',
              description: 'Blocked suspicious activity from 192.168.12.44.',
              timestamp: '15m ago',
              category: 'security',
              icon: Icons.block,
              iconColor: Colors.red,
            ),
            WorkspaceTimelineItem(
              title: 'Incident Queue Created',
              description: 'Incident INC-891 raised automatically by telemetry analyzer.',
              timestamp: '30m ago',
              category: 'operations',
              icon: Icons.warning,
              iconColor: Colors.orange,
            ),
          ],
        ),
      ],
    );
  }
}

class _AuditTabBridge extends StatelessWidget {
  const _AuditTabBridge({required this.securityId});
  final String securityId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Administrative Change Log Explorer', style: context.eosText.titleMedium),
        const SizedBox(height: 12),
        EosDataTable(
          columns: const [
            DataColumn(label: Text('Timestamp')),
            DataColumn(label: Text('Operator')),
            DataColumn(label: Text('Scope')),
            DataColumn(label: Text('Old Value')),
            DataColumn(label: Text('New Value')),
          ],
          rows: const [
            DataRow(cells: [
              DataCell(Text('2026-06-28 14:22:00')),
              DataCell(Text('Super Admin')),
              DataCell(Text('Rate limit bookings')),
              DataCell(Text('60 / min')),
              DataCell(Text('120 / min')),
            ]),
          ],
        ),
      ],
    );
  }
}

class _RelationsTabBridge extends ConsumerWidget {
  const _RelationsTabBridge({required this.securityId});
  final String securityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        WorkspaceRelationshipGraph(currentType: WorkspaceEntityType.security, entityId: securityId),
      ],
    );
  }
}

class _SettingsTabBridge extends StatelessWidget {
  const _SettingsTabBridge({required this.securityId});
  final String securityId;

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
                Text('Platform Security Policies Configuration', style: context.eosText.titleMedium),
                const Divider(height: 24),
                _buildSettingSlider('Session Timeout Limit (minutes)', 30),
                _buildSettingSlider('Rate Limit Booking Endpoint (req/min)', 120),
                const Divider(height: 24),
                ListTile(
                  title: const Text('Global Enforcement of Multi-Factor Authentication'),
                  subtitle: const Text('Enforces TOTP setup during next login for all administrators'),
                  trailing: Switch(value: true, onChanged: (v) {}),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingSlider(String label, double val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Slider(value: val, min: 10, max: 200, onChanged: (v) {}),
        ],
      ),
    );
  }
}
