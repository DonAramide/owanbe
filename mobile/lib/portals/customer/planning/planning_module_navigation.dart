import 'package:flutter/material.dart';

import '../models/customer_event_models.dart';
import '../navigation/event_navigator.dart';
import 'event_planning_models.dart';

/// Opens the existing Event OS module for a planning deep-link.
void openPlanningModuleLink(
  BuildContext context,
  String eventId,
  PlanningModuleLink link, {
  CustomerEvent? event,
}) {
  final nav = context.eventNav;
  switch (link) {
    case PlanningModuleLink.guests:
      nav.openGuests(eventId);
    case PlanningModuleLink.invitations:
      nav.openInvitations(eventId);
    case PlanningModuleLink.budget:
      nav.openBudget(eventId);
    case PlanningModuleLink.vendors:
      nav.openVendorPipeline(eventId);
    case PlanningModuleLink.marketplace:
      nav.openMarketplace(eventId: eventId);
    case PlanningModuleLink.tickets:
      if (event?.isPublicTicketed == true) {
        nav.openTicketsManage(eventId);
      } else {
        nav.openInvitations(eventId);
      }
    case PlanningModuleLink.program:
      nav.openProgram(eventId);
    case PlanningModuleLink.seating:
      nav.openSeating(eventId);
    case PlanningModuleLink.rentals:
      nav.openRentals(eventId);
    case PlanningModuleLink.website:
      nav.openWebsite(eventId);
    case PlanningModuleLink.wall:
      nav.openWall(eventId);
    case PlanningModuleLink.aiPlanner:
      nav.openAiPlanner(eventId);
    case PlanningModuleLink.eventDay:
      nav.openEventDay(eventId);
  }
}
