import 'package:flutter/material.dart';

import '../extensions/eos_context.dart';
import '../layout/eos_adaptive.dart';
import '../layout/eos_responsive.dart';
import '../navigation/eos_nav_destination.dart';
import '../tokens/eos_breakpoints.dart';
import '../tokens/eos_colors.dart';
import '../tokens/eos_spacing.dart';
import '../widgets/owambe_logo.dart';

/// Role-aware app shell — adaptive presentation only; routes/indices unchanged.
///
/// - Phone (compact): bottom nav with primary slots + "More" overflow
/// - Tablet (medium): compact navigation rail
/// - Desktop (expanded): extended navigation rail
class EosAppShell extends StatelessWidget {
  const EosAppShell({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    required this.body,
    required this.topBar,
    this.brandLabel = 'Owambe',
    this.brandSubtitle,
    this.mobilePrimarySlots = EosBreakpoints.mobilePrimaryNavSlots,
  });

  final List<EosNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Widget body;
  final Widget topBar;
  final String brandLabel;
  final String? brandSubtitle;

  /// How many destinations appear in the phone bottom bar before "More".
  final int mobilePrimarySlots;

  @override
  Widget build(BuildContext context) {
    return EosAdaptiveTextScale(
      child: EosResponsive(
        mobile: _MobileShell(
          destinations: destinations,
          selectedIndex: selectedIndex,
          onSelected: onSelected,
          topBar: topBar,
          body: body,
          primarySlots: mobilePrimarySlots,
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
    final safeIndex = selectedIndex.clamp(0, destinations.isEmpty ? 0 : destinations.length - 1);
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: extended,
            minExtendedWidth: 200,
            selectedIndex: destinations.isEmpty ? 0 : safeIndex,
            onDestinationSelected: onSelected,
            leading: extended
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(
                      EosSpacing.md,
                      EosSpacing.lg,
                      EosSpacing.md,
                      EosSpacing.sm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          brandLabel,
                          style: context.eosText.titleLarge?.copyWith(color: EosColors.plum),
                        ),
                        if (brandSubtitle != null)
                          Text(brandSubtitle!, style: context.eosText.labelSmall),
                      ],
                    ),
                  )
                : const Padding(
                    padding: EdgeInsets.only(top: EosSpacing.md),
                    child: OwambeLogo(size: 28),
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
    required this.primarySlots,
  });

  final List<EosNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Widget body;
  final Widget topBar;
  final int primarySlots;

  @override
  Widget build(BuildContext context) {
    final overflow = destinations.length > primarySlots;
    final primary = overflow ? destinations.take(primarySlots).toList() : destinations;
    final moreIndex = primary.length;

    final safeSelected = selectedIndex.clamp(0, destinations.isEmpty ? 0 : destinations.length - 1);
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
      bottomNavigationBar: destinations.isEmpty
          ? null
          : NavigationBar(
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
                for (final d in primary)
                  NavigationDestination(
                    icon: Badge(
                      isLabelVisible: d.badge != null,
                      label: Text(d.badge ?? ''),
                      child: Icon(d.icon),
                    ),
                    selectedIcon: Icon(d.selectedIcon ?? d.icon),
                    label: d.label,
                  ),
                if (overflow)
                  NavigationDestination(
                    icon: Badge(
                      isLabelVisible: safeSelected >= primarySlots,
                      child: const Icon(Icons.more_horiz),
                    ),
                    selectedIcon: const Icon(Icons.more_horiz),
                    label: 'More',
                  ),
              ],
            ),
    );
  }
}
