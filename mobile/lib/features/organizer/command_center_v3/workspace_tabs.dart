import '../models/organizer_models.dart';

/// Stable workspace tab keys for deep links (`?tab=overview`).
enum EventWorkspaceTab {
  overview,
  tickets,
  attendees,
  vendors,
  marketplace,
  finance,
  operations,
  analytics,
  settings,
}

extension EventWorkspaceTabX on EventWorkspaceTab {
  String get key => name;

  String get label => switch (this) {
        EventWorkspaceTab.overview => 'Overview',
        EventWorkspaceTab.tickets => 'Tickets',
        EventWorkspaceTab.attendees => 'Attendees',
        EventWorkspaceTab.vendors => 'Vendors',
        EventWorkspaceTab.marketplace => 'Marketplace',
        EventWorkspaceTab.finance => 'Finance',
        EventWorkspaceTab.operations => 'Operations',
        EventWorkspaceTab.analytics => 'Analytics',
        EventWorkspaceTab.settings => 'Settings',
      };
}

List<EventWorkspaceTab> workspaceTabsFor(OrganizerEvent event) {
  final tabs = <EventWorkspaceTab>[EventWorkspaceTab.overview];
  if (event.isPublicTicketed) {
    tabs.add(EventWorkspaceTab.tickets);
  }
  tabs.addAll([
    EventWorkspaceTab.attendees,
    EventWorkspaceTab.vendors,
    EventWorkspaceTab.marketplace,
    EventWorkspaceTab.finance,
    EventWorkspaceTab.operations,
    EventWorkspaceTab.analytics,
    EventWorkspaceTab.settings,
  ]);
  return tabs;
}

EventWorkspaceTab resolveWorkspaceTab(OrganizerEvent event, {String? tabKey, int? legacyIndex}) {
  final tabs = workspaceTabsFor(event);
  if (tabKey != null && tabKey.isNotEmpty) {
    for (final t in EventWorkspaceTab.values) {
      if (t.key == tabKey && tabs.contains(t)) return t;
    }
  }
  if (legacyIndex != null && legacyIndex >= 0 && legacyIndex < tabs.length) {
    return tabs[legacyIndex];
  }
  return EventWorkspaceTab.overview;
}

int workspaceTabIndex(OrganizerEvent event, EventWorkspaceTab tab) {
  return workspaceTabsFor(event).indexOf(tab);
}
