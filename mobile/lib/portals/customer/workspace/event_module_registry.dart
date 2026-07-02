import 'package:flutter/material.dart';

import '../models/command_center_models.dart';
import '../models/customer_event_models.dart';
import '../navigation/event_navigator.dart';

/// Event OS module categories for workspace layout (Phase 42.3).
enum EventModuleCategory {
  planning('Planning', 'Guests, budget, vendors, and invitations'),
  operations('Operations', 'Program, seating, rentals, and day-of'),
  celebration('Celebration', 'Website, wall, and guest experiences'),
  business('Business', 'Finance, tickets, and analytics'),
  administration('Administration', 'Event configuration');

  const EventModuleCategory(this.title, this.subtitle);

  final String title;
  final String subtitle;
}

/// Stable module identifiers for registry and deep links.
enum EventModuleId {
  overview,
  guests,
  invitations,
  budget,
  vendors,
  marketplace,
  rentals,
  asoEbi,
  program,
  seating,
  website,
  celebrationWall,
  gallery,
  memories,
  aiPlanner,
  eventDay,
  finance,
  analytics,
  tickets,
  settings,
}

/// Registered Event OS module definition.
class EventModuleDefinition {
  const EventModuleDefinition({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.category,
    required this.visible,
    this.supportsQuickAction = false,
    this.badgeCount,
    required this.onOpen,
  });

  final EventModuleId id;
  final String title;
  final String subtitle;
  final IconData icon;
  final EventModuleCategory category;
  final bool Function(CustomerEvent event) visible;
  final bool supportsQuickAction;
  final int? Function(EventCommandCenterSnapshot snapshot)? badgeCount;
  final void Function(BuildContext context, String eventId) onOpen;
}

