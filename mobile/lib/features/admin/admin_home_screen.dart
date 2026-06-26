import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/auth_notifier.dart';
import '../../auth/user_role.dart';
import 'finance/admin_finance_providers.dart';
import 'platform/event_oversight_screen.dart';
import 'platform/launch_ops_dashboard_screen.dart';
import 'platform/operations_center_screen.dart';
import 'platform/organizer_oversight_screen.dart';
import 'platform/platform_dashboard_screen.dart';
import 'platform/vendor_oversight_screen.dart';
import 'screens/admin_audit_screen.dart';
import 'screens/admin_compliance_screen.dart';
import 'screens/admin_finance_screen.dart';
import 'screens/admin_settings_screen.dart';
import 'shell/admin_shell.dart';
import 'shell/admin_top_bar.dart';

class AdminHomeScreen extends ConsumerWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);
    final financeState = ref.watch(financeStateProvider);
    final shell = ref.watch(adminShellTabProvider);

    return AdminShell(
      selectedIndex: shell.tab,
      onSelected: (v) => ref.read(adminShellTabProvider.notifier).select(v),
      topBar: AdminTopBar(
        displayName: session?.displayName ?? 'Platform Admin',
        roleLabel: session?.role.label ?? 'Admin',
        environmentLabel: kDebugMode ? 'Development' : 'Production',
        financeState: financeState,
        onSetFinanceState: (v) async {
          await ref.read(adminFinanceApiProvider).setFinanceState(v);
          ref.invalidate(financeStateProvider);
        },
        onSignOut: () async {
          await ref.read(authSessionProvider.notifier).signOut();
          if (context.mounted) context.go('/');
        },
      ),
      body: _bodyForTab(shell),
    );
  }

  Widget _bodyForTab(AdminShellState shell) => switch (shell.tab) {
        0 => const LaunchOpsDashboardScreen(),
        1 => const OrganizerOversightScreen(),
        2 => const EventOversightScreen(),
        3 => const VendorOversightScreen(),
        4 => const OperationsCenterScreen(),
        5 => AdminFinanceScreen(subView: shell.financeSub),
        6 => const AdminComplianceScreen(),
        7 => const AdminAuditScreen(),
        8 => const AdminSettingsScreen(),
        _ => const PlatformDashboardScreen(),
      };
}
