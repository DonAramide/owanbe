import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/money.dart';
import '../../../eos/eos.dart';
import '../../../eos/layout/eos_workspace_layout.dart';
import '../../../eos/widgets/analytics/eos_time_series_chart.dart';
import '../super_admin_providers.dart';
import 'executive_dashboard_provider.dart';

class ExecutiveOverviewScreen extends ConsumerStatefulWidget {
  const ExecutiveOverviewScreen({super.key});

  @override
  ConsumerState<ExecutiveOverviewScreen> createState() => _ExecutiveOverviewScreenState();
}

class _ExecutiveOverviewScreenState extends ConsumerState<ExecutiveOverviewScreen> {
  final FocusNode _focusNode = FocusNode();
  String _selectedLayout = 'default';
  bool _timelineAutoRefresh = true;
  Timer? _refreshTimer;
  int _checkInsPerMinute = 32;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_timelineAutoRefresh && mounted) {
        setState(() {
          _checkInsPerMinute = 25 + (15 * (timer.tick % 3));
        });
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _showCommandPalette(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const _CommandPaletteDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(executiveDashboardProvider);

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          final isCtrl = HardwareKeyboard.instance.isControlPressed ||
              HardwareKeyboard.instance.isMetaPressed;
          if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyK) {
            _showCommandPalette(context);
          }
        }
      },
      child: dashboard.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EosPageScaffold(
          title: 'Executive Overview',
          subtitle: 'Platform command center',
          body: EosSurfaceCard(child: Text('Unable to load dashboard: $e')),
        ),
        data: (data) => _buildCommandCenter(context, data),
      ),
    );
  }

  Widget _buildCommandCenter(BuildContext context, dynamic data) {
    final isMobile = EosResponsive.isMobile(context);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Platform Command Center'),
            Text(
              'Real-time Owambe Platform Intelligence & Operations',
              style: context.eosText.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              if (!isMobile)
                Text('Timeline Auto-Refresh', style: context.eosText.bodySmall),
              Switch(
                value: _timelineAutoRefresh,
                onChanged: (val) => setState(() => _timelineAutoRefresh = val),
              ),
            ],
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Command Palette (Ctrl+K)',
            onPressed: () => _showCommandPalette(context),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // 1. Live Operations Ribbon
          _buildLiveOperationsRibbon(context),
          const SizedBox(height: 24),

          // 2. Platform Health & Forecasts Grid
          if (isMobile) ...[
            _buildPlatformHealthCard(context, data.healthScore),
            const SizedBox(height: 20),
            _buildPredictiveForecasts(context),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 4,
                  child: _buildPlatformHealthCard(context, data.healthScore),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 8,
                  child: _buildPredictiveForecasts(context),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),

          // 3. AI Attention Center & Action Center
          if (isMobile) ...[
            _buildAiAttentionCenter(context),
            const SizedBox(height: 20),
            _buildGlobalActionCenter(context),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 7,
                  child: _buildAiAttentionCenter(context),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 5,
                  child: _buildGlobalActionCenter(context),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),

          // 4. Activity Map & Executive Insights
          if (isMobile) ...[
            _buildPlatformActivityMap(context),
            const SizedBox(height: 20),
            _buildExecutiveInsightsPanel(context),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 7,
                  child: _buildPlatformActivityMap(context),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 5,
                  child: _buildExecutiveInsightsPanel(context),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),

          // 5. Executive Scorecards Leaderboard
          _buildExecutiveScorecards(context, data),
        ],
      ),
    );
  }

  Widget _buildLiveOperationsRibbon(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: context.eosColors.primaryContainer.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.eosColors.primaryContainer.withOpacity(0.3)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildRibbonItem(context, 'Live Events', '14', Colors.green),
            _buildRibbonDivider(context),
            _buildRibbonItem(context, 'Active Attendees', '4,120', Colors.blue),
            _buildRibbonDivider(context),
            _buildRibbonItem(context, 'Check-ins / Min', '$_checkInsPerMinute', Colors.purple),
            _buildRibbonDivider(context),
            _buildRibbonItem(context, 'Open Incidents', '3', Colors.red),
            _buildRibbonDivider(context),
            _buildRibbonItem(context, 'Queued Payouts', '5', Colors.orange),
            _buildRibbonDivider(context),
            _buildRibbonItem(context, 'Refund Requests', '2', Colors.grey),
            _buildRibbonDivider(context),
            _buildRibbonItem(context, 'API Health', '99.98%', Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _buildRibbonItem(BuildContext context, String label, String val, Color valColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: context.eosText.labelSmall?.copyWith(fontSize: 8)),
        const SizedBox(height: 2),
        Text(val, style: context.eosText.titleMedium?.copyWith(color: valColor, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildRibbonDivider(BuildContext context) {
    return Container(
      height: 24,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: context.eosColors.outlineVariant,
    );
  }

  Widget _buildPlatformHealthCard(BuildContext context, int healthScore) {
    return EosSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Platform Health Score', style: context.eosText.titleMedium),
            const SizedBox(height: 16),
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 110,
                    height: 110,
                    child: CircularProgressIndicator(
                      value: healthScore / 100,
                      strokeWidth: 10,
                      backgroundColor: context.eosColors.surfaceVariant,
                      valueColor: AlwaysStoppedAnimation(
                        healthScore > 80 ? Colors.green : (healthScore > 55 ? Colors.orange : Colors.red),
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$healthScore', style: context.eosText.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                      Text('NOMINAL', style: context.eosText.labelSmall?.copyWith(fontSize: 9)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildHealthItem(context, 'Revenue Index', '94', Colors.green),
            _buildHealthItem(context, 'Ops Latency', '98', Colors.green),
            _buildHealthItem(context, 'Security Center', '100', Colors.green),
            _buildHealthItem(context, 'Finance Recons', '91', Colors.orange),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthItem(BuildContext context, String name, String score, Color col) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name, style: context.eosText.bodyMedium),
          Text('$score%', style: TextStyle(color: col, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildPredictiveForecasts(BuildContext context) {
    final isMobile = EosResponsive.isMobile(context);
    return EosSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Predictive Operational Forecasts', style: context.eosText.titleMedium),
            const SizedBox(height: 16),
            if (isMobile) ...[
              _buildForecastWidget(context, 'Weekend Attendance', '12,450', '+18% vs last week', Icons.people),
              const SizedBox(height: 16),
              _buildForecastWidget(context, 'Expected Platform Fees', '₦4.8M', 'Based on bookings pipeline', Icons.monetization_on),
              const SizedBox(height: 16),
              _buildForecastWidget(context, 'API Traffic Growth', '1.4M reqs', 'Estimated storage +6.3 GB', Icons.network_check),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: _buildForecastWidget(context, 'Weekend Attendance', '12,450', '+18% vs last week', Icons.people),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildForecastWidget(context, 'Expected Platform Fees', '₦4.8M', 'Based on bookings pipeline', Icons.monetization_on),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildForecastWidget(context, 'API Traffic Growth', '1.4M reqs', 'Estimated storage +6.3 GB', Icons.network_check),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildForecastWidget(BuildContext context, String title, String val, String subtitle, IconData icon) {
    return Container(
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
            children: [
              Icon(icon, size: 16, color: context.eosColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: context.eosText.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(val, style: context.eosText.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(subtitle, style: context.eosText.bodySmall?.copyWith(fontSize: 10, color: Colors.blue)),
        ],
      ),
    );
  }

  Widget _buildAiAttentionCenter(BuildContext context) {
    return EosSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('AI Attention Center', style: context.eosText.titleMedium),
                const Icon(Icons.psychology_outlined, color: Colors.purple),
              ],
            ),
            const SizedBox(height: 16),
            _buildAttentionItem(
              context,
              title: 'Revenue Drop Detected (Sandbox)',
              severity: 'CRITICAL',
              confidence: '92%',
              impact: 'Estimated ₦1.8M below target.',
              reason: 'Ticket sales have slowed across three major events.',
              recommendation: 'Verify payment rail config on Owambe Dev.',
            ),
            _buildAttentionItem(
              context,
              title: 'Escrow Payout Release Overdue',
              severity: 'WARNING',
              confidence: '95%',
              impact: 'Est. 12 organizers delayed in settlement cycles.',
              reason: 'Verification logs pending for Phase 41 bank verification checks.',
              recommendation: 'Open platform finance control drawer.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttentionItem(
    BuildContext context, {
    required String title,
    required String severity,
    required String confidence,
    required String impact,
    required String reason,
    required String recommendation,
  }) {
    final color = severity == 'CRITICAL' ? Colors.red : Colors.orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.04),
        border: Border.all(color: color.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                child: Text(severity, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Text('Confidence: $confidence', style: context.eosText.labelSmall),
              const Spacer(),
              Text('Detected just now', style: context.eosText.bodySmall),
            ],
          ),
          const SizedBox(height: 8),
          Text(title, style: context.eosText.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Impact: $impact', style: context.eosText.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
          Text('Reason: $reason', style: context.eosText.bodySmall),
          const SizedBox(height: 8),
          Text('Recommendation: $recommendation', style: context.eosText.bodySmall?.copyWith(color: Colors.blue)),
        ],
      ),
    );
  }

  Widget _buildGlobalActionCenter(BuildContext context) {
    return EosSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Unified Action Center', style: context.eosText.titleMedium),
            const SizedBox(height: 16),
            _buildActionItem(context, 'Approve Vendors', 12, 'High Priority (Est: 20m)', Colors.red, 2), // Navigate to tab 1
            _buildActionItem(context, 'Release Escrow Settlements', 18, 'Medium Priority (Est: 15m)', Colors.orange, 2),
            _buildActionItem(context, 'Review System Incidents', 3, 'High Priority (Est: 10m)', Colors.red, 3), // Health Tab
            _buildActionItem(context, 'Resolve Security Alerts', 1, 'Low Priority (Est: 5m)', Colors.blue, 7), // Security Tab
          ],
        ),
      ),
    );
  }

  Widget _buildActionItem(BuildContext context, String label, int count, String priority, Color borderCol, int targetTab) {
    return InkWell(
      onTap: () {
        ref.read(superAdminShellTabProvider.notifier).select(targetTab);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: borderCol, width: 4)),
          color: context.eosColors.surfaceVariant.withOpacity(0.2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(priority, style: context.eosText.bodySmall),
              ],
            ),
            CircleAvatar(
              radius: 12,
              backgroundColor: borderCol,
              child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformActivityMap(BuildContext context) {
    final isMobile = EosResponsive.isMobile(context);
    return EosSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Platform Activity Map (Pulse)', style: context.eosText.titleMedium),
            const SizedBox(height: 16),
            // Mock Activity Map graphic
            Container(
              height: 250,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.eosColors.outlineVariant),
              ),
              child: Stack(
                children: [
                  Center(child: Text('LAGOS, ABUJA, IBADAN, ENUGU HOTSPOTS', style: context.eosText.labelSmall)),
                  // Pulsing widgets for map
                  Positioned(
                    top: 80,
                    left: isMobile ? 80 : 120,
                    child: _buildPulseCircle(context, 'Lagos Hub (9 live events)', Colors.green),
                  ),
                  Positioned(
                    top: 150,
                    left: isMobile ? 180 : 280,
                    child: _buildPulseCircle(context, 'Abuja Hub (3 live events)', Colors.blue),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPulseCircle(BuildContext context, String tooltip, Color col) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: col.withOpacity(0.4),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: col, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }

  Widget _buildExecutiveInsightsPanel(BuildContext context) {
    return EosSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Executive Briefing Insights', style: context.eosText.titleMedium),
            const SizedBox(height: 16),
            _buildBriefingItem(context, 'Revenue', 'Wedding & celebration events generate 61% of total platform revenue.'),
            _buildBriefingItem(context, 'Operations', 'Average vendor onboarding and verification times improved by 18% during sandbox staging.'),
            _buildBriefingItem(context, 'Risks', 'Ledger compliance records indicate refunds and payouts stay within baseline tolerances.'),
            _buildBriefingItem(context, 'Compliance', 'Platform verification audits for organizers have completed verification loops.'),
          ],
        ),
      ),
    );
  }

  Widget _buildBriefingItem(BuildContext context, String cat, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: context.eosColors.secondaryContainer, borderRadius: BorderRadius.circular(4)),
            child: Text(cat.toUpperCase(), style: TextStyle(fontSize: 8, color: context.eosColors.onSecondaryContainer, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(desc, style: context.eosText.bodySmall)),
        ],
      ),
    );
  }

  Widget _buildExecutiveScorecards(BuildContext context, dynamic data) {
    final isMobile = EosResponsive.isMobile(context);
    return EosSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Platform Executive Scorecards', style: context.eosText.titleMedium),
            const SizedBox(height: 16),
            if (isMobile) ...[
              _buildTopTenantsList(context, data),
              const SizedBox(height: 24),
              _buildFastestGrowingOrganizers(context, data),
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildTopTenantsList(context, data),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: _buildFastestGrowingOrganizers(context, data),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTopTenantsList(BuildContext context, dynamic data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Top Tenants By Revenue', style: context.eosText.titleSmall),
        const SizedBox(height: 12),
        for (int i = 0; i < data.topTenants.length; i++)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(radius: 10, child: Text('${i + 1}', style: const TextStyle(fontSize: 9))),
            title: Text(data.topTenants[i].name),
            trailing: Text(formatRevenue(data.topTenants[i].revenueMinor)),
            onTap: () {
              context.go('/super-admin/tenants/${data.topTenants[i].id}');
            },
          ),
      ],
    );
  }

  Widget _buildFastestGrowingOrganizers(BuildContext context, dynamic data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Fastest Growing Organizers', style: context.eosText.titleSmall),
        const SizedBox(height: 12),
        for (int i = 0; i < data.topOrganizers.length; i++)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(radius: 10, child: Text('${i + 1}', style: const TextStyle(fontSize: 9))),
            title: Text(data.topOrganizers[i].name),
            trailing: const Text('+12% growth', style: TextStyle(color: Colors.green)),
            onTap: () {
              ref.read(superAdminShellTabProvider.notifier).select(2); // Platform Finance or Tenants tab
            },
          ),
      ],
    );
  }
}

