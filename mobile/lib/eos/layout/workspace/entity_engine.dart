import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'analytics_engine.dart';
import '../../security/security_engine.dart';

import 'commerce_engine.dart';
import 'workspace_definition.dart';
import 'workspace_state.dart';

class EntityRelation {
  const EntityRelation({
    required this.targetId,
    required this.type,
    required this.label,
    required this.icon,
  });

  final String targetId;
  final WorkspaceEntityType type;
  final String label;
  final IconData icon;
}

class EntityDefinition {
  const EntityDefinition({
    required this.id,
    required this.type,
    required this.name,
    required this.logoText,
    required this.status,
    required this.healthScore,
    required this.environment,
    required this.region,
    required this.primaryContact,
    required this.createdDate,
    required this.lastActivity,
    required this.relations,
    required this.factors,
    required this.insights,
  });

  final String id;
  final WorkspaceEntityType type;
  final String name;
  final String logoText;
  final String status;
  final int healthScore;
  final String environment;
  final String region;
  final String primaryContact;
  final String createdDate;
  final String lastActivity;
  final List<EntityRelation> relations;
  final List<String> factors;
  final List<String> insights;
}

class EntityEngine {
  static EntityDefinition resolve(String entityId, {WorkspaceEntityType fallbackType = WorkspaceEntityType.tenant}) {
    if (entityId == 'commerce_global' || fallbackType == WorkspaceEntityType.commerce) {
      return CommerceEngine.resolveCommerceEntity();
    }
    if (entityId == 'analytics_global' || fallbackType == WorkspaceEntityType.analytics) {
      return AnalyticsEngine.resolveAnalyticsEntity();
    }
    if (entityId == 'security_global' || fallbackType == WorkspaceEntityType.security) {
      return SecurityEngine.resolveSecurityEntity();
    }

    WorkspaceEntityType type;
    if (entityId.startsWith('usr_') || entityId.startsWith('user_') || fallbackType == WorkspaceEntityType.user || fallbackType == WorkspaceEntityType.attendee) {
      type = WorkspaceEntityType.user;
    } else if (entityId.startsWith('inc_') || fallbackType == WorkspaceEntityType.incident) {
      type = WorkspaceEntityType.incident;
    } else if (entityId.startsWith('evt_') || entityId.startsWith('event_') || fallbackType == WorkspaceEntityType.event) {
      type = WorkspaceEntityType.event;
    } else if (entityId.startsWith('org_') || fallbackType == WorkspaceEntityType.organizer) {
      type = WorkspaceEntityType.organizer;
    } else {
      type = fallbackType;
    }

    final String name = type == WorkspaceEntityType.event
        ? 'Owambe Staging Gala'
        : (type == WorkspaceEntityType.organizer
            ? 'Alpha Event Group'
            : (type == WorkspaceEntityType.user
                ? 'Adenike Adebayo'
                : (type == WorkspaceEntityType.incident
                    ? 'INC-891: DB Replication Latency'
                    : 'Gate Tenant Enterprise')));

    return EntityDefinition(
      id: entityId,
      type: type,
      name: name,
      logoText: name.isNotEmpty ? name[0].toUpperCase() : 'O',
      status: 'active',
      healthScore: type == WorkspaceEntityType.event ? 94 : (type == WorkspaceEntityType.incident ? 45 : 88),
      environment: 'Production',
      region: 'NG-LAGOS',
      primaryContact: type == WorkspaceEntityType.user ? 'adenike@owanbe.dev' : 'contact@owanbe.dev',
      createdDate: '2026-06-01',
      lastActivity: 'Active 4m ago',
      relations: [
        EntityRelation(targetId: 'tenant_1', type: WorkspaceEntityType.tenant, label: 'Tenant Owner', icon: Icons.corporate_fare),
        EntityRelation(targetId: 'usr_1', type: WorkspaceEntityType.user, label: 'Lead User', icon: Icons.person),
        EntityRelation(targetId: 'evt_1', type: WorkspaceEntityType.event, label: 'Active Event', icon: Icons.event),
        EntityRelation(targetId: 'inc_sec_109', type: WorkspaceEntityType.incident, label: 'MFA Configuration Drift', icon: Icons.warning),
      ],
      factors: [
        'Operations are stable',
        'No open reconciliation discrepancies',
        'All platform guidelines verified',
      ],
      insights: [
        'Engagement index increased 12% WoW.',
        'Zero security infractions logged in last 30d.',
      ],
    );
  }

  static void open(BuildContext context, WidgetRef ref, String entityId, {WorkspaceEntityType fallbackType = WorkspaceEntityType.tenant}) {
    final entity = resolve(entityId, fallbackType: fallbackType);

    // Dynamic Routing Decision
    if (entity.type == WorkspaceEntityType.tenant) {
      ref.read(contextDrawerProvider.notifier).clear();
      context.go('/super-admin/tenants/${entity.id}');
    } else if (entity.type == WorkspaceEntityType.commerce) {
      ref.read(contextDrawerProvider.notifier).clear();
      context.go('/super-admin/commerce/${entity.id}');
    } else if (entity.type == WorkspaceEntityType.analytics) {
      ref.read(contextDrawerProvider.notifier).clear();
      context.go('/super-admin/analytics/${entity.id}');
    } else if (entity.type == WorkspaceEntityType.security) {
      ref.read(contextDrawerProvider.notifier).clear();
      context.go('/super-admin/security/${entity.id}');
    } else if (entity.type == WorkspaceEntityType.user) {
      ref.read(contextDrawerProvider.notifier).clear();
      context.go('/super-admin/users/${entity.id}');
    } else if (entity.type == WorkspaceEntityType.incident) {
      ref.read(contextDrawerProvider.notifier).clear();
      context.go('/super-admin/incidents/${entity.id}');
    } else {
      // Open in Global Context Drawer to preserve workspace context
      ref.read(contextDrawerProvider.notifier).push(
            '${entity.type.name.toUpperCase()}: ${entity.name}',
            _buildDrawerContent(context, ref, entity),
          );
  }
  }

  static Widget _buildDrawerContent(BuildContext context, WidgetRef ref, EntityDefinition entity) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(entity.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('ID: ${entity.id}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
          const Divider(height: 32),
          Text('Health Score: ${entity.healthScore}%', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text('Status: ${entity.status.toUpperCase()}', style: const TextStyle(color: Colors.green)),
          const SizedBox(height: 24),
          const Text('AI Insights:', style: TextStyle(fontWeight: FontWeight.bold)),
          for (final insight in entity.insights)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline, size: 14, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(child: Text(insight, style: const TextStyle(fontSize: 12))),
                ],
              ),
            ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    // Open deeper nested explorer or target
                  },
                  child: const Text('Focus View'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
