import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/auth_notifier.dart';
import '../../../eos/eos.dart';
import '../../../features/workspace/widgets/workspace_experience_shell.dart';
import '../navigation/event_navigator.dart';
import '../../../eos/widgets/owambe_logo.dart';
import 'customer_nav_destinations.dart';

/// Customer Portal shell — mobile bottom nav, tablet/desktop rail, route persistence.
class CustomerShell extends StatelessWidget {
  const CustomerShell({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  static const brandLabel = 'Owambe';
  static const brandSubtitle = 'Organizer Workspace';

  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final destinations = CustomerNavDestinations.items;
    final selectedIndex = navigationShell.currentIndex;

    return EosAppShell(
      brandLabel: brandLabel,
      brandSubtitle: brandSubtitle,
      destinations: destinations,
      selectedIndex: selectedIndex,
      onSelected: _onDestinationSelected,
      topBar: _CustomerTopBar(
        title: destinations[selectedIndex].label,
        subtitle: brandSubtitle,
      ),
      body: navigationShell,
    );
  }
}

class _CustomerTopBar extends ConsumerWidget {
  const _CustomerTopBar({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);
    final firstName = (session?.displayName ?? '').trim().split(RegExp(r'\s+')).first;
    final initial = firstName.isNotEmpty ? firstName[0].toUpperCase() : 'O';
    final compact = EosAdaptive.isCompact(context);

    return EosAdaptiveTopBarChrome(
      leading: const OwambeLogo(size: 28),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: context.eosText.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (!compact)
            Text(subtitle, style: context.eosText.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
      iconActions: [
        IconButton(
          tooltip: 'Discover events',
          icon: const Icon(Icons.explore_outlined),
          onPressed: () => context.eventNav.openDiscover(),
        ),
      ],
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const WorkspaceContextActions(),
          GestureDetector(
            onTap: () => context.eventNav.goProfile(),
            child: Tooltip(
              message: session?.displayName ?? 'My profile',
              child: CircleAvatar(
                radius: 17,
                backgroundColor: EosColors.plum,
                child: Text(
                  initial,
                  style: context.eosText.labelMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
