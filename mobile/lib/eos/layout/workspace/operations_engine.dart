import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'entity_engine.dart';
import 'workspace_definition.dart';
import 'workspace_state.dart';

class OperationsHealth {
  const OperationsHealth({
    required this.score,
    required this.availability,
    required this.latencyMs,
    required this.errorRate,
    required this.throughput,
    required this.capacity,
    required this.trend,
    required this.activeAlerts,
  });

  final int score;
  final double availability;
  final int latencyMs;
  final double errorRate;
  final double throughput;
  final double capacity;
  final String trend;
  final List<String> activeAlerts;
}

class OperationsDefinition {
  const OperationsDefinition({
    required this.id,
    required this.type,
    required this.name,
    required this.health,
    required this.version,
    required this.region,
    required this.dependencies,
  });

  final String id;
  final WorkspaceEntityType type;
  final String name;
  final OperationsHealth health;
  final String version;
  final String region;
  final List<String> dependencies;
}

class OperationsEngine {
  static OperationsDefinition resolve(String id, {WorkspaceEntityType fallbackType = WorkspaceEntityType.service}) {
    final name = id.toUpperCase();
    return OperationsDefinition(
      id: id,
      type: id.contains('db') ? WorkspaceEntityType.database : fallbackType,
      name: name,
      health: OperationsHealth(
        score: id.contains('fail') ? 45 : 98,
        availability: id.contains('fail') ? 0.94 : 0.9999,
        latencyMs: id.contains('db') ? 8 : 45,
        errorRate: id.contains('fail') ? 0.08 : 0.001,
        throughput: 1240.0,
        capacity: 0.42,
        trend: 'STABLE',
        activeAlerts: id.contains('fail') ? ['Slow queries detected on secondary replica'] : [],
      ),
      version: 'v1.4.2',
      region: 'NG-LAGOS',
      dependencies: ['api-gateway', 'auth-service'],
    );
  }

  static void open(BuildContext context, WidgetRef ref, String id, {WorkspaceEntityType fallbackType = WorkspaceEntityType.service}) {
    final ops = resolve(id, fallbackType: fallbackType);
    if (ops.type == WorkspaceEntityType.incident) {
      context.go('/super-admin/incidents/${ops.id}');
    } else {
      context.go('/super-admin/services/${ops.id}');
    }
  }
}
