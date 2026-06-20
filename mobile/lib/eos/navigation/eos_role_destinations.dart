import 'package:flutter/material.dart';

import 'eos_nav_destination.dart';

/// Role-specific navigation presets for EOS shells.
abstract final class EosRoleDestinations {
  static const platformAdmin = [
    EosNavDestination(label: 'Dashboard', icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard),
    EosNavDestination(label: 'Organizers', icon: Icons.groups_outlined),
    EosNavDestination(label: 'Events', icon: Icons.celebration_outlined, selectedIcon: Icons.celebration),
    EosNavDestination(label: 'Vendors', icon: Icons.storefront_outlined),
    EosNavDestination(label: 'Operations', icon: Icons.sensors_outlined, selectedIcon: Icons.sensors),
    EosNavDestination(label: 'Finance', icon: Icons.account_balance_outlined),
    EosNavDestination(label: 'Compliance', icon: Icons.policy_outlined),
  ];

  static const superAdmin = [
    EosNavDestination(label: 'Overview', icon: Icons.hub_outlined, selectedIcon: Icons.hub),
    EosNavDestination(label: 'Tenants', icon: Icons.apartment_outlined),
    EosNavDestination(label: 'Finance', icon: Icons.account_balance_outlined),
    EosNavDestination(label: 'Health', icon: Icons.monitor_heart_outlined),
    EosNavDestination(label: 'Flags', icon: Icons.toggle_on_outlined),
    EosNavDestination(label: 'Audit', icon: Icons.history_outlined),
    EosNavDestination(label: 'Analytics', icon: Icons.insights_outlined),
    EosNavDestination(label: 'Security', icon: Icons.security_outlined),
  ];

  static const adminFinance = [
    EosNavDestination(label: 'Dashboard', icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard),
    EosNavDestination(label: 'Transactions', icon: Icons.receipt_long_outlined),
    EosNavDestination(label: 'Payouts', icon: Icons.payments_outlined),
    EosNavDestination(label: 'Under Review', icon: Icons.fact_check_outlined),
    EosNavDestination(label: 'Reconciliation', icon: Icons.rule_folder_outlined),
    EosNavDestination(label: 'Disputes', icon: Icons.report_problem_outlined),
    EosNavDestination(label: 'Settings', icon: Icons.settings_outlined),
  ];

  static const organizer = [
    EosNavDestination(label: 'Dashboard', icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard),
    EosNavDestination(label: 'Events', icon: Icons.celebration_outlined, selectedIcon: Icons.celebration),
    EosNavDestination(label: 'Tickets', icon: Icons.confirmation_number_outlined),
    EosNavDestination(label: 'Vendors', icon: Icons.storefront_outlined),
    EosNavDestination(label: 'Attendees', icon: Icons.people_outline),
    EosNavDestination(label: 'Analytics', icon: Icons.insights_outlined),
    EosNavDestination(label: 'Live Ops', icon: Icons.sensors_outlined, selectedIcon: Icons.sensors),
  ];

  static const vendor = [
    EosNavDestination(label: 'Dashboard', icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard),
    EosNavDestination(label: 'Events', icon: Icons.celebration_outlined),
    EosNavDestination(label: 'Catalog', icon: Icons.menu_book_outlined),
    EosNavDestination(label: 'Orders', icon: Icons.receipt_long_outlined),
    EosNavDestination(label: 'Wallet', icon: Icons.account_balance_wallet_outlined),
    EosNavDestination(label: 'Payouts', icon: Icons.payments_outlined),
    EosNavDestination(label: 'Analytics', icon: Icons.insights_outlined),
  ];

  static const attendee = [
    EosNavDestination(label: 'Discover', icon: Icons.explore_outlined),
    EosNavDestination(label: 'Tickets', icon: Icons.qr_code_2_outlined),
    EosNavDestination(label: 'Schedule', icon: Icons.calendar_month_outlined),
  ];
}
