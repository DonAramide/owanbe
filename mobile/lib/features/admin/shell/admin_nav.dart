import 'package:flutter/material.dart';

class AdminNavItem {
  const AdminNavItem({
    required this.label,
    required this.icon,
    this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData? selectedIcon;
}

const adminNavItems = <AdminNavItem>[
  AdminNavItem(label: 'Launch ops', icon: Icons.rocket_launch_outlined, selectedIcon: Icons.rocket_launch),
  AdminNavItem(label: 'Tenants', icon: Icons.apartment_outlined, selectedIcon: Icons.apartment),
  AdminNavItem(label: 'Events', icon: Icons.celebration_outlined, selectedIcon: Icons.celebration),
  AdminNavItem(label: 'Vendors', icon: Icons.storefront_outlined, selectedIcon: Icons.storefront),
  AdminNavItem(label: 'Operations', icon: Icons.sensors_outlined, selectedIcon: Icons.sensors),
  AdminNavItem(label: 'Finance', icon: Icons.account_balance_outlined, selectedIcon: Icons.account_balance),
  AdminNavItem(label: 'Compliance', icon: Icons.verified_user_outlined, selectedIcon: Icons.verified_user),
  AdminNavItem(label: 'Audit', icon: Icons.history_outlined, selectedIcon: Icons.history),
  AdminNavItem(label: 'Settings', icon: Icons.settings_outlined, selectedIcon: Icons.settings),
];

const adminMobileBreakpoint = 768.0;
