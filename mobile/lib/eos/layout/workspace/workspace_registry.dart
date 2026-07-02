import 'package:flutter/material.dart';

import 'workspace_definition.dart';

class WorkspaceRegistry {
  static final Map<WorkspaceEntityType, WorkspaceDefinition> _registry = {};

  static void register(WorkspaceDefinition definition) {
    _registry[definition.entityType] = definition;
  }

  static WorkspaceDefinition? get(WorkspaceEntityType type) {
    return _registry[type];
  }

  static IconData getIcon(WorkspaceEntityType type) {
    return _registry[type]?.icon ?? Icons.grid_view_outlined;
  }
}
