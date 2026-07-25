import 'package:flutter/material.dart';

import '../models/customer_event_models.dart';
import '../navigation/event_navigator.dart';
import 'event_closing_models.dart';

void openClosingModuleLink(
  BuildContext context,
  String eventId,
  ClosingModuleLink link, {
  CustomerEvent? event,
}) {
  final nav = context.eventNav;
  switch (link) {
    case ClosingModuleLink.budget:
      nav.openBudget(eventId);
    case ClosingModuleLink.guests:
      nav.openGuests(eventId);
    case ClosingModuleLink.vendors:
      nav.openVendorPipeline(eventId);
    case ClosingModuleLink.tickets:
      if (event?.isPublicTicketed == true) {
        nav.openTicketsManage(eventId);
      } else {
        nav.openInvitations(eventId);
      }
    case ClosingModuleLink.program:
      nav.openProgram(eventId);
    case ClosingModuleLink.wall:
      nav.openWall(eventId);
    case ClosingModuleLink.aiPlanner:
      nav.openAiPlanner(eventId);
  }
}
