import 'package:flutter/material.dart';

import '../../../eos/eos.dart';
import 'admin_nav.dart';
import 'admin_sidebar.dart';
import 'admin_top_bar.dart';

/// Admin shell — presentation adapts via EOS breakpoints; routes unchanged.
///
/// - Compact: bottom nav with primary slots + More overflow
/// - Medium: compact sidebar
/// - Expanded: extended sidebar
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

  static const _primarySlots = EosBreakpoints.mobilePrimaryNavSlots;

  @override
  Widget build(BuildContext context) {
    return EosAdaptiveTextScale(
      child: EosResponsive(
        mobile: _AdminMobileShell(
          selectedIndex: selectedIndex,
          onSelected: onSelected,
          body: body,
          topBar: topBar,
          primarySlots: _primarySlots,
        ),
        tablet: _AdminRailShell(
          selectedIndex: selectedIndex,
          onSelected: onSelected,
          body: body,
          topBar: topBar,
          extended: false,
        ),
        desktop: _AdminRailShell(
          selectedIndex: selectedIndex,
          onSelected: onSelected,
          body: body,
          topBar: topBar,
          extended: true,
        ),
      ),
    );
  }
}

class _AdminRailShell extends StatelessWidget {
  const _AdminRailShell({
    required this.selectedIndex,
    required this.onSelected,
    required this.body,
    required this.topBar,
    required this.extended,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Widget body;
  final AdminTopBar topBar;
  final bool extended;

  @override
  Widget build(BuildContext context) {
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
}

class _AdminMobileShell extends StatelessWidget {
  const _AdminMobileShell({
    required this.selectedIndex,
    required this.onSelected,
    required this.body,
    required this.topBar,
    required this.primarySlots,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Widget body;
  final AdminTopBar topBar;
  final int primarySlots;

  @override
  Widget build(BuildContext context) {
    final destinations = adminNavItems;
    final overflow = destinations.length > primarySlots;
    final primary = overflow ? destinations.take(primarySlots).toList() : destinations;
    final moreIndex = primary.length;
    final safeSelected = selectedIndex.clamp(0, destinations.length - 1);
    final bottomSelected = !overflow
        ? safeSelected
        : (safeSelected < primarySlots ? safeSelected : moreIndex);

    return Scaffold(
      body: Column(
        children: [
          SafeArea(bottom: false, child: topBar),
          Expanded(child: body),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: bottomSelected,
        onDestinationSelected: (i) async {
          if (!overflow || i < primarySlots) {
            onSelected(i);
            return;
          }
          final chosen = await showModalBottomSheet<int>(
            context: context,
            showDragHandle: true,
            builder: (ctx) {
              return SafeArea(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Text('More', style: Theme.of(ctx).textTheme.titleMedium),
                    ),
                    for (var i = primarySlots; i < destinations.length; i++)
                      ListTile(
                        leading: Icon(
                          safeSelected == i
                              ? (destinations[i].selectedIcon ?? destinations[i].icon)
                              : destinations[i].icon,
                        ),
                        title: Text(destinations[i].label),
                        selected: safeSelected == i,
                        onTap: () => Navigator.pop(ctx, i),
                      ),
                  ],
                ),
              );
            },
          );
          if (chosen != null) onSelected(chosen);
        },
        destinations: [
          for (final item in primary)
            NavigationDestination(
              icon: Icon(item.icon),
              selectedIcon: Icon(item.selectedIcon ?? item.icon),
              label: item.label,
            ),
          if (overflow)
            const NavigationDestination(
              icon: Icon(Icons.more_horiz),
              selectedIcon: Icon(Icons.more_horiz),
              label: 'More',
            ),
        ],
      ),
    );
  }
}
