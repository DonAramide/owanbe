import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/auth_notifier.dart';
import '../../eos/eos.dart';
import '../../eos/widgets/owambe_logo.dart';
import 'executive/executive_overview_screen.dart';
import 'executive/widgets/executive_global_search.dart';
import 'screens/audit_intelligence_screen.dart';
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
  var _railExtended = true;

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
        8 => const AdminNavigationShell(),
        _ => const ExecutiveOverviewScreen(),
      };

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);
    final tab = widget.selectedTenantId != null ? 1 : ref.watch(superAdminShellTabProvider);

    if (EosResponsive.isMobile(context)) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Control Tower'),
          actions: [IconButton(onPressed: _signOut, icon: const Icon(Icons.logout))],
        ),
        body: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(context.eos.spacing.md),
              child: const ExecutiveGlobalSearch(),
            ),
            Expanded(child: _bodyForTab(tab)),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (v) {
            if (widget.selectedTenantId != null) {
              context.go('/super-admin');
            }
            ref.read(superAdminShellTabProvider.notifier).select(v);
          },
          destinations: [
            for (final d in _destinations) NavigationDestination(icon: Icon(d.icon), label: d.label),
          ],
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: _railExtended,
            minExtendedWidth: 200,
            selectedIndex: tab,
            onDestinationSelected: (v) {
              if (widget.selectedTenantId != null) {
                context.go('/super-admin');
              }
              ref.read(superAdminShellTabProvider.notifier).select(v);
            },
            leading: Padding(
              padding: const EdgeInsets.fromLTRB(EosSpacing.md, EosSpacing.lg, EosSpacing.md, EosSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const OwambeLogo(size: 40),
                  if (_railExtended) ...[
                    const SizedBox(height: EosSpacing.sm),
                    Text('Control Tower', style: context.eosText.labelLarge),
                  ],
                  IconButton(
                    tooltip: _railExtended ? 'Collapse navigation' : 'Expand navigation',
                    onPressed: () => setState(() => _railExtended = !_railExtended),
                    icon: Icon(_railExtended ? Icons.menu_open : Icons.menu),
                  ),
                ],
              ),
            ),
            destinations: [
              for (final d in _destinations)
                NavigationRailDestination(icon: Icon(d.icon), label: Text(d.label)),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                _ExecutiveTopBar(displayName: session?.displayName ?? 'Super Admin', onSignOut: _signOut),
                Expanded(child: _bodyForTab(tab)),
              ],
            ),
          ),
        ],
      ),
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
    return Material(
      color: context.eosColors.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.eosColors.outlineVariant))),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: context.eos.spacing.lg, vertical: context.eos.spacing.sm),
          child: Row(
            children: [
              const Expanded(child: ExecutiveGlobalSearch()),
              SizedBox(width: context.eos.spacing.md),
              Text(displayName, style: context.eosText.titleSmall),
              IconButton(onPressed: onSignOut, icon: const Icon(Icons.logout)),
            ],
          ),
        ),
      ),
    );
  }
}
