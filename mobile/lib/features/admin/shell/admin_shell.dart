import 'package:flutter/material.dart';

import 'admin_nav.dart';
import 'admin_sidebar.dart';
import 'admin_top_bar.dart';

/// Desktop-first admin shell — sidebar + top bar; bottom nav only below 768px.
class AdminShell extends StatelessWidget {
  const AdminShell({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.body,
    required this.topBar,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Widget body;
  final AdminTopBar topBar;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final useSidebar = width >= adminMobileBreakpoint;

    if (useSidebar) {
      final extended = width >= 1200;
      return Scaffold(
        body: Row(
          children: [
            AdminSidebar(
              selectedIndex: selectedIndex,
              onSelected: onSelected,
              extended: extended,
            ),
            Expanded(
              child: Column(
                children: [
                  topBar,
                  Expanded(child: body),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          topBar,
          Expanded(child: body),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex.clamp(0, adminNavItems.length - 1),
        onDestinationSelected: onSelected,
        destinations: [
          for (final item in adminNavItems)
            NavigationDestination(
              icon: Icon(item.icon),
              selectedIcon: Icon(item.selectedIcon ?? item.icon),
              label: item.label,
            ),
        ],
      ),
    );
  }
}
