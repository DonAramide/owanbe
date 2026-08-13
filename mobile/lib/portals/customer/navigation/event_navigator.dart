import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../identity/experience_navigation.dart';
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

  void openPortfolio() => context.push(EventRouteRegistry.portfolio);

  void openDiscover() => context.push(EventRouteRegistry.discover);

  void openAttendeeDashboard() => context.push(EventRouteRegistry.attendeeDashboard);

  void goLanding() => context.go(EventRouteRegistry.landing);

  // — Event workspace —

  /// Opens the Event Command Center (`/events/:eventId`).
  void openOverview(String eventId) => context.push(EventRouteRegistry.event(eventId));

  /// Returns to Command Center — pop when possible, otherwise policy fallback.
  void backToOverview(String eventId) {
    ExperienceNavigation.navigateBack(context);
  }
  void openGuests(String eventId) => context.push(EventRouteRegistry.eventGuests(eventId));

  void openInvitations(String eventId) => context.push(EventRouteRegistry.eventInvitations(eventId));

  void openBudget(String eventId) => context.push(EventRouteRegistry.eventBudget(eventId));

  void openProgram(String eventId) => context.push(EventRouteRegistry.eventProgram(eventId));

  void openSeating(String eventId) => context.push(EventRouteRegistry.eventSeating(eventId));

  void openRentals(String eventId) => context.push(EventRouteRegistry.eventRentals(eventId));

  void openVendorPipeline(String eventId) =>
      context.push(EventRouteRegistry.eventVendorPipeline(eventId));

  /// Attendee ticket purchase at `/events/:id/tickets`.
  void openTickets(String eventId) => context.push(EventRouteRegistry.eventTickets(eventId));

  /// Organizer tier management at `/events/:id/tickets/manage`.
  void openTicketsManage(String eventId) =>
      context.push(EventRouteRegistry.eventTicketsManage(eventId));

  void openWebsite(String eventId) => context.push(EventRouteRegistry.eventWebsite(eventId));

  void openWall(String eventId) => context.push(EventRouteRegistry.eventWall(eventId));

  void openWallDisplay(String eventId) => context.push(EventRouteRegistry.eventWallDisplay(eventId));

  /// Aso-Ebi management — canonical route is attire (`/events/:id/attire`).
  void openAsoEbi(String eventId) => context.push(EventRouteRegistry.eventAttire(eventId));

  void openAttire(String eventId) => openAsoEbi(eventId);

  void openEventDay(String eventId) => context.push(EventRouteRegistry.eventDay(eventId));

  void openCheckIn(String eventId) => context.push(EventRouteRegistry.eventDayCheckIn(eventId));

  void openQrScan(String eventId) => context.push(EventRouteRegistry.eventDayQrScan(eventId));

  void openIncidents(String eventId) => context.push(EventRouteRegistry.eventDayIncidents(eventId));

  void openOpsFeed(String eventId) => context.push(EventRouteRegistry.eventDayFeed(eventId));

  void openAiPlanner(String eventId) => context.push(EventRouteRegistry.eventAiPlanner(eventId));

  /// Global marketplace; pass [eventId] when launched from Event Desktop.
  void openMarketplace({String? eventId}) {
    if (eventId != null && eventId.isNotEmpty) {
      context.push(EventRouteRegistry.vendorsForEvent(eventId));
    } else {
      context.push(EventRouteRegistry.vendors);
    }
  }

  void openMarketplaceCategory(String category, {String? eventId}) {
    final base = EventRouteRegistry.vendorsWithCategory(category);
    if (eventId != null && eventId.isNotEmpty) {
      context.push('$base&eventId=${Uri.encodeComponent(eventId)}');
    } else {
      context.push(base);
    }
  }

  void openRentalsMarketplace({String? eventId}) =>
      context.push(EventRouteRegistry.rentalsMarketplace(eventId: eventId));

  void openVendorDetail(String vendorId, {String? eventId, String? service}) =>
      context.push(
        EventRouteRegistry.vendorDetailForEvent(
          vendorId,
          eventId: eventId,
          service: service,
        ),
      );

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

  static void openMarketplace(BuildContext context, {String? eventId}) =>
      context.eventNav.openMarketplace(eventId: eventId);

  static void openTicketsManage(BuildContext context, String eventId) =>
      context.eventNav.openTicketsManage(eventId);

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
