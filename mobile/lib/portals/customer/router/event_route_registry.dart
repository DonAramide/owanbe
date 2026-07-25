/// Canonical Event OS route paths (Phase 42.1).
///
/// All event-scoped navigation must use this registry — do not hardcode `/events/...` paths.
abstract final class EventRouteRegistry {
  // — Customer shell —
  static const home = '/home';
  static const myEvents = '/events/mine';
  static const createEvent = '/events/create';
  static const guestsHub = '/guests';
  static const profile = '/profile';
  static const portfolio = '/portfolio';
  static const portfolioExecutive = '/portfolio/executive';

  // — Public discovery (reachable from Customer shell) —
  static const discover = '/events';
  static const attendeeDashboard = '/attendee';
  static const attendeeFindTicket = '/attendee/find-ticket';
  static const legacyAttending = '/attending';
  static const landing = '/';

  // — Global marketplace —
  static const vendors = '/vendors';

  static String vendorsWithCategory(String category) =>
      '$vendors?category=${Uri.encodeComponent(category)}';

  /// Marketplace scoped to the active event (no event picker in vendor requests).
  static String vendorsForEvent(String eventId) =>
      '$vendors?eventId=${Uri.encodeComponent(eventId)}';

  static String rentalsMarketplace({String? eventId}) =>
      eventId != null
          ? '/vendors/rentals?eventId=${Uri.encodeComponent(eventId)}'
          : '/vendors/rentals';

  static String vendorDetail(String vendorId) => '/vendors/$vendorId';

  static String vendorDetailForEvent(String vendorId, {String? eventId}) {
    final base = vendorDetail(vendorId);
    if (eventId == null || eventId.isEmpty) return base;
    return '$base?eventId=${Uri.encodeComponent(eventId)}';
  }

  // — Event hub & modules —
  static String event(String eventId) => '/events/$eventId';

  static String eventBudget(String eventId) => '/events/$eventId/budget';

  static String eventGuests(String eventId) => '/events/$eventId/guests';

  static String eventInvitations(String eventId) => '/events/$eventId/invitations';

  static String eventAiPlanner(String eventId) => '/events/$eventId/ai-planner';

  static String eventDay(String eventId) => '/events/$eventId/day';

  static String eventDayCheckIn(String eventId) => '/events/$eventId/day/check-in';

  static String eventDayQrScan(String eventId) => '/events/$eventId/day/scan';

  static String eventDayIncidents(String eventId) => '/events/$eventId/day/incidents';

  static String eventDayFeed(String eventId) => '/events/$eventId/day/feed';

  static String eventWebsite(String eventId) => '/events/$eventId/website';

  static String eventWall(String eventId) => '/events/$eventId/wall';

  static String eventWallDisplay(String eventId) => '/events/$eventId/wall/display';

  static String eventAttire(String eventId) => '/events/$eventId/attire';

  static String eventAsoEbi(String eventId) => '/events/$eventId/aso-ebi';

  static String eventRentals(String eventId) => '/events/$eventId/rentals';

  static String eventSeating(String eventId) => '/events/$eventId/seating';

  static String eventProgram(String eventId) => '/events/$eventId/program';

  static String eventVendorPipeline(String eventId) => '/events/$eventId/vendor-pipeline';

  /// Event-scoped vendor sourcing (alias for vendor pipeline).
  static String eventVendors(String eventId) => '/events/$eventId/vendors';

  /// Attendee ticket purchase — public commerce flow only.
  static String eventTickets(String eventId) => '/events/$eventId/tickets';

  /// Organizer tier management — never mixed with attendee purchase.
  static String eventTicketsManage(String eventId) => '/events/$eventId/tickets/manage';

  /// Reads `eventId` from marketplace query when launched from Event Desktop.
  static String? marketplaceEventIdFromLocation(String location) {
    final uri = Uri.tryParse(location);
    return uri?.queryParameters['eventId'];
  }

  static bool isShellPath(String location) {
    if (location == home) return true;
    if (location == createEvent) return true;
    if (location == guestsHub || location.startsWith('$guestsHub/')) return true;
    if (location == profile || location.startsWith('$profile/')) return true;
    if (location == myEvents) return true;
    if (location == portfolio || location.startsWith('$portfolio/')) return true;
    return false;
  }

  static bool isEventModulePath(String location) {
    final match = RegExp(r'^/events/([^/]+)/').firstMatch(location);
    if (match == null) return false;
    final segment = match.group(1)!;
    return segment != 'mine' && segment != 'create';
  }

  /// Event command center overview — `/events/:eventId` (no module segment).
  static bool isEventOverviewPath(String location) {
    final match = RegExp(r'^/events/([^/]+)$').firstMatch(location);
    if (match == null) return false;
    final segment = match.group(1)!;
    return segment != 'mine' && segment != 'create';
  }

  /// All Organizer (Customer) workspace routes — shell tabs, event overview, and modules.
  ///
  /// Used by [ExperienceRoutes.workspaceFromPath] so the universal router guard never
  /// sends valid organizer navigation to `/hub`.
  static bool isOrganizerWorkspacePath(String location) {
    final path = location.split('?').first;
    return isShellPath(path) || isEventOverviewPath(path) || isEventModulePath(path);
  }
}