// ==================== KEYBOARD COMMAND PALETTE MODAL ====================

class _CommandPaletteDialog extends ConsumerStatefulWidget {
  const _CommandPaletteDialog();

  @override
  ConsumerState<_CommandPaletteDialog> createState() => _CommandPaletteDialogState();
}

class _CommandPaletteDialogState extends ConsumerState<_CommandPaletteDialog> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> _filteredCommands = [];

  final List<Map<String, dynamic>> _allCommands = [
    {'label': 'Navigate to: Tenants list', 'action': 'nav_tenants', 'tab': 1},
    {'label': 'Navigate to: Platform Finance', 'action': 'nav_finance', 'tab': 2},
    {'label': 'Navigate to: System Health', 'action': 'nav_health', 'tab': 3},
    {'label': 'Navigate to: Feature Flags', 'action': 'nav_flags', 'tab': 4},
    {'label': 'Navigate to: Audit log intelligence', 'action': 'nav_audit', 'tab': 5},
    {'label': 'Navigate to: Platform Security Center', 'action': 'nav_security', 'tab': 7},
    {'label': 'Navigate to: Platform Administration & Governance', 'route': '/super-admin/vendor-governance'},
    {'label': 'Vendor Groups Governance Dashboard', 'route': '/super-admin/vendor-governance'},
    {'label': 'Vendor Policies & Communication Controls', 'route': '/super-admin/vendor-governance'},
    {'label': 'Vendor Compliance Documents & KYC', 'route': '/super-admin/vendor-governance'},
    {'label': 'Vendor Risk Intelligence & Watchlist', 'route': '/super-admin/vendor-governance'},
    {'label': 'Vendor Broadcast Announcement Center', 'route': '/super-admin/vendor-governance'},
    {'label': 'User: Adenike Adebayo (usr_1)', 'route': '/super-admin/users/usr_1'},
    {'label': 'Vendor: Nikkis Catering Ltd (vend_1)', 'route': '/super-admin/vendors/vend_1'},
    {'label': 'Organizer: Alpha Event Group (org_1)', 'route': '/super-admin/organizers/org_1'},
    {'label': 'Event: Owambe Staging Gala (evt_1)', 'route': '/super-admin/events/evt_1'},
    {'label': 'Incident: MFA configuration drift detected (inc_sec_109)', 'route': '/super-admin/incidents/inc_sec_109'},
    {'label': 'Threat: Credential stuffing attempt (thr_1)', 'route': '/super-admin/security/global'},
    {'label': 'Policy: Password Complexity Rules', 'route': '/super-admin/security/global'},
    {'label': 'Role: Lead Organizer RBAC Definition', 'route': '/super-admin/security/global'},
    {'label': 'Device: macOS Sonoma - Adenike Adebayo', 'route': '/super-admin/users/usr_1'},
    {'label': 'Session: sess_99 - Active Session', 'route': '/super-admin/users/usr_1'},
    {'label': 'Service: booking-db-replica PostgreSQL', 'route': '/super-admin/incidents/inc_sec_109'},
    {'label': 'Lookup: Currencies Dictionary', 'route': '/super-admin/vendor-governance'},
    {'label': 'Lookup: Countries Dictionary', 'route': '/super-admin/vendor-governance'},
    {'label': 'Broadcast: Platform Maintenance Announcement', 'route': '/super-admin/vendor-governance'},
    {'label': 'Configuration: SMTP Server & DNS Setup', 'route': '/super-admin/vendor-governance'},
    {'label': 'Feature Flag: Beta Split Payouts', 'route': '/super-admin/vendor-governance'},
    {'label': 'Policy: Rate Limiting & API Backoff', 'route': '/super-admin/vendor-governance'},
    {'label': 'Audit Log: Secrets Rotation Sequence Logs', 'route': '/super-admin/vendor-governance'},
    {'label': 'Analytics 360: Platform Growth Charts', 'route': '/super-admin/analytics/global'},
    {'label': 'Commerce Configuration: Vendor Pricing Rules', 'route': '/super-admin/commerce/vendor-pricing'},
    {'label': 'Navigate to: Commerce Configuration', 'action': 'nav_commerce', 'tab': 8},
    {'label': 'Navigate to: Platform Administration', 'action': 'nav_platform_admin', 'tab': 9},
    {'label': 'Commerce 360: Payout Ledger & Revenue Analytics', 'route': '/super-admin/commerce/global'},
    {'label': 'Security 360: Platform Intrusion Logs', 'route': '/super-admin/security/global'},
    {'label': 'Execute: Release Escrow Payouts', 'action': 'exec_escrow'},
    {'label': 'Execute: Approve pending vendors', 'action': 'exec_vendors'},
  ];

  @override
  void initState() {
    super.initState();
    _filteredCommands = List.from(_allCommands);
  }

  void _onSearch(String query) {
    setState(() {
      _filteredCommands = _allCommands
          .where((c) => (c['label'] as String).toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Search actions, users, incidents, or workspaces (Ctrl+K)...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _onSearch,
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _filteredCommands.length,
                itemBuilder: (context, index) {
                  final c = _filteredCommands[index];
                  return ListTile(
                    title: Text(c['label'] as String),
                    onTap: () {
                      Navigator.pop(context);
                      if (c['route'] != null) {
                        context.go(c['route'] as String);
                      } else if (c['tab'] != null) {
                        ref.read(superAdminShellTabProvider.notifier).select(c['tab'] as int);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Executing: ${c['label']}')),
                        );
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
