import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/auth_notifier.dart';
import '../../eos/eos.dart';
import '../../features/workspace/widgets/workspace_experience_shell.dart';
import '../../identity/experience_navigation.dart';
import '../../identity/workspace_models.dart';
import '../../router/experience_routes.dart';
import 'providers/vendor_providers.dart';
import 'providers/vendor_profile_providers.dart';
import 'screens/event_participation_screen.dart';
import 'screens/orders_bookings_screen.dart';
import 'screens/service_catalog_screen.dart';
import 'screens/vendor_analytics_screen.dart';
import 'screens/vendor_dashboard_screen.dart';
import 'screens/vendor_payouts_screen.dart';
import 'screens/vendor_profile_edit_sheet.dart';
import 'screens/vendor_wallet_screen.dart';

class VendorHomeScreen extends ConsumerWidget {
  const VendorHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const WorkspaceExperienceShell(
      workspace: ExperienceWorkspace.vendor,
      child: _VendorHomeContent(),
    );
  }
}

class _VendorHomeContent extends ConsumerWidget {
  const _VendorHomeContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaceProfile = ref.watch(vendorWorkspaceProfileProvider);

    // Harden: never show dashboard before vendor onboarding is complete.
    final step = workspaceProfile.valueOrNull?.onboardingStep;
    if (workspaceProfile.isLoading) {
      return const Scaffold(
        backgroundColor: EosColors.plumDark,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (step != null && step != 'complete') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.go(ExperienceRoutes.onboardingFor(ExperienceWorkspace.vendor));
        }
      });
      return const Scaffold(
        backgroundColor: EosColors.plumDark,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final tab = ref.watch(vendorShellTabProvider);
    final profile = ref.watch(vendorProfileProvider);

    return EosAppShell(
      brandLabel: 'Owambe',
      brandSubtitle: 'Vendor Workspace',
      destinations: EosRoleDestinations.vendor,
      selectedIndex: tab,
      onSelected: (v) => ref.read(vendorShellTabProvider.notifier).select(v),
      topBar: _VendorTopBar(
        businessName: profile.businessName,
        tier: profile.tier,
        onEditProfile: () => showVendorProfileEditor(context, ref),
        onSignOut: () {
          ref.read(authSessionProvider.notifier).signOut();
          context.go(ExperienceNavigation.afterSignOut());
        },
      ),
      body: _bodyForTab(tab),
    );
  }

  Widget _bodyForTab(int index) => switch (index) {
        0 => const VendorDashboardScreen(),
        1 => const EventParticipationScreen(),
        2 => const ServiceCatalogScreen(),
        3 => const OrdersBookingsScreen(),
        4 => const VendorWalletScreen(),
        5 => const VendorPayoutsScreen(),
        6 => const VendorAnalyticsScreen(),
        _ => const VendorDashboardScreen(),
      };
}

class _VendorTopBar extends ConsumerWidget {
  const _VendorTopBar({
    required this.businessName,
    required this.tier,
    required this.onEditProfile,
    required this.onSignOut,
  });

  final String businessName;
  final String tier;
  final VoidCallback onEditProfile;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return EosAdaptiveTopBarChrome(
      search: const EosSearchField(hint: 'Search orders, events, catalog…'),
      title: EosAdaptive.isCompact(context)
          ? Text(
              businessName,
              style: context.eosText.titleSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : Row(
              children: [
                if (tier.trim().isNotEmpty) ...[
                  EosVendorTierChip(tier: tier),
                  SizedBox(width: context.eos.spacing.sm),
                ],
                Flexible(
                  child: Text(
                    businessName,
                    style: context.eosText.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
      iconActions: [
        IconButton(
          tooltip: 'Edit Vendor Profile',
          onPressed: onEditProfile,
          icon: const Icon(Icons.manage_accounts_outlined),
        ),
      ],
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const WorkspaceContextActions(),
          IconButton(onPressed: onSignOut, icon: const Icon(Icons.logout)),
        ],
      ),
    );
  }
}
