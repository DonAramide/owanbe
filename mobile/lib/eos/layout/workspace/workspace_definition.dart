import 'package:flutter/material.dart';

enum WorkspaceEntityType {
  tenant,
  organizer,
  event,
  vendor,
  attendee,
  ticket,
  order,
  payment,
  refund,
  payout,
  incident,
  auditRecord,
  commerce,
  service,
  database,
  queue,
  integration,
  infrastructure,
  webhook,
  analytics,
  security,
  user,
}

class WorkspaceDefinition {
  const WorkspaceDefinition({
    required this.entityType,
    required this.title,
    required this.tabs,
    required this.quickActions,
    required this.metrics,
    this.icon = Icons.grid_view_outlined,
  });

  final WorkspaceEntityType entityType;
  final String title;
  final List<WorkspaceTabDefinition> tabs;
  final List<WorkspaceActionDefinition> quickActions;
  final List<WorkspaceMetricDefinition> metrics;
  final IconData icon;
}

class WorkspaceTabDefinition {
  const WorkspaceTabDefinition({
    required this.label,
    required this.builder,
    this.icon,
  });

  final String label;
  final Widget Function(BuildContext context, String entityId) builder;
  final IconData? icon;
}

class WorkspaceActionDefinition {
  const WorkspaceActionDefinition({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isDanger = false,
  });

  final String label;
  final IconData icon;
  final Future<void> Function(BuildContext context, String entityId) onPressed;
  final bool isDanger;
}

class WorkspaceMetricDefinition {
  const WorkspaceMetricDefinition({
    required this.label,
    required this.valueResolver,
    required this.subtitle,
  });

  final String label;
  final String Function(Map<String, dynamic> data) valueResolver;
  final String subtitle;
}
