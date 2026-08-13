import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../eos.dart';
import '../../layout/workspace/entity_engine.dart';
import '../../layout/workspace/workspace_widgets.dart';
import '../../services/platform_admin_services.dart';
import '../../../features/super_admin/platform_admin/mdm_workspace_screen.dart';
import '../../../features/super_admin/platform_admin/workflow_studio_screen.dart';
import '../../../features/super_admin/platform_admin/communication_center_screen.dart';
import '../../../features/super_admin/platform_admin/copilot_workspace_screen.dart';
import '../../../features/super_admin/platform_admin/integration_hub_screen.dart';
import '../../../features/super_admin/platform_admin/enterprise_email_infrastructure_screen.dart';
import '../../../core/api/control_plane_api.dart';
import '../../../core/api/identity_security_api.dart';

class AuditEvent {
  final String who;
  final String affected;
  final String timestamp;
  final String action;
  final String reason;
  final String prevVal;
  final String newVal;
  final String correlationId;

  AuditEvent({
    required this.who,
    required this.affected,
    required this.timestamp,
    required this.action,
    required this.reason,
    required this.prevVal,
    required this.newVal,
    required this.correlationId,
  });
}

class AdminNavigationShell extends ConsumerStatefulWidget {
  const AdminNavigationShell({super.key});

  @override
  ConsumerState<AdminNavigationShell> createState() => _AdminNavigationShellState();
}

class _AdminNavigationShellState extends ConsumerState<AdminNavigationShell> {
  int _activeTab = 0;
  String _userSearchQuery = '';
  String _selectedUserType = 'All';

  // Audit Logs State
  final List<AuditEvent> _auditLogs = [
    AuditEvent(
      who: 'Platform Super Admin',
      affected: 'usr_1 (Adenike Adebayo)',
      timestamp: '2026-06-29 03:22:00',
      action: 'SUSPEND_ACCOUNT',
      reason: 'MFA Configuration Drift Detections',
      prevVal: 'ACTIVE',
      newVal: 'SUSPENDED',
      correlationId: 'tx_sec_1092',
    ),
  ];

  // User list state
  final List<Map<String, String>> _usersList = [
    {'id': 'usr_1', 'name': 'Adenike Adebayo', 'type': 'Finance', 'status': 'ACTIVE', 'mfa': 'YES'},
    {'id': 'usr_2', 'name': 'Chidi Benson', 'type': 'Organizer', 'status': 'PENDING', 'mfa': 'NO'},
    {'id': 'usr_3', 'name': 'Femi Balogun', 'type': 'Vendor', 'status': 'ACTIVE', 'mfa': 'YES'},
    {'id': 'usr_4', 'name': 'Fatima Musa', 'type': 'Attendee', 'status': 'SUSPENDED', 'mfa': 'NO'},
  ];

  // Verification lists state
  final List<Map<String, String>> _verifications = [
    {'id': 'org_1', 'name': 'Alpha Event Group', 'type': 'Organizer', 'cac': 'CAC-291834', 'status': 'PENDING'},
    {'id': 'vend_1', 'name': 'Nikkis Catering Ltd', 'type': 'Vendor', 'cac': 'CAC-771899', 'status': 'PENDING'},
  ];

  // Lookup settings state
  final List<Map<String, String>> _lookups = [
    {'category': 'Supported Currencies', 'elements': 'NGN, USD, EUR'},
    {'category': 'Supported Countries', 'elements': 'Nigeria, United Kingdom, United States'},
    {'category': 'Event Categories', 'elements': 'Wedding, Gala, Concert, Conference'},
  ];

  // Maintenance configurations
  bool _maintenanceMode = false;
  bool _checkoutDisabled = false;

