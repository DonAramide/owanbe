import 'event_route_registry.dart';

/// Compatibility redirects from legacy Organizer Portal paths to Event OS routes.
///
/// Legacy screens remain in the codebase but are not primary navigation targets.
abstract final class LegacyOrganizerRouter {
  static const deprecatedPrefix = '/organizer';

  /// Returns an Event OS path when [location] is a legacy organizer route.
  static String? tryRedirect(String location, [Map<String, String> query = const {}]) {
    final path = location.split('?').first;
    if (!path.startsWith(deprecatedPrefix)) return null;

    if (path == deprecatedPrefix || path == '$deprecatedPrefix/') {
      return EventRouteRegistry.home;
    }

    if (path == '$deprecatedPrefix/events/new') {
      return EventRouteRegistry.createEvent;
    }

    final moduleMatch = RegExp(r'^/organizer/events/([^/]+)/(.+)$').firstMatch(path);
    if (moduleMatch != null) {
      final eventId = moduleMatch.group(1)!;
      final modulePath = moduleMatch.group(2)!;
      return redirectModule(eventId, modulePath, query);
    }

    final eventMatch = RegExp(r'^/organizer/events/([^/]+)$').firstMatch(path);
    if (eventMatch != null) {
      final eventId = eventMatch.group(1)!;
      return redirectEvent(eventId, query);
    }

    // Unknown legacy path — send organizers to customer home.
    return EventRouteRegistry.home;
  }

  /// Maps legacy event submodule paths to Event OS module routes.
  static String redirectModule(String eventId, String modulePath, Map<String, String> query) {
    final segment = modulePath.split('/').first;
    final base = switch (segment) {
      'guests' || 'attendees' => EventRouteRegistry.eventGuests(eventId),
      'invitations' => EventRouteRegistry.eventInvitations(eventId),
      'program' => EventRouteRegistry.eventProgram(eventId),
      'seating' => EventRouteRegistry.eventSeating(eventId),
      'budget' || 'finance' => EventRouteRegistry.eventBudget(eventId),
      'rentals' => EventRouteRegistry.eventRentals(eventId),
      'vendors' || 'vendor-pipeline' => EventRouteRegistry.eventVendorPipeline(eventId),
      'day' || 'operations' => EventRouteRegistry.eventDay(eventId),
      'wall' => modulePath.contains('display')
          ? EventRouteRegistry.eventWallDisplay(eventId)
          : EventRouteRegistry.eventWall(eventId),
      'website' => EventRouteRegistry.eventWebsite(eventId),
      'attire' || 'aso-ebi' => EventRouteRegistry.eventAttire(eventId),
      'ai-planner' => EventRouteRegistry.eventAiPlanner(eventId),
      'tickets' => EventRouteRegistry.eventTickets(eventId),
      'analytics' || 'settings' || 'overview' => EventRouteRegistry.event(eventId),
      _ => EventRouteRegistry.event(eventId),
    };
    return _appendQuery(base, query);
  }

  /// Maps legacy workspace tab query params to Event OS module routes.
  static String redirectEvent(String eventId, Map<String, String> query) {
    final tabKey = query['tabKey']?.trim();
    if (tabKey != null && tabKey.isNotEmpty) {
      final target = switch (tabKey) {
        'overview' => EventRouteRegistry.event(eventId),
        'tickets' => EventRouteRegistry.eventTickets(eventId),
        'attendees' => EventRouteRegistry.eventGuests(eventId),
        'vendors' => EventRouteRegistry.eventVendors(eventId),
        'marketplace' => EventRouteRegistry.vendors,
        'finance' => EventRouteRegistry.eventBudget(eventId),
        'operations' => EventRouteRegistry.eventDay(eventId),
        'analytics' => EventRouteRegistry.event(eventId),
        'settings' => EventRouteRegistry.event(eventId),
        _ => EventRouteRegistry.event(eventId),
      };
      return _appendQuery(target, query, exclude: {'tabKey', 'tab'});
    }

    final tab = query['tab']?.trim();
    if (tab != null && tab.isNotEmpty) {
      final target = switch (tab) {
        '1' => EventRouteRegistry.eventGuests(eventId),
        '2' => EventRouteRegistry.eventTickets(eventId),
        '3' => EventRouteRegistry.eventVendors(eventId),
        '4' => EventRouteRegistry.vendors,
        '5' => EventRouteRegistry.eventBudget(eventId),
        '6' => EventRouteRegistry.eventDay(eventId),
        _ => EventRouteRegistry.event(eventId),
      };
      return _appendQuery(target, query, exclude: {'tabKey', 'tab'});
    }

    final module = query['module']?.trim();
    if (module != null && module.isNotEmpty) {
      return redirectModule(eventId, module, query);
    }

    return EventRouteRegistry.event(eventId);
  }

  static String _appendQuery(
    String path,
    Map<String, String> query, {
    Set<String> exclude = const {},
  }) {
    if (query.isEmpty) return path;
    final params = Map<String, String>.from(query)..removeWhere((k, _) => exclude.contains(k));
    if (params.isEmpty) return path;
    final uri = Uri(path: path, queryParameters: params);
    return uri.toString();
  }
}
