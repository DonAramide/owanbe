import 'package:flutter/material.dart';

import '../extensions/eos_context.dart';
import '../layout/eos_responsive.dart';
import '../navigation/eos_nav_destination.dart';
import '../tokens/eos_colors.dart';
import '../tokens/eos_spacing.dart';
import '../widgets/owanbe_logo.dart';

/// Role-aware app shell — rail on desktop/tablet, bottom bar on mobile.
class EosAppShell extends StatelessWidget {
  const EosAppShell({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    required this.body,
    required this.topBar,
    this.brandLabel = 'Owanbe',
    this.brandSubtitle,
  });

  final List<EosNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Widget body;
  final Widget topBar;
  final String brandLabel;
  final String? brandSubtitle;

  @override
  Widget build(BuildContext context) {
    return EosResponsive(
      mobile: _MobileShell(
        destinations: destinations,
        selectedIndex: selectedIndex,
        onSelected: onSelected,
        topBar: topBar,
        body: body,
      ),
      tablet: _RailShell(
        destinations: destinations,
        selectedIndex: selectedIndex,
        onSelected: onSelected,
        topBar: topBar,
        body: body,
        brandLabel: brandLabel,
        brandSubtitle: brandSubtitle,
        extended: false,
      ),
      desktop: _RailShell(
        destinations: destinations,
        selectedIndex: selectedIndex,
        onSelected: onSelected,
        topBar: topBar,
        body: body,
        brandLabel: brandLabel,
        brandSubtitle: brandSubtitle,
        extended: true,
      ),
    );
  }
}

class _RailShell extends StatelessWidget {
  const _RailShell({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    required this.body,
    required this.topBar,
    required this.brandLabel,
    required this.extended,
    this.brandSubtitle,
  });

  final List<EosNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Widget body;
  final Widget topBar;
  final String brandLabel;
  final String? brandSubtitle;
  final bool extended;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: extended,
            minExtendedWidth: 200,
            selectedIndex: selectedIndex,
            onDestinationSelected: onSelected,
            leading: extended
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(EosSpacing.md, EosSpacing.lg, EosSpacing.md, EosSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(brandLabel, style: context.eosText.titleLarge?.copyWith(color: EosColors.plum)),
                        if (brandSubtitle != null)
                          Text(brandSubtitle!, style: context.eosText.labelSmall),
                      ],
                    ),
                  )
                : const Padding(
                    padding: EdgeInsets.only(top: EosSpacing.md),
                    child: OwanbeLogo(size: 28),
                  ),
            destinations: [
              for (final d in destinations)
                NavigationRailDestination(
                  icon: Badge(
                    isLabelVisible: d.badge != null,
                    label: Text(d.badge ?? ''),
                    child: Icon(d.icon),
                  ),
                  selectedIcon: Icon(d.selectedIcon ?? d.icon),
                  label: Text(d.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
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

class _MobileShell extends StatelessWidget {
  const _MobileShell({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    required this.body,
    required this.topBar,
  });

  final List<EosNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Widget body;
  final Widget topBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          topBar,
          Expanded(child: body),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onSelected,
        destinations: [
          for (final d in destinations)
            NavigationDestination(
              icon: Badge(
                isLabelVisible: d.badge != null,
                label: Text(d.badge ?? ''),
                child: Icon(d.icon),
              ),
              selectedIcon: Icon(d.selectedIcon ?? d.icon),
              label: d.label,
            ),
        ],
      ),
    );
  }
}
