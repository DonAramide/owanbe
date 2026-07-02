import 'event_route_registry.dart';

/// Customer Portal route paths.
///
/// Deprecated: prefer [EventRouteRegistry] for all new code (Phase 42.1).
@Deprecated('Use EventRouteRegistry — Customer Portal Event OS canonical paths')
abstract final class CustomerRoutes {
  static const home = EventRouteRegistry.home;
  static const myEvents = EventRouteRegistry.myEvents;
  static const createEvent = EventRouteRegistry.createEvent;
  static const guests = EventRouteRegistry.guestsHub;
  static const profile = EventRouteRegistry.profile;

  static String eventDetail(String eventId) => EventRouteRegistry.event(eventId);

  static String eventBudget(String eventId) => EventRouteRegistry.eventBudget(eventId);

  static String eventGuests(String eventId) => EventRouteRegistry.eventGuests(eventId);

  static String eventInvitations(String eventId) => EventRouteRegistry.eventInvitations(eventId);

  static String eventAiPlanner(String eventId) => EventRouteRegistry.eventAiPlanner(eventId);

  static String eventDay(String eventId) => EventRouteRegistry.eventDay(eventId);

  static String eventWebsite(String eventId) => EventRouteRegistry.eventWebsite(eventId);

  static String eventWall(String eventId) => EventRouteRegistry.eventWall(eventId);

  static String eventWallDisplay(String eventId) => EventRouteRegistry.eventWallDisplay(eventId);

  static String eventAsoEbi(String eventId) => EventRouteRegistry.eventAsoEbi(eventId);

  static String eventAttire(String eventId) => EventRouteRegistry.eventAttire(eventId);

  static String eventRentals(String eventId) => EventRouteRegistry.eventRentals(eventId);

  static String eventSeating(String eventId) => EventRouteRegistry.eventSeating(eventId);

  static String eventProgram(String eventId) => EventRouteRegistry.eventProgram(eventId);

  static String eventVendorPipeline(String eventId) => EventRouteRegistry.eventVendorPipeline(eventId);

  static String rentalsMarketplace({String? eventId}) =>
      EventRouteRegistry.rentalsMarketplace(eventId: eventId);

  static const vendors = EventRouteRegistry.vendors;

  static String vendorDetail(String vendorId) => EventRouteRegistry.vendorDetail(vendorId);

  static bool isShellPath(String location) => EventRouteRegistry.isShellPath(location);
}
