import 'package:flutter/material.dart';

import '../navigation/event_navigator.dart';
import 'event_operations_models.dart';

void executeOperationsCommand(
  BuildContext context,
  String eventId,
  OperationsCommandAction action,
) {
  final nav = context.eventNav;
  switch (action) {
    case OperationsCommandAction.openCheckIn:
      nav.openCheckIn(eventId);
    case OperationsCommandAction.broadcastAnnouncement:
      nav.openWall(eventId);
    case OperationsCommandAction.contactVendor:
      nav.openVendorPipeline(eventId);
    case OperationsCommandAction.contactStaff:
      nav.openProgram(eventId);
    case OperationsCommandAction.emergencyMode:
      nav.openIncidents(eventId);
    case OperationsCommandAction.logIncident:
      nav.openIncidents(eventId);
  }
}

IconData iconForOperationsCommand(OperationsCommandAction action) => switch (action) {
      OperationsCommandAction.openCheckIn => Icons.qr_code_scanner_outlined,
      OperationsCommandAction.broadcastAnnouncement => Icons.campaign_outlined,
      OperationsCommandAction.contactVendor => Icons.handshake_outlined,
      OperationsCommandAction.contactStaff => Icons.groups_outlined,
      OperationsCommandAction.emergencyMode => Icons.emergency_outlined,
      OperationsCommandAction.logIncident => Icons.report_outlined,
    };