  void _logAuditEvent(String action, String affected, String prevVal, String newVal, String reason) {
    AdminAuditService.logAdminAction(
      action: action,
      target: affected,
      prevVal: prevVal,
      newVal: newVal,
      reason: reason,
    );
    setState(() {
      _auditLogs.insert(
        0,
        AuditEvent(
          who: 'Platform Super Admin',
          affected: affected,
          timestamp: DateTime.now().toString().split('.').first,
          action: action,
          reason: reason,
          prevVal: prevVal,
          newVal: newVal,
          correlationId: 'tx_admin_${DateTime.now().millisecondsSinceEpoch}',
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return EosPageScaffold(
      title: 'Platform Administration',
      subtitle: 'Platform-wide configuration, broadcast center, moderation & maintenance',
      bodyScrollable: false,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 240,
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: context.eosColors.outlineVariant)),
            ),
            child: ListView(
              children: [
                _buildNavItem(0, 'User Directory', Icons.people),
                _buildNavItem(1, 'Verification Center', Icons.verified_user),
                _buildNavItem(2, 'Communication Center', Icons.message),
                _buildNavItem(3, 'Maintenance Center', Icons.build),
                _buildNavItem(4, 'Platform Master Data', Icons.dns),
                _buildNavItem(5, 'Marketplace Moderation', Icons.gavel),
                _buildNavItem(6, 'Commerce Configuration', Icons.sell_outlined),
                _buildNavItem(7, 'Governance Audit Logs', Icons.history_edu),
                _buildNavItem(8, 'Workflow Studio', Icons.account_tree),
                _buildNavItem(9, 'Platform Copilot', Icons.psychology),
                _buildNavItem(10, 'Integration Hub', Icons.hub),
                _buildNavItem(11, 'Enterprise Email', Icons.mark_email_unread),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: SingleChildScrollView(
              child: _buildActivePanel(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, String label, IconData icon) {
    final active = _activeTab == index;
    return ListTile(
      selected: active,
      leading: Icon(icon, size: 16, color: active ? context.eosColors.primary : null),
      title: Text(label, style: context.eosText.labelMedium?.copyWith(fontWeight: active ? FontWeight.bold : null)),
      onTap: () => setState(() => _activeTab = index),
    );
  }

  Widget _buildActivePanel() {
    return switch (_activeTab) {
      0 => _buildUserDirectoryPanel(),
      1 => _buildVerificationCenterPanel(),
      2 => const CommunicationCenterScreen(),
      3 => _buildMaintenanceCenterPanel(),
      4 => const MdmWorkspaceScreen(),
      5 => _buildMarketplacePanel(),
      6 => const _CommerceConfigurationPanel(),
      7 => _buildGovernanceAuditLogsPanel(),
      8 => const WorkflowStudioScreen(),
      9 => const CopilotWorkspaceScreen(),
      10 => const IntegrationHubScreen(),
      _ => const EnterpriseEmailInfrastructureScreen(),
    };
  }

  Widget _buildUserDirectoryPanel() {
    final usersAsync = ref.watch(identitySecurityUsersProvider(_userSearchQuery));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('User Directory', style: context.eosText.titleMedium),
        const SizedBox(height: 8),
        Text(
          'Nest identity-security users (Phase 29) — not hardcoded seed rows.',
          style: context.eosText.bodySmall,
        ),
        const SizedBox(height: 12),
        EosSearchBar(
          hintText: 'Search users by email or name…',
          onChanged: (val) => setState(() => _userSearchQuery = val),
        ),
        const SizedBox(height: 16),
        usersAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('User directory unavailable: $e'),
          data: (items) {
            if (items.isEmpty) {
              return const Text('No users found.');
            }
            return EosDataTable(
              columns: const [
                DataColumn(label: Text('User ID')),
                DataColumn(label: Text('Email')),
                DataColumn(label: Text('Tenant')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Actions')),
              ],
              rows: [
                for (final u in items.take(50))
                  DataRow(cells: [
                    DataCell(Text('${u['id']}'.substring(0, 8))),
                    DataCell(Text('${u['email'] ?? ''}')),
                    DataCell(Text('${u['tenantSlug'] ?? ''}')),
                    DataCell(Text('${u['status'] ?? ''}')),
                    DataCell(Row(
                      children: [
                        if (u['status'] != 'suspended')
                          IconButton(
                            icon: const Icon(Icons.block, size: 14, color: Colors.red),
                            onPressed: () async {
                              try {
                                await AdminUserService.suspendUser(
                                  u['id'].toString(),
                                  reason: 'Administrative Suspension',
                                );
                                  ref.invalidate(identitySecurityUsersProvider(_userSearchQuery));
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Suspended ${u['email']}')),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('$e')),
                                    );
                                  }
                                }
                              },
                            ),
                          if (u['status'] == 'suspended')
                            TextButton(
                              onPressed: () async {
                                await AdminUserService.reactivateUser(u['id'].toString());
                                ref.invalidate(identitySecurityUsersProvider(_userSearchQuery));
                              },
                              child: const Text('Restore'),
                            ),
                        ],
                      )),
                    ]),
                ],
              );
            },
        ),
      ],
    );
  }

  Widget _buildVerificationCenterPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Vendor & Organizer Verification Queue', style: context.eosText.titleMedium),
        const SizedBox(height: 12),
        EosDataTable(
          columns: const [
            DataColumn(label: Text('Verification Target')),
            DataColumn(label: Text('Details')),
            DataColumn(label: Text('CAC Registry')),
            DataColumn(label: Text('Action')),
          ],
          rows: [
            for (final v in _verifications)
              DataRow(cells: [
                DataCell(Text(v['name']!)),
                DataCell(Text('${v['type']!} Onboarding')),
                DataCell(Text(v['cac']!)),
                DataCell(Row(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        if (v['type'] == 'Vendor') {
                          AdminVendorService.approveVendor(v['id']!);
                        } else {
                          AdminOrganizerService.approveOrganizer(v['id']!);
                        }
                        setState(() => v['status'] = 'VERIFIED');
                        _logAuditEvent('APPROVE_ONBOARDING', v['name']!, 'PENDING', 'VERIFIED', 'Business documents validated.');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Verified ${v['name']} successfully.')),
                        );
                      },
                      child: const Text('Verify'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        if (v['type'] == 'Vendor') {
                          AdminVendorService.rejectVendor(v['id']!);
                        } else {
                          AdminOrganizerService.rejectOrganizer(v['id']!);
                        }
                        setState(() => v['status'] = 'REJECTED');
                        _logAuditEvent('REJECT_ONBOARDING', v['name']!, 'PENDING', 'REJECTED', 'Invalid documentation');
                      },
                      child: const Text('Reject', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                )),
              ]),
          ],
        ),
      ],
    );
  }

  Widget _buildBroadcastCenterPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Broadcast Notification Center', style: context.eosText.titleMedium),
        const SizedBox(height: 16),
        EosSurfaceCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TextField(
                  decoration: InputDecoration(
                    labelText: 'Broadcast Header Subject',
                    hintText: 'Maintenance Announcement',
                  ),
                ),
                const SizedBox(height: 12),
                const TextField(
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Notification Content Body',
                    hintText: 'System under scheduled maintenance window next Friday.',
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        AdminBroadcastService.sendBroadcast(
                          channel: 'all',
                          target: 'everyone',
                          subject: 'Maintenance Announcement',
                          body: 'System under scheduled maintenance window.',
                        );
                        _logAuditEvent('BROADCAST_ALL', 'SYSTEM', 'NONE', 'BROADCAST_QUEUED', 'Global platform notify');
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Broadcast queued to everyone successfully.')),
                        );
                      },
                      icon: const Icon(Icons.send),
                      label: const Text('Broadcast Notification to Everyone'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        AdminBroadcastService.sendBroadcast(
                          channel: 'email',
                          target: 'vendors',
                          subject: 'Maintenance Announcement',
                          body: 'System under scheduled maintenance window.',
                        );
                        _logAuditEvent('BROADCAST_VENDORS', 'VENDORS', 'NONE', 'BROADCAST_QUEUED', 'Vendor communications dispatch');
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Broadcast queued to all Vendors.')),
                        );
                      },
                      icon: const Icon(Icons.campaign),
                      label: const Text('Target Vendors Only'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMaintenanceCenterPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Platform Lockdown & Operations Control Center', style: context.eosText.titleMedium),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildLockdownCard('Checkout & Ticket Sales', 'Checkout endpoints status', !_checkoutDisabled, (v) {
                final prev = !_checkoutDisabled;
                AdminMaintenanceService.setCheckoutStatus(v);
                setState(() => _checkoutDisabled = !v);
                _logAuditEvent('LOCKDOWN_CHECKOUT', 'CHECKOUT_SERVICE', prev ? 'LIVE' : 'DISABLED', !prev ? 'LIVE' : 'DISABLED', 'SaaS maintenance rules applied.');
              }),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildLockdownCard('System Maintenance Mode', 'Platform-wide logins status', !_maintenanceMode, (v) {
                final prev = !_maintenanceMode;
                AdminMaintenanceService.setMaintenanceMode(!v);
                setState(() => _maintenanceMode = !v);
                _logAuditEvent('LOCKDOWN_SYSTEM', 'PLATFORM_LOGIN', prev ? 'LIVE' : 'DISABLED', !prev ? 'LIVE' : 'DISABLED', 'Emergency operational rules applied.');
              }),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLockdownCard(String title, String subtitle, bool isLive, ValueChanged<bool> onChanged) {
    return EosSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: context.eosText.titleSmall),
            const SizedBox(height: 8),
            Text(subtitle, style: context.eosText.bodySmall),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enforced'),
              value: !isLive,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigurationPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Platform Master Lookup Configurations', style: context.eosText.titleMedium),
        const SizedBox(height: 16),
        EosDataTable(
          columns: const [
            DataColumn(label: Text('Lookup Dictionary')),
            DataColumn(label: Text('Active Elements')),
            DataColumn(label: Text('Actions')),
          ],
          rows: [
            for (final l in _lookups)
              DataRow(cells: [
                DataCell(Text(l['category']!)),
                DataCell(Text(l['elements']!)),
                DataCell(Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 14),
                      onPressed: () {
                        AdminLookupService.updateLookup(l['category']!, '${l['elements']!}, NEW_VAL');
                        _logAuditEvent('EDIT_LOOKUP', l['category']!, l['elements']!, '${l['elements']!}, NEW_VAL', 'Added metadata entry');
                        setState(() => l['elements'] = '${l['elements']!}, NEW_VAL');
                      },
                    ),
                  ],
                )),
              ]),
          ],
        ),
      ],
    );
  }

  Widget _buildMarketplacePanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Marketplace Listings Moderation Center', style: context.eosText.titleMedium),
        const SizedBox(height: 12),
        EosDataTable(
          columns: const [
            DataColumn(label: Text('Listing Name')),
            DataColumn(label: Text('Owner')),
            DataColumn(label: Text('Review Rating')),
            DataColumn(label: Text('Moderation Status')),
          ],
          rows: [
            DataRow(cells: [
              const DataCell(Text('Owambe Staging Gala')),
              const DataCell(Text('Alpha Event Group')),
              const DataCell(Text('4.8 / 5.0')),
              DataCell(EosFinanceChip(label: 'APPROVED', compact: true)),
            ]),
          ],
        ),
      ],
    );
  }

  Widget _buildGovernanceAuditLogsPanel() {
    return const _ControlPlaneAuditPanel();
  }
}