/// Central registry for Event Workspace modules — single source of truth.
abstract final class EventModuleRegistry {
  static void _comingSoon(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label is coming soon.')),
    );
  }

  static List<EventModuleDefinition> all = [
    EventModuleDefinition(
      id: EventModuleId.guests,
      title: 'Guests',
      subtitle: 'Lists, RSVP, and check-in',
      icon: Icons.people_outline,
      category: EventModuleCategory.planning,
      visible: (_) => true,
      supportsQuickAction: true,
      badgeCount: (s) {
        final pending = s.guestInvited - s.guestRsvp;
        return pending > 0 ? pending : null;
      },
      onOpen: (c, id) => c.eventNav.openGuests(id),
    ),
    EventModuleDefinition(
      id: EventModuleId.invitations,
      title: 'Invitations',
      subtitle: 'Cards, templates, and sharing',
      icon: Icons.mail_outline,
      category: EventModuleCategory.planning,
      visible: (_) => true,
      supportsQuickAction: true,
      onOpen: (c, id) => c.eventNav.openInvitations(id),
    ),
    EventModuleDefinition(
      id: EventModuleId.budget,
      title: 'Budget',
      subtitle: 'Allocations, spend, and balance',
      icon: Icons.account_balance_wallet_outlined,
      category: EventModuleCategory.planning,
      visible: (e) => e.isPrivateCelebration,
      onOpen: (c, id) => c.eventNav.openBudget(id),
    ),
    EventModuleDefinition(
      id: EventModuleId.vendors,
      title: 'Vendor pipeline',
      subtitle: 'Requests through day-of arrival',
      icon: Icons.handshake_outlined,
      category: EventModuleCategory.planning,
      visible: (_) => true,
      badgeCount: (s) {
        final open = s.vendorRequested - s.vendorCompleted;
        return open > 0 ? open : null;
      },
      onOpen: (c, id) => c.eventNav.openVendorPipeline(id),
    ),
    EventModuleDefinition(
      id: EventModuleId.marketplace,
      title: 'Marketplace',
      subtitle: 'Discover and book vendors',
      icon: Icons.storefront_outlined,
      category: EventModuleCategory.planning,
      visible: (_) => true,
      supportsQuickAction: true,
      onOpen: (c, id) => c.eventNav.openMarketplace(),
    ),
    EventModuleDefinition(
      id: EventModuleId.aiPlanner,
      title: 'AI Event Planner',
      subtitle: 'Smart checklist and recommendations',
      icon: Icons.auto_awesome_outlined,
      category: EventModuleCategory.planning,
      visible: (_) => true,
      onOpen: (c, id) => c.eventNav.openAiPlanner(id),
    ),
    EventModuleDefinition(
      id: EventModuleId.program,
      title: 'Program',
      subtitle: 'Run sheet and timeline',
      icon: Icons.schedule_outlined,
      category: EventModuleCategory.operations,
      visible: (_) => true,
      onOpen: (c, id) => c.eventNav.openProgram(id),
    ),
    EventModuleDefinition(
      id: EventModuleId.seating,
      title: 'Seating',
      subtitle: 'Tables and guest assignment',
      icon: Icons.table_restaurant_outlined,
      category: EventModuleCategory.operations,
      visible: (_) => true,
      onOpen: (c, id) => c.eventNav.openSeating(id),
    ),
    EventModuleDefinition(
      id: EventModuleId.rentals,
      title: 'Rentals',
      subtitle: 'Equipment and event hire',
      icon: Icons.inventory_2_outlined,
      category: EventModuleCategory.operations,
      visible: (_) => true,
      onOpen: (c, id) => c.eventNav.openRentals(id),
    ),
    EventModuleDefinition(
      id: EventModuleId.asoEbi,
      title: 'Aso-Ebi',
      subtitle: 'Attire packages and fabrics',
      icon: Icons.checkroom_outlined,
      category: EventModuleCategory.operations,
      visible: (_) => true,
      onOpen: (c, id) => c.eventNav.openAsoEbi(id),
    ),
    EventModuleDefinition(
      id: EventModuleId.eventDay,
      title: 'Event day',
      subtitle: 'Live operations hub',
      icon: Icons.celebration_outlined,
      category: EventModuleCategory.operations,
      visible: (_) => true,
      supportsQuickAction: true,
      onOpen: (c, id) => c.eventNav.openEventDay(id),
    ),
    EventModuleDefinition(
      id: EventModuleId.website,
      title: 'Website',
      subtitle: 'Celebration microsite',
      icon: Icons.language_outlined,
      category: EventModuleCategory.celebration,
      visible: (_) => true,
      onOpen: (c, id) => c.eventNav.openWebsite(id),
    ),
    EventModuleDefinition(
      id: EventModuleId.celebrationWall,
      title: 'Celebration wall',
      subtitle: 'Messages and live display',
      icon: Icons.forum_outlined,
      category: EventModuleCategory.celebration,
      visible: (_) => true,
      onOpen: (c, id) => c.eventNav.openWall(id),
    ),
    EventModuleDefinition(
      id: EventModuleId.gallery,
      title: 'Gallery',
      subtitle: 'Photos and highlights',
      icon: Icons.photo_library_outlined,
      category: EventModuleCategory.celebration,
      visible: (_) => false,
      onOpen: (c, _) => _comingSoon(c, 'Gallery'),
    ),
    EventModuleDefinition(
      id: EventModuleId.memories,
      title: 'Memories',
      subtitle: 'Guest contributions archive',
      icon: Icons.collections_bookmark_outlined,
      category: EventModuleCategory.celebration,
      visible: (_) => false,
      onOpen: (c, _) => _comingSoon(c, 'Memories'),
    ),
    EventModuleDefinition(
      id: EventModuleId.finance,
      title: 'Finance',
      subtitle: 'Wallet, releases, and settlements',
      icon: Icons.payments_outlined,
      category: EventModuleCategory.business,
      visible: (e) => e.isPrivateCelebration,
      onOpen: (c, id) => c.eventNav.openBudget(id),
    ),
    EventModuleDefinition(
      id: EventModuleId.tickets,
      title: 'Tickets',
      subtitle: 'Sales and tiers',
      icon: Icons.confirmation_number_outlined,
      category: EventModuleCategory.business,
      visible: (e) => e.isPublicTicketed,
      onOpen: (c, id) => c.eventNav.openTickets(id),
    ),
    EventModuleDefinition(
      id: EventModuleId.analytics,
      title: 'Analytics',
      subtitle: 'Performance and trends',
      icon: Icons.insights_outlined,
      category: EventModuleCategory.business,
      visible: (_) => false,
      onOpen: (c, _) {},
    ),
    EventModuleDefinition(
      id: EventModuleId.settings,
      title: 'Settings',
      subtitle: 'Event configuration',
      icon: Icons.settings_outlined,
      category: EventModuleCategory.administration,
      visible: (_) => false,
      onOpen: (c, _) {},
    ),
  ];

  static List<EventModuleDefinition> visibleModules(
    CustomerEvent event,
    EventCommandCenterSnapshot snapshot,
  ) {
    return all.where((m) => m.visible(event)).toList();
  }

  static Map<EventModuleCategory, List<EventModuleDefinition>> groupedModules(
    CustomerEvent event,
    EventCommandCenterSnapshot snapshot,
  ) {
    final visible = visibleModules(event, snapshot);
    return {
      for (final category in EventModuleCategory.values)
        category: visible.where((m) => m.category == category).toList(),
    };
  }

  static List<EventModuleDefinition> quickActionModules(
    CustomerEvent event,
    EventCommandCenterSnapshot snapshot,
  ) {
    return visibleModules(event, snapshot).where((m) => m.supportsQuickAction).toList();
  }

  /// Maps legacy Organizer workspace tab keys to module opens.
  static void openLegacyTab(BuildContext context, String eventId, String tabKey) {
    final nav = context.eventNav;
    switch (tabKey) {
      case 'overview':
        return;
      case 'tickets':
        nav.openTickets(eventId);
      case 'attendees':
        nav.openGuests(eventId);
      case 'vendors':
        nav.openVendorPipeline(eventId);
      case 'marketplace':
        nav.openMarketplace();
      case 'finance':
        nav.openBudget(eventId);
      case 'operations':
        nav.openEventDay(eventId);
      case 'analytics':
      case 'settings':
        return;
      default:
        return;
    }
  }

  static void openLegacyTabIndex(BuildContext context, String eventId, int index) {
    const keys = [
      'overview',
      'tickets',
      'attendees',
      'vendors',
      'marketplace',
      'finance',
      'operations',
      'analytics',
      'settings',
    ];
    if (index < 0 || index >= keys.length) return;
    openLegacyTab(context, eventId, keys[index]);
  }
}
