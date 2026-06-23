import 'package:flutter/material.dart';

import '../../../eos/navigation/eos_nav_destination.dart';

/// Bottom / side navigation for the Customer Portal shell.
abstract final class CustomerNavDestinations {
  static const items = <EosNavDestination>[
    EosNavDestination(
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
    ),
    EosNavDestination(
      label: 'My Events',
      icon: Icons.celebration_outlined,
      selectedIcon: Icons.celebration,
    ),
    EosNavDestination(
      label: 'Create',
      icon: Icons.add_circle_outline,
      selectedIcon: Icons.add_circle,
    ),
    EosNavDestination(
      label: 'Guests',
      icon: Icons.groups_outlined,
      selectedIcon: Icons.groups,
    ),
    EosNavDestination(
      label: 'More',
      icon: Icons.menu_outlined,
      selectedIcon: Icons.menu,
    ),
  ];
}
