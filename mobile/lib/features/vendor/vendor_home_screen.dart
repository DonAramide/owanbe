import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/auth_notifier.dart';
import '../../eos/eos.dart';
import 'providers/vendor_providers.dart';
import 'screens/event_participation_screen.dart';
import 'screens/orders_bookings_screen.dart';
import 'screens/service_catalog_screen.dart';
import 'screens/vendor_analytics_screen.dart';
import 'screens/vendor_dashboard_screen.dart';
import 'screens/vendor_payouts_screen.dart';
import 'screens/vendor_wallet_screen.dart';

class VendorHomeScreen extends ConsumerWidget {
  const VendorHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(vendorShellTabProvider);
    final profile = ref.watch(vendorProfileProvider);

    return EosAppShell(
      brandLabel: 'Owanbe',
      brandSubtitle: 'Vendor Portal',
      destinations: EosRoleDestinations.vendor,
      selectedIndex: tab,
      onSelected: (v) => ref.read(vendorShellTabProvider.notifier).select(v),
      topBar: _VendorTopBar(
        businessName: profile.businessName,
        tier: profile.tier,
        onSignOut: () {
          ref.read(authSessionProvider.notifier).signOut();
          context.go('/');
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

class _VendorTopBar extends StatelessWidget {
  const _VendorTopBar({
    required this.businessName,
    required this.tier,
    required this.onSignOut,
  });

  final String businessName;
  final String tier;
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
              Expanded(child: EosSearchField(hint: 'Search orders, events, catalog…')),
              SizedBox(width: context.eos.spacing.sm),
              EosVendorTierChip(tier: tier),
              SizedBox(width: context.eos.spacing.sm),
              Text(businessName, style: context.eosText.titleSmall),
              IconButton(onPressed: onSignOut, icon: const Icon(Icons.logout)),
            ],
          ),
        ),
      ),
    );
  }
}
