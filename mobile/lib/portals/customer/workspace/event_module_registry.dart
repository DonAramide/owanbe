import 'package:flutter/material.dart';

import '../models/command_center_models.dart';
import '../models/customer_event_models.dart';
import '../navigation/event_navigator.dart';

/// Event OS module categories for workspace layout (Phase 42.3).
enum EventModuleCategory {
  planning('Planning', 'Vendors, guests, invitations, and AI planning'),
  operations('Operations', 'Seating, program, live ops, and rentals'),
  experience('Experience', 'Website and celebration wall'),
  commerce('Commerce', 'Budget, finance, and tickets'),
  administration('Administration', 'Analytics and configuration');

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

/// Desktop section grouping for [EventDesktop].
class EventDesktopSection {
  const EventDesktopSection({
    required this.title,
    required this.subtitle,
    required this.modules,
  });

  final String title;
  final String subtitle;
  final List<EventModuleDefinition> modules;
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
      category: EventModuleCategory.commerce,
      visible: (e) => e.isPrivateCelebration,
      onOpen: (c, id) => c.eventNav.openBudget(id),
    ),
    EventModuleDefinition(
      id: EventModuleId.vendors,
      title: 'Vendors',
      subtitle: 'Requests, quotes, and hires',
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
      onOpen: (c, id) => c.eventNav.openMarketplace(eventId: id),
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
      title: 'Attire',
      subtitle: 'Aso-Ebi packages and fabrics',
      icon: Icons.checkroom_outlined,
      category: EventModuleCategory.operations,
      visible: (_) => true,
      onOpen: (c, id) => c.eventNav.openAsoEbi(id),
    ),
    EventModuleDefinition(
      id: EventModuleId.eventDay,
      title: 'Live Operations',
      subtitle: 'Day-of command hub',
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
      category: EventModuleCategory.experience,
      visible: (_) => true,
      onOpen: (c, id) => c.eventNav.openWebsite(id),
    ),
    EventModuleDefinition(
      id: EventModuleId.celebrationWall,
      title: 'Event Wall',
      subtitle: 'Messages and live display',
      icon: Icons.forum_outlined,
      category: EventModuleCategory.experience,
      visible: (_) => true,
      onOpen: (c, id) => c.eventNav.openWall(id),
    ),
    EventModuleDefinition(
      id: EventModuleId.gallery,
      title: 'Gallery',
      subtitle: 'Photos and highlights',
      icon: Icons.photo_library_outlined,
      category: EventModuleCategory.experience,
      visible: (_) => false,
      onOpen: (c, _) => _comingSoon(c, 'Gallery'),
    ),
    EventModuleDefinition(
      id: EventModuleId.memories,
      title: 'Memories',
      subtitle: 'Guest contributions archive',
      icon: Icons.collections_bookmark_outlined,
      category: EventModuleCategory.experience,
      visible: (_) => false,
      onOpen: (c, _) => _comingSoon(c, 'Memories'),
    ),
    EventModuleDefinition(
      id: EventModuleId.finance,
      title: 'Finance',
      subtitle: 'Wallet, releases, and settlements',
      icon: Icons.payments_outlined,
      category: EventModuleCategory.commerce,
      visible: (e) => e.isPrivateCelebration,
      onOpen: (c, id) => c.eventNav.openBudget(id),
    ),
    EventModuleDefinition(
      id: EventModuleId.tickets,
      title: 'Tickets',
      subtitle: 'Tier management and sales',
      icon: Icons.confirmation_number_outlined,
      category: EventModuleCategory.commerce,
      visible: (e) => e.isPublicTicketed,
      onOpen: (c, id) => c.eventNav.openTicketsManage(id),
    ),
    EventModuleDefinition(
      id: EventModuleId.analytics,
      title: 'Analytics',
      subtitle: 'Performance and trends',
      icon: Icons.insights_outlined,
      category: EventModuleCategory.commerce,
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

  /// Modules eligible for the Event Desktop launcher (Phase 1).
  ///
  /// Excludes hidden / no-op modules (analytics, settings, gallery, memories).
  static const _desktopExcludedIds = <EventModuleId>{
    EventModuleId.analytics,
    EventModuleId.settings,
    EventModuleId.gallery,
    EventModuleId.memories,
  };

  static List<EventDesktopSection> desktopSections(
    CustomerEvent event,
    EventCommandCenterSnapshot snapshot,
  ) {
    final visible = visibleModules(event, snapshot)
        .where((m) => !_desktopExcludedIds.contains(m.id))
        .toList();

    EventDesktopSection section(EventModuleCategory cat) {
      final modules = visible.where((m) => m.category == cat).toList();
      return EventDesktopSection(
        title: cat.title,
        subtitle: cat.subtitle,
        modules: modules,
      );
    }

    return [
      section(EventModuleCategory.planning),
      section(EventModuleCategory.commerce),
      section(EventModuleCategory.operations),
      section(EventModuleCategory.experience),
      section(EventModuleCategory.administration),
    ].where((s) => s.modules.isNotEmpty).toList();
  }

  /// Maps legacy Organizer workspace tab keys to module opens.
  static void openLegacyTab(BuildContext context, String eventId, String tabKey) {
    final nav = context.eventNav;
    switch (tabKey) {
      case 'overview':
        return;
      case 'tickets':
        nav.openTicketsManage(eventId);
      case 'attendees':
        nav.openGuests(eventId);
      case 'vendors':
        nav.openVendorPipeline(eventId);
      case 'marketplace':
        nav.openMarketplace(eventId: eventId);
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
