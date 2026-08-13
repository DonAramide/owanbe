import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/auth_notifier.dart';
import '../../eos/eos.dart';
import 'executive/executive_overview_screen.dart';
import 'executive/widgets/executive_global_search.dart';
import 'screens/audit_intelligence_screen.dart';
import 'screens/commerce_configuration_screen.dart';
import 'screens/feature_flags_screen.dart';
import 'screens/platform_analytics_screen.dart';
import 'screens/platform_finance_screen.dart';
import 'screens/security_center_screen.dart';
import 'screens/system_health_screen.dart';
import 'screens/tenant_management_screen.dart';
import 'tenant_360/tenant_360_workspace_screen.dart';
import 'super_admin_providers.dart';
import '../../../eos/layout/admin/admin_framework.dart';

class SuperAdminHomeScreen extends ConsumerStatefulWidget {
  const SuperAdminHomeScreen({super.key, this.selectedTenantId});
  final String? selectedTenantId;

  @override
  ConsumerState<SuperAdminHomeScreen> createState() => _SuperAdminHomeScreenState();
}

class _SuperAdminHomeScreenState extends ConsumerState<SuperAdminHomeScreen> {
  static final _destinations = EosRoleDestinations.superAdmin;

  Widget _bodyForTab(int index) => switch (index) {
        0 => const ExecutiveOverviewScreen(),
        1 => widget.selectedTenantId != null
            ? Tenant360WorkspaceScreen(tenantId: widget.selectedTenantId!)
            : const TenantManagementScreen(),
        2 => const PlatformFinanceScreen(),
        3 => const SystemHealthScreen(),
        4 => const FeatureFlagsScreen(),
        5 => const AuditIntelligenceScreen(),
        6 => const PlatformAnalyticsScreen(),
        7 => const SecurityCenterScreen(),
        8 => const CommerceConfigurationScreen(),
        9 => const AdminNavigationShell(),
        _ => const ExecutiveOverviewScreen(),
      };

  void _onSelected(int v) {
    if (widget.selectedTenantId != null) {
      context.go('/super-admin');
    }
    ref.read(superAdminShellTabProvider.notifier).select(v);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);
    final tab = widget.selectedTenantId != null ? 1 : ref.watch(superAdminShellTabProvider);

    return EosAppShell(
      brandLabel: 'Owambe',
      brandSubtitle: 'Control Tower',
      destinations: _destinations,
      selectedIndex: tab,
      onSelected: _onSelected,
      topBar: _ExecutiveTopBar(
        displayName: session?.displayName ?? 'Super Admin',
        onSignOut: _signOut,
      ),
      body: _bodyForTab(tab),
    );
  }

  Future<void> _signOut() async {
    await ref.read(authSessionProvider.notifier).signOut();
    if (mounted) context.go('/');
  }
}

class _ExecutiveTopBar extends StatelessWidget {
  const _ExecutiveTopBar({required this.displayName, required this.onSignOut});

  final String displayName;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return EosAdaptiveTopBarChrome(
      search: const ExecutiveGlobalSearch(),
      title: EosAdaptive.isCompact(context)
          ? null
          : Text(displayName, style: context.eosText.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
      iconActions: [
        IconButton(tooltip: 'Sign out', onPressed: onSignOut, icon: const Icon(Icons.logout)),
      ],
    );
  }
}