/// Control Tower → Commerce Configuration — deep-link only (no duplicate CRUD).
class _CommerceConfigurationPanel extends StatelessWidget {
  const _CommerceConfigurationPanel();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Commerce Configuration', style: context.eosText.titleMedium),
        const SizedBox(height: 8),
        Text(
          'Platform commerce controls. Vendor Pricing opens the existing Platform Admin editor — '
          'single source of truth (no duplicate screens).',
          style: context.eosText.bodySmall,
        ),
        const SizedBox(height: 16),
        EosSurfaceCard(
          elevated: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vendor Pricing',
                style: context.eosText.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Global default, service category, vendor, and vendor+service markup rules. '
                'Same screen as Platform Admin → Settings → Vendor Pricing Rules.',
                style: context.eosText.bodyMedium,
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: () => context.push('/super-admin/commerce/vendor-pricing'),
                icon: const Icon(Icons.percent),
                label: const Text('Open Vendor Pricing'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ControlPlaneAuditPanel extends ConsumerWidget {
  const _ControlPlaneAuditPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(controlPlaneActivityProvider);
    final dash = ref.watch(controlPlaneDashboardProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Control plane audit', style: context.eosText.titleMedium),
        const SizedBox(height: 8),
        Text(
          'Live Nest audit_log (control_plane.* / mdm.* / tenant_* / vendor_*)',
          style: context.eosText.bodySmall,
        ),
        const SizedBox(height: 16),
        dash.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Dashboard: $e'),
          data: (d) => Wrap(
            spacing: 8,
            children: [
              Chip(label: Text('Tenants ${d['tenantsByStatus']}')),
              Chip(label: Text('Vendors ${d['vendorsByStatus']}')),
              Chip(label: Text('MDM ${d['mdm']}')),
            ],
          ),
        ),
        const SizedBox(height: 16),
        activity.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Audit unavailable: $e'),
          data: (items) {
            if (items.isEmpty) {
              return const Text('No control-plane audit events yet');
            }
            return EosDataTable(
              columns: const [
                DataColumn(label: Text('Action')),
                DataColumn(label: Text('Resource')),
                DataColumn(label: Text('When')),
              ],
              rows: [
                for (final a in items.take(40))
                  DataRow(cells: [
                    DataCell(Text('${a['action']}')),
                    DataCell(Text('${a['resourceType']} ${a['resourceId'] ?? ''}')),
                    DataCell(Text('${a['createdAt'] ?? ''}')),
                  ]),
              ],
            );
          },
        ),
      ],
    );
  }
}
