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
