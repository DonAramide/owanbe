import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../eos/eos.dart';
import '../../../eos/layout/workspace/workspace_definition.dart';
import '../../../eos/layout/workspace/workspace_shell.dart';
import '../../../eos/layout/workspace/workspace_widgets.dart';
import '../../../platform/identity/identity_mfa_provider.dart';
import '../../../platform/identity/identity_mfa_models.dart';

class User360WorkspaceScreen extends ConsumerStatefulWidget {
  const User360WorkspaceScreen({super.key, required this.userId});
  final String userId;

  @override
  ConsumerState<User360WorkspaceScreen> createState() => _User360WorkspaceScreenState();
}

class _User360WorkspaceScreenState extends ConsumerState<User360WorkspaceScreen> {
  String _userStatus = 'Active';

  @override
  Widget build(BuildContext context) {
    final mfaState = ref.watch(identityMfaProvider);
    final userConfig = mfaState.configs[widget.userId] ?? UserMfaConfig(
      userId: widget.userId,
      email: 'user_${widget.userId}@owanbe.dev',
      isMfaEnabled: false,
      mfaFactor: 'none',
      recoveryCodes: const [],
      trustedDevicesCount: 0,
      activeSessionsCount: 0,
      failedLoginAttempts: 0,
      isLocked: false,
    );

    final definition = WorkspaceDefinition(
      entityType: WorkspaceEntityType.user,
      title: 'User 360 Workspace',
      icon: Icons.person_outline,
      metrics: [
        const WorkspaceMetricDefinition(
          label: 'KYC Status',
          valueResolver: _resolveKycStatus,
          subtitle: 'National ID & biometric match',
        ),
        WorkspaceMetricDefinition(
          label: 'MFA Status',
          valueResolver: (d) => userConfig.isMfaEnabled ? 'ACTIVE (${userConfig.mfaFactor.toUpperCase()})' : 'DISABLED',
          subtitle: 'Multi-factor authentication status',
        ),
        WorkspaceMetricDefinition(
          label: 'Lock Status',
          valueResolver: (d) => userConfig.isLocked ? 'LOCKED' : 'ACTIVE',
          subtitle: 'Account lockout status',
        ),
      ],
      quickActions: [
        WorkspaceActionDefinition(
          label: userConfig.isLocked ? 'Unlock Account' : 'Lock Account',
          icon: userConfig.isLocked ? Icons.lock_open : Icons.lock,
          isDanger: !userConfig.isLocked,
          onPressed: (context, id) async {
            ref.read(identityMfaProvider.notifier).setAccountLock(id, !userConfig.isLocked);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Account lock status updated.')),
            );
          },
        ),
        WorkspaceActionDefinition(
          label: 'Suspend Account',
          icon: Icons.block,
          isDanger: true,
          onPressed: (context, id) async {
            setState(() {
              _userStatus = 'Suspended';
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('User $id has been suspended.')),
            );
          },
        ),
        WorkspaceActionDefinition(
          label: 'Reactivate Account',
          icon: Icons.check_circle_outline,
          onPressed: (context, id) async {
            setState(() {
              _userStatus = 'Active';
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('User $id has been reactivated.')),
            );
          },
        ),
        WorkspaceActionDefinition(
          label: 'Force Logout',
          icon: Icons.logout,
          onPressed: (context, id) async {
            ref.read(identityMfaProvider.notifier).terminateSession(id);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Terminated active session for user $id.')),
            );
          },
        ),
        WorkspaceActionDefinition(
          label: 'Reset MFA',
          icon: Icons.security_update_warning,
          onPressed: (context, id) async {
            ref.read(identityMfaProvider.notifier).disableMfa(id);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('MFA has been reset for user $id.')),
            );
          },
        ),
      ],
      tabs: [
        WorkspaceTabDefinition(
          label: 'Profile',
          builder: (context, id) => _ProfileTabBridge(userId: id, status: _userStatus),
        ),
        WorkspaceTabDefinition(
          label: 'Identity',
          builder: (context, id) => _IdentityTabBridge(userId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Devices',
          builder: (context, id) => _DevicesTabBridge(userId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Sessions',
          builder: (context, id) => _SessionsTabBridge(userId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Roles',
          builder: (context, id) => _RolesTabBridge(userId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Permissions',
          builder: (context, id) => _PermissionsTabBridge(userId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Wallet',
          builder: (context, id) => _WalletTabBridge(userId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Tickets',
          builder: (context, id) => _TicketsTabBridge(userId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Events',
          builder: (context, id) => _EventsTabBridge(userId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Messages',
          builder: (context, id) => _MessagesTabBridge(userId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Audit',
          builder: (context, id) => _AuditTabBridge(userId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Timeline',
          builder: (context, id) => _TimelineTabBridge(userId: id),
        ),
      ],
    );

    return WorkspaceShell(
      definition: definition,
      entityId: widget.userId,
      name: 'Adenike Adebayo',
      logoText: 'AA',
      healthScore: _userStatus == 'Suspended' ? 0 : 98,
      environment: 'Production',
      region: 'NG-LAGOS',
      primaryContact: 'adenike@owanbe.dev',
      createdDate: '2026-05-12',
      lastActivity: 'Active 4m ago',
      sidebarWidgets: [
        WorkspaceHealthPanel(
          healthScore: _userStatus == 'Suspended' ? 0 : 98,
          factors: [
            'User status: $_userStatus',
            'KYC verification tier: Tier 3',
            'MFA active: ${userConfig.isMfaEnabled ? userConfig.mfaFactor.toUpperCase() : 'NO'}',
          ],
        ),
      ],
    );
  }

  static String _resolveKycStatus(dynamic d) => 'VERIFIED';
}

// ==================== USER TAB BRIDGES ====================

class _ProfileTabBridge extends StatelessWidget {
  const _ProfileTabBridge({required this.userId, required this.status});
  final String userId;
  final String status;

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
                Text('User Demographic Profile', style: context.eosText.titleMedium),
                const Divider(height: 24),
                _buildField(context, 'Full Name', 'Adenike Adebayo'),
                _buildField(context, 'ID', userId),
                _buildField(context, 'Account Status', status),
                _buildField(context, 'Email Address', 'adenike@owanbe.dev'),
                _buildField(context, 'Phone Number', '+234 809 123 4567'),
                _buildField(context, 'KYC Verification Tier', 'Tier 3 (Government ID Verified)'),
                _buildField(context, 'Registered On', '2026-05-12 10:44:00'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildField(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Text('$label: ', style: context.eosText.labelMedium),
          Text(value, style: context.eosText.bodyMedium),
        ],
      ),
    );
  }
}

class _IdentityTabBridge extends ConsumerWidget {
  const _IdentityTabBridge({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mfaState = ref.watch(identityMfaProvider);
    final userConfig = mfaState.configs[userId] ?? UserMfaConfig(
      userId: userId,
      email: 'user_$userId@owanbe.dev',
      isMfaEnabled: false,
      mfaFactor: 'none',
      recoveryCodes: const [],
      trustedDevicesCount: 0,
      activeSessionsCount: 0,
      failedLoginAttempts: 0,
      isLocked: false,
    );

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        EosSurfaceCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Credentials & Authentication Config', style: context.eosText.titleMedium),
                const Divider(height: 24),
                ListTile(
                  leading: const Icon(Icons.password, color: Colors.blue),
                  title: const Text('Password Credentials'),
                  subtitle: const Text('Last changed 45 days ago'),
                  trailing: OutlinedButton(onPressed: () {}, child: const Text('Invalidate')),
                ),
                ListTile(
                  leading: Icon(Icons.phone_android, color: userConfig.isMfaEnabled ? Colors.green : Colors.grey),
                  title: Text('MFA Authenticator (${userConfig.mfaFactor.toUpperCase()})'),
                  subtitle: Text(userConfig.isMfaEnabled ? 'Status: Active' : 'Status: Disabled'),
                  trailing: userConfig.isMfaEnabled
                      ? OutlinedButton(
                          onPressed: () => ref.read(identityMfaProvider.notifier).disableMfa(userId),
                          child: const Text('Deactivate MFA'),
                        )
                      : OutlinedButton(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Enroll in Multi-Factor Authentication'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('Scan the QR code with your authenticator app (like Google Authenticator):'),
                                    const SizedBox(height: 16),
                                    Container(
                                      width: 140,
                                      height: 140,
                                      color: Colors.white,
                                      padding: const EdgeInsets.all(8),
                                      child: const Icon(Icons.qr_code_2, size: 120, color: Colors.black),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text('Enter 6-digit verification code below:'),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () {
                                      ref.read(identityMfaProvider.notifier).enrollMfa(userId, 'totp');
                                      Navigator.pop(context);
                                    },
                                    child: const Text('Verify & Activate'),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: const Text('Enroll MFA'),
                        ),
                ),
                if (userConfig.isMfaEnabled) ...[
                  const Divider(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Security Recovery Codes', style: context.eosText.titleSmall),
                      TextButton.icon(
                        icon: const Icon(Icons.refresh, size: 14),
                        label: const Text('Regenerate Codes'),
                        onPressed: () => ref.read(identityMfaProvider.notifier).regenerateRecoveryCodes(userId),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final code in userConfig.recoveryCodes)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.grey.withOpacity(0.2)),
                          ),
                          child: Text(
                            code,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DevicesTabBridge extends ConsumerWidget {
  const _DevicesTabBridge({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mfaState = ref.watch(identityMfaProvider);
    final userConfig = mfaState.configs[userId] ?? UserMfaConfig(
      userId: userId,
      email: 'user_$userId@owanbe.dev',
      isMfaEnabled: false,
      mfaFactor: 'none',
      recoveryCodes: const [],
      trustedDevicesCount: 0,
      activeSessionsCount: 0,
      failedLoginAttempts: 0,
      isLocked: false,
    );

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Registered Trusted Workstations', style: context.eosText.titleMedium),
            FilledButton.icon(
              icon: const Icon(Icons.add_to_queue),
              label: const Text('Register Workstation'),
              onPressed: () => ref.read(identityMfaProvider.notifier).registerTrustedDevice(userId),
            ),
          ],
        ),
        const SizedBox(height: 12),
        EosDataTable(
          columns: const [
            DataColumn(label: Text('Device OS')),
            DataColumn(label: Text('Browser')),
            DataColumn(label: Text('Last IP')),
            DataColumn(label: Text('Status')),
          ],
          rows: [
            for (int i = 0; i < userConfig.trustedDevicesCount; i++)
              DataRow(cells: [
                DataCell(Text(i == 0 ? 'macOS Sonoma' : 'Windows 11 Enterprise')),
                const DataCell(Text('Chrome v124')),
                const DataCell(Text('197.210.64.2')),
                const DataCell(Text('TRUSTED')),
              ]),
            if (userConfig.trustedDevicesCount == 0)
              const DataRow(cells: [
                DataCell(Text('No trusted devices registered')),
                DataCell(Text('-')),
                DataCell(Text('-')),
                DataCell(Text('-')),
              ]),
          ],
        ),
      ],
    );
  }
}

class _SessionsTabBridge extends ConsumerWidget {
  const _SessionsTabBridge({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mfaState = ref.watch(identityMfaProvider);
    final userConfig = mfaState.configs[userId] ?? UserMfaConfig(
      userId: userId,
      email: 'user_$userId@owanbe.dev',
      isMfaEnabled: false,
      mfaFactor: 'none',
      recoveryCodes: const [],
      trustedDevicesCount: 0,
      activeSessionsCount: 0,
      failedLoginAttempts: 0,
      isLocked: false,
    );

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Active Connection Sessions', style: context.eosText.titleMedium),
        const SizedBox(height: 12),
        EosDataTable(
          columns: const [
            DataColumn(label: Text('Session ID')),
            DataColumn(label: Text('IP Address')),
            DataColumn(label: Text('Location')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Actions')),
          ],
          rows: [
            for (int i = 0; i < userConfig.activeSessionsCount; i++)
              DataRow(cells: [
                DataCell(Text('sess_9$i')),
                const DataCell(Text('197.210.64.2')),
                const DataCell(Text('Lagos, Nigeria')),
                const DataCell(Text('ACTIVE')),
                DataCell(
                  TextButton(
                    onPressed: () => ref.read(identityMfaProvider.notifier).terminateSession(userId),
                    child: const Text('Terminate', style: TextStyle(color: Colors.redAccent)),
                  ),
                ),
              ]),
            if (userConfig.activeSessionsCount == 0)
              const DataRow(cells: [
                DataCell(Text('No active sessions')),
                DataCell(Text('-')),
                DataCell(Text('-')),
                DataCell(Text('INACTIVE')),
                DataCell(Text('-')),
              ]),
          ],
        ),
      ],
    );
  }
}

class _RolesTabBridge extends StatelessWidget {
  const _RolesTabBridge({required this.userId});
  final String userId;

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
                Text('Assigned Application Roles', style: context.eosText.titleMedium),
                const Divider(height: 24),
                ListTile(
                  leading: const Icon(Icons.badge, color: Colors.blue),
                  title: const Text('Attendee / Client'),
                  subtitle: const Text('Direct assignment'),
                ),
                ListTile(
                  leading: const Icon(Icons.business_center, color: Colors.purple),
                  title: const Text('Lead Organizer'),
                  subtitle: const Text('Assigned via Alpha Tenant'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PermissionsTabBridge extends StatelessWidget {
  const _PermissionsTabBridge({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        EosDataTable(
          columns: const [
            DataColumn(label: Text('Permission Name')),
            DataColumn(label: Text('Origin')),
            DataColumn(label: Text('Scope')),
          ],
          rows: const [
            DataRow(cells: [
              DataCell(Text('event:create')),
              DataCell(Text('Role: Lead Organizer')),
              DataCell(Text('Tenant-wide')),
            ]),
            DataRow(cells: [
              DataCell(Text('ticket:buy')),
              DataCell(Text('Role: Attendee')),
              DataCell(Text('Global')),
            ]),
          ],
        ),
      ],
    );
  }
}

class _WalletTabBridge extends StatelessWidget {
  const _WalletTabBridge({required this.userId});
  final String userId;

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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('EOS Platform Wallet Balance', style: context.eosText.titleMedium),
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.ac_unit, size: 14),
                      label: const Text('Freeze Wallet'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('₦450,000.00', style: context.eosText.headlineMedium?.copyWith(color: Colors.green, fontWeight: FontWeight.bold)),
                const Divider(height: 32),
                Text('Wallet Transactions Logs', style: context.eosText.titleSmall),
                const SizedBox(height: 12),
                EosDataTable(
                  columns: const [
                    DataColumn(label: Text('Ref ID')),
                    DataColumn(label: Text('Description')),
                    DataColumn(label: Text('Amount')),
                    DataColumn(label: Text('Status')),
                  ],
                  rows: const [
                    DataRow(cells: [
                      DataCell(Text('tx_4891')),
                      DataCell(Text('Event Ticket Purchase - Gala VIP')),
                      DataCell(Text('-₦35,000.00')),
                      DataCell(Text('SETTLED')),
                    ]),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TicketsTabBridge extends StatelessWidget {
  const _TicketsTabBridge({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        EosDataTable(
          columns: const [
            DataColumn(label: Text('Ticket Code')),
            DataColumn(label: Text('Event')),
            DataColumn(label: Text('Tier')),
            DataColumn(label: Text('Checked In')),
          ],
          rows: const [
            DataRow(cells: [
              DataCell(Text('TCK-990-281')),
              DataCell(Text('Owambe Staging Gala')),
              DataCell(Text('VIP')),
              DataCell(Text('YES - 2026-06-29 00:04')),
            ]),
          ],
        ),
      ],
    );
  }
}

class _EventsTabBridge extends StatelessWidget {
  const _EventsTabBridge({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        EosDataTable(
          columns: const [
            DataColumn(label: Text('Event ID')),
            DataColumn(label: Text('Event Name')),
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('Role')),
          ],
          rows: const [
            DataRow(cells: [
              DataCell(Text('evt_1')),
              DataCell(Text('Owambe Staging Gala')),
              DataCell(Text('2026-07-04')),
              DataCell(Text('Attendee')),
            ]),
          ],
        ),
      ],
    );
  }
}

class _MessagesTabBridge extends StatelessWidget {
  const _MessagesTabBridge({required this.userId});
  final String userId;

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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Direct Notifications Logs', style: context.eosText.titleMedium),
                    ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.send, size: 14),
                      label: const Text('Broadcast Message'),
                    ),
                  ],
                ),
                const Divider(height: 24),
                ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: const Text('MFA Verification Code Email'),
                  subtitle: const Text('Delivered to adenike@owanbe.dev'),
                  trailing: const Text('10m ago'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AuditTabBridge extends ConsumerWidget {
  const _AuditTabBridge({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mfaState = ref.watch(identityMfaProvider);
    final userLogs = mfaState.logs.where((l) => l.userId == userId).toList();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        EosDataTable(
          columns: const [
            DataColumn(label: Text('Action / Event')),
            DataColumn(label: Text('Operator / IP')),
            DataColumn(label: Text('Timestamp')),
            DataColumn(label: Text('Details')),
          ],
          rows: [
            for (final log in userLogs)
              DataRow(cells: [
                DataCell(EosFinanceChip(label: log.eventType, compact: true)),
                DataCell(Text(log.ipAddress)),
                DataCell(Text(log.timestamp)),
                DataCell(Text(log.details)),
              ]),
            if (userLogs.isEmpty)
              const DataRow(cells: [
                DataCell(Text('No events')),
                DataCell(Text('-')),
                DataCell(Text('-')),
                DataCell(Text('No security logs found')),
              ]),
          ],
        ),
      ],
    );
  }
}

class _TimelineTabBridge extends StatelessWidget {
  const _TimelineTabBridge({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        WorkspaceTimeline(
          items: [
            WorkspaceTimelineItem(
              title: 'Login Success',
              description: 'Authenticated from Chrome / Lagos, NG (197.210.64.2)',
              timestamp: '4m ago',
              category: 'security',
              icon: Icons.login,
              iconColor: Colors.green,
            ),
            WorkspaceTimelineItem(
              title: 'Ticket Checked In',
              description: 'Checked into Owambe Staging Gala (VIP tier)',
              timestamp: '2h ago',
              category: 'operations',
              icon: Icons.confirmation_number,
              iconColor: Colors.blue,
            ),
          ],
        ),
      ],
    );
  }
}

class _SecurityTabBridge extends StatelessWidget {
  const _SecurityTabBridge({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        EosDataTable(
          columns: const [
            DataColumn(label: Text('Event Type')),
            DataColumn(label: Text('Source IP')),
            DataColumn(label: Text('Risk Assessment')),
            DataColumn(label: Text('Timestamp')),
          ],
          rows: const [
            DataRow(cells: [
              DataCell(Text('Suspicious session replay detection')),
              DataCell(Text('102.89.23.4')),
              DataCell(Text('MEDIUM (Risk: 82/100)')),
              DataCell(Text('2026-06-29 01:04')),
            ]),
          ],
        ),
      ],
    );
  }
}
