/// Customer Portal route paths.
abstract final class CustomerRoutes {
  static const home = '/home';
  static const myEvents = '/events/mine';
  static const createEvent = '/events/create';
  static const guests = '/guests';
  static const profile = '/profile';

  static String eventDetail(String eventId) => '/events/$eventId';

  static String eventBudget(String eventId) => '/events/$eventId/budget';

  static String eventGuests(String eventId) => '/events/$eventId/guests';

  static String eventInvitations(String eventId) => '/events/$eventId/invitations';

  static String eventAiPlanner(String eventId) => '/events/$eventId/ai-planner';

  static String eventDay(String eventId) => '/events/$eventId/day';

  static String eventWebsite(String eventId) => '/events/$eventId/website';

  static String eventWall(String eventId) => '/events/$eventId/wall';

  static String eventWallDisplay(String eventId) => '/events/$eventId/wall/display';

  static String eventAsoEbi(String eventId) => '/events/$eventId/aso-ebi';

  static String eventAttire(String eventId) => '/events/$eventId/attire';

  static String eventRentals(String eventId) => '/events/$eventId/rentals';

  static String eventSeating(String eventId) => '/events/$eventId/seating';

  static String eventProgram(String eventId) => '/events/$eventId/program';

  static String eventVendorPipeline(String eventId) => '/events/$eventId/vendor-pipeline';

  static String rentalsMarketplace({String? eventId}) =>
      eventId != null ? '/vendors/rentals?eventId=$eventId' : '/vendors/rentals';

  static const vendors = '/vendors';

  static String vendorDetail(String vendorId) => '/vendors/$vendorId';

  static bool isShellPath(String location) {
    if (location == home) return true;
    if (location == createEvent) return true;
    if (location == guests || location.startsWith('$guests/')) return true;
    if (location == profile || location.startsWith('$profile/')) return true;
    if (location == myEvents) return true;
    return false;
  }
}
