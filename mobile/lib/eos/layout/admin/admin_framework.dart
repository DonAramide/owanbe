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
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Navigation Side bar
          Container(
            width: 240,
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: context.eosColors.outlineVariant)),
            ),
            child: Column(
              children: [
                _buildNavItem(0, 'User Directory', Icons.people),
                _buildNavItem(1, 'Verification Center', Icons.verified_user),
                _buildNavItem(2, 'Communication Center', Icons.message),
                _buildNavItem(3, 'Maintenance Center', Icons.build),
                _buildNavItem(4, 'Platform Master Data', Icons.dns),
                _buildNavItem(5, 'Marketplace Moderation', Icons.gavel),
                _buildNavItem(6, 'Governance Audit Logs', Icons.history_edu),
                _buildNavItem(7, 'Workflow Studio', Icons.account_tree),
                _buildNavItem(8, 'Platform Copilot', Icons.psychology),
                _buildNavItem(9, 'Integration Hub', Icons.hub),
              ],
            ),
          ),
          const SizedBox(width: 24),

          // Active Panel area
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
      6 => _buildGovernanceAuditLogsPanel(),
      7 => const WorkflowStudioScreen(),
      8 => const CopilotWorkspaceScreen(),
      _ => const IntegrationHubScreen(),
    };
  }

  Widget _buildUserDirectoryPanel() {
    final filtered = _usersList.where((u) {
      final matchSearch = u['name']!.toLowerCase().contains(_userSearchQuery.toLowerCase());
      final matchType = _selectedUserType == 'All' || u['type'] == _selectedUserType;
      return matchSearch && matchType;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('User Directory', style: context.eosText.titleMedium),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: EosSearchBar(
                hintText: 'Search user portfolio directories...',
                onChanged: (val) => setState(() => _userSearchQuery = val),
              ),
            ),
            const SizedBox(width: 12),
            DropdownButton<String>(
              value: _selectedUserType,
              items: ['All', 'Finance', 'Organizer', 'Vendor', 'Attendee'].map((t) {
                return DropdownMenuItem(value: t, child: Text(t));
              }).toList(),
              onChanged: (val) => setState(() => _selectedUserType = val ?? 'All'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        EosDataTable(
          columns: const [
            DataColumn(label: Text('User ID')),
            DataColumn(label: Text('Display Name')),
            DataColumn(label: Text('MFA Active')),
            DataColumn(label: Text('Account Status')),
            DataColumn(label: Text('Actions')),
          ],
          rows: [
            for (final u in filtered)
              DataRow(cells: [
                DataCell(Text(u['id']!)),
                DataCell(Text('${u['name']!} (${u['type']!})')),
                DataCell(Text(u['mfa']!)),
                DataCell(Text(u['status']!)),
                DataCell(Row(
                  children: [
                    TextButton(
                      onPressed: () => context.go('/super-admin/users/${u['id']!}'),
                      child: const Text('Open User360'),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.block, size: 14, color: Colors.red),
                      onPressed: () {
                        final prev = u['status']!;
                        AdminUserService.suspendUser(u['id']!);
                        setState(() => u['status'] = 'SUSPENDED');
                        _logAuditEvent('SUSPEND_USER', u['id']!, prev, 'SUSPENDED', 'Administrative Suspension');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Suspended ${u['name']} successfully.')),
                        );
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Governance Audit Log Matrix', style: context.eosText.titleMedium),
        const SizedBox(height: 16),
        EosDataTable(
          columns: const [
            DataColumn(label: Text('Correlation ID')),
            DataColumn(label: Text('Operator')),
            DataColumn(label: Text('Affected Target')),
            DataColumn(label: Text('Action Type')),
            DataColumn(label: Text('Transition')),
          ],
          rows: [
            for (final audit in _auditLogs)
              DataRow(cells: [
                DataCell(Text(audit.correlationId)),
                DataCell(Text(audit.who)),
                DataCell(Text(audit.affected)),
                DataCell(Text(audit.action)),
                DataCell(Text('${audit.prevVal} -> ${audit.newVal}')),
              ]),
          ],
        ),
      ],
    );
  }
}
