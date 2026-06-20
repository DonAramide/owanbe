import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/auth_notifier.dart';
import '../../eos/eos.dart';
import 'screens/audit_intelligence_screen.dart';
import 'screens/feature_flags_screen.dart';
import 'screens/platform_analytics_screen.dart';
import 'screens/platform_finance_screen.dart';
import 'screens/security_center_screen.dart';
import 'screens/super_admin_overview_screen.dart';
import 'screens/system_health_screen.dart';
import 'screens/tenant_management_screen.dart';
import 'super_admin_providers.dart';

class SuperAdminHomeScreen extends ConsumerWidget {
  const SuperAdminHomeScreen({super.key});

  static final _destinations = EosRoleDestinations.superAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);
    final tab = ref.watch(superAdminShellTabProvider);

    return EosAppShell(
      brandLabel: 'Owanbe',
      brandSubtitle: 'Control Tower',
      destinations: _destinations,
      selectedIndex: tab,
      onSelected: (v) => ref.read(superAdminShellTabProvider.notifier).select(v),
      topBar: _TopBar(
        displayName: session?.displayName ?? 'Super Admin',
        onSignOut: () => ref.read(authSessionProvider.notifier).signOut(),
      ),
      body: _bodyForTab(tab),
    );
  }

  Widget _bodyForTab(int index) => switch (index) {
        0 => const SuperAdminOverviewScreen(),
        1 => const TenantManagementScreen(),
        2 => const PlatformFinanceScreen(),
        3 => const SystemHealthScreen(),
        4 => const FeatureFlagsScreen(),
        5 => const AuditIntelligenceScreen(),
        6 => const PlatformAnalyticsScreen(),
        7 => const SecurityCenterScreen(),
        _ => const SuperAdminOverviewScreen(),
      };
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.displayName, required this.onSignOut});
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
              Expanded(child: EosSearchField(hint: 'Search tenants, finance, audit…')),
              SizedBox(width: context.eos.spacing.sm),
              Text(displayName, style: context.eosText.titleSmall),
              IconButton(onPressed: onSignOut, icon: const Icon(Icons.logout)),
            ],
          ),
        ),
      ),
    );
  }
}
