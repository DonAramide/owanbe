import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../eos/eos.dart';
import '../../../features/workspace/widgets/workspace_switcher.dart';
import '../../../navigation/enterprise_back_handler.dart';
import '../providers/living_home_providers.dart';
import '../widgets/customer_home_design.dart';
import '../widgets/customer_home_welcome_tab.dart';
import '../widgets/home_activity_tab.dart';
import '../widgets/home_profile_tab.dart';

/// Owanbe Customer Home — branded welcome first; workspaces via Explore / ⋮.
class OwanbeHomeScreen extends ConsumerStatefulWidget {
  const OwanbeHomeScreen({super.key});

  @override
  ConsumerState<OwanbeHomeScreen> createState() => _OwanbeHomeScreenState();
}

class _OwanbeHomeScreenState extends ConsumerState<OwanbeHomeScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final alertCount = ref.watch(homeAlertCountProvider);
    final isHome = _tabIndex == 0;

    return WorkspaceBackScope(
      child: Scaffold(
        backgroundColor: EosColors.plumDark,
        // Welcome tab owns its own top chrome (logo + ⋮). Other tabs keep AppBar.
        appBar: isHome
            ? null
            : AppBar(
                backgroundColor: EosColors.plumDark,
                foregroundColor: Colors.white,
                elevation: 0,
                title: Text(
                  switch (_tabIndex) {
                    1 => 'Activity',
                    _ => 'Profile',
                  },
                  style: context.eosText.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                actions: const [
                  WorkspaceSwitcher(iconColor: Colors.white),
                  SizedBox(width: 4),
                ],
              ),
        body: IndexedStack(
          index: _tabIndex,
          children: const [
            CustomerHomeWelcomeTab(),
            HomeActivityTab(),
            HomeProfileTab(),
          ],
        ),
        bottomNavigationBar: Theme(
          data: Theme.of(context).copyWith(
            navigationBarTheme: NavigationBarThemeData(
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                final selected = states.contains(WidgetState.selected);
                return TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? CustomerHomeDesign.gold : Colors.white.withValues(alpha: 0.55),
                );
              }),
            ),
          ),
          child: NavigationBar(
          selectedIndex: _tabIndex,
          backgroundColor: CustomerHomeDesign.plumDeep,
          indicatorColor: Colors.transparent,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          height: 72,
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.home_outlined, color: Colors.white.withValues(alpha: 0.55)),
              selectedIcon: const Icon(Icons.home, color: CustomerHomeDesign.gold),
              label: 'Home',
            ),
            NavigationDestination(
              icon: alertCount > 0
                  ? Badge(
                      label: Text('$alertCount'),
                      backgroundColor: Colors.redAccent,
                      child: Icon(Icons.notifications_outlined, color: Colors.white.withValues(alpha: 0.55)),
                    )
                  : Icon(Icons.notifications_outlined, color: Colors.white.withValues(alpha: 0.55)),
              selectedIcon: alertCount > 0
                  ? Badge(
                      label: Text('$alertCount'),
                      backgroundColor: Colors.redAccent,
                      child: const Icon(Icons.notifications, color: CustomerHomeDesign.gold),
                    )
                  : const Icon(Icons.notifications, color: CustomerHomeDesign.gold),
              label: 'Activity',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline, color: Colors.white.withValues(alpha: 0.55)),
              selectedIcon: const Icon(Icons.person, color: CustomerHomeDesign.gold),
              label: 'Profile',
            ),
          ],
          onDestinationSelected: (i) => setState(() => _tabIndex = i),
          ),
        ),
      ),
    );
  }
}
