import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/event_route_registry.dart';

/// Shared navigator for Event OS modules (Phase 42.1+).
///
/// All Customer Portal navigation must use this abstraction — no hardcoded routes.
class EventNavigator {
  const EventNavigator(this.context);

  final BuildContext context;

  // — Customer shell —

  void goHome() => context.go(EventRouteRegistry.home);

  void goMyEvents() => context.go(EventRouteRegistry.myEvents);

  void goCreateEvent() => context.go(EventRouteRegistry.createEvent);

  void goGuestsHub() => context.go(EventRouteRegistry.guestsHub);

  void goProfile() => context.go(EventRouteRegistry.profile);

  void openDiscover() => context.push(EventRouteRegistry.discover);

  void openAttendeeDashboard() => context.push(EventRouteRegistry.attendeeDashboard);

  void goLanding() => context.go(EventRouteRegistry.landing);

  // — Event workspace —

  /// Opens the Event Command Center (`/events/:eventId`).
  void openOverview(String eventId) => context.push(EventRouteRegistry.event(eventId));

  /// Returns to Command Center — pop when possible, otherwise `go` to overview.
  void backToOverview(String eventId) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(EventRouteRegistry.event(eventId));
    }
  }

  void openGuests(String eventId) => context.push(EventRouteRegistry.eventGuests(eventId));

  void openInvitations(String eventId) => context.push(EventRouteRegistry.eventInvitations(eventId));

  void openBudget(String eventId) => context.push(EventRouteRegistry.eventBudget(eventId));

  void openProgram(String eventId) => context.push(EventRouteRegistry.eventProgram(eventId));

  void openSeating(String eventId) => context.push(EventRouteRegistry.eventSeating(eventId));

  void openRentals(String eventId) => context.push(EventRouteRegistry.eventRentals(eventId));

  void openVendorPipeline(String eventId) =>
      context.push(EventRouteRegistry.eventVendorPipeline(eventId));

  void openTickets(String eventId) => context.push(EventRouteRegistry.eventTickets(eventId));

  void openWebsite(String eventId) => context.push(EventRouteRegistry.eventWebsite(eventId));

  void openWall(String eventId) => context.push(EventRouteRegistry.eventWall(eventId));

  void openWallDisplay(String eventId) => context.push(EventRouteRegistry.eventWallDisplay(eventId));

  /// Aso-Ebi management — canonical route is attire (`/events/:id/attire`).
  void openAsoEbi(String eventId) => context.push(EventRouteRegistry.eventAttire(eventId));

  void openAttire(String eventId) => openAsoEbi(eventId);

  void openEventDay(String eventId) => context.push(EventRouteRegistry.eventDay(eventId));

  void openAiPlanner(String eventId) => context.push(EventRouteRegistry.eventAiPlanner(eventId));

  void openMarketplace() => context.push(EventRouteRegistry.vendors);

  void openMarketplaceCategory(String category) => context.push(
        EventRouteRegistry.vendorsWithCategory(category),
      );

  void openRentalsMarketplace({String? eventId}) =>
      context.push(EventRouteRegistry.rentalsMarketplace(eventId: eventId));

  void openVendorDetail(String vendorId) => context.push(EventRouteRegistry.vendorDetail(vendorId));

  void openPublicEvent(String eventId) => context.push(EventRouteRegistry.event(eventId));
}

/// Static convenience API matching Phase 42.2 navigation contract.
abstract final class EventNavigation {
  static void openOverview(BuildContext context, String eventId) =>
      context.eventNav.openOverview(eventId);

  static void openGuests(BuildContext context, String eventId) =>
      context.eventNav.openGuests(eventId);

  static void openInvitations(BuildContext context, String eventId) =>
      context.eventNav.openInvitations(eventId);

  static void openProgram(BuildContext context, String eventId) =>
      context.eventNav.openProgram(eventId);

  static void openBudget(BuildContext context, String eventId) =>
      context.eventNav.openBudget(eventId);

  static void openSeating(BuildContext context, String eventId) =>
      context.eventNav.openSeating(eventId);

  static void openWebsite(BuildContext context, String eventId) =>
      context.eventNav.openWebsite(eventId);

  static void openWall(BuildContext context, String eventId) =>
      context.eventNav.openWall(eventId);

  static void openAsoEbi(BuildContext context, String eventId) =>
      context.eventNav.openAsoEbi(eventId);

  static void openRentals(BuildContext context, String eventId) =>
      context.eventNav.openRentals(eventId);

  static void openMarketplace(BuildContext context) => context.eventNav.openMarketplace();

  static void openVendorPipeline(BuildContext context, String eventId) =>
      context.eventNav.openVendorPipeline(eventId);

  static void openEventDay(BuildContext context, String eventId) =>
      context.eventNav.openEventDay(eventId);

  static void openAiPlanner(BuildContext context, String eventId) =>
      context.eventNav.openAiPlanner(eventId);
}

extension EventNavigatorContext on BuildContext {
  EventNavigator get eventNav => EventNavigator(this);
}
