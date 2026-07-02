import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../eos/eos.dart';
import '../../../eos/layout/workspace/entity_engine.dart';
import '../../../eos/layout/workspace/operations_engine.dart';
import '../../../eos/layout/workspace/workspace_definition.dart';
import '../../../eos/layout/workspace/workspace_shell.dart';
import '../../../eos/layout/workspace/workspace_widgets.dart';

class Service360WorkspaceScreen extends ConsumerStatefulWidget {
  const Service360WorkspaceScreen({super.key, required this.serviceId});
  final String serviceId;

  @override
  ConsumerState<Service360WorkspaceScreen> createState() => _Service360WorkspaceScreenState();
}

class _Service360WorkspaceScreenState extends ConsumerState<Service360WorkspaceScreen> {
  late WorkspaceDefinition _serviceWorkspaceDefinition;

  @override
  void initState() {
    super.initState();
    _serviceWorkspaceDefinition = WorkspaceDefinition(
      entityType: WorkspaceEntityType.service,
      title: 'Service 360 Workspace',
      icon: Icons.settings_system_daydream,
      metrics: const [
        WorkspaceMetricDefinition(
          label: 'Requests per Sec',
          valueResolver: _resolveRps,
          subtitle: 'Active throughput proxy load',
        ),
      ],
      quickActions: [
        WorkspaceActionDefinition(
          label: 'Restart Service Container',
          icon: Icons.refresh,
          onPressed: (context, id) async {
            // Restart action
          },
        ),
      ],
      tabs: [
        WorkspaceTabDefinition(
          label: 'Overview',
          builder: (context, id) => _OverviewTabBridge(serviceId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Metrics',
          builder: (context, id) => _MetricsTabBridge(serviceId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Dependencies',
          builder: (context, id) => _DependenciesTabBridge(serviceId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Deployments',
          builder: (context, id) => _DeploymentsTabBridge(serviceId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Configuration',
          builder: (context, id) => _ConfigurationTabBridge(serviceId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Logs',
          builder: (context, id) => _LogsTabBridge(serviceId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Alerts',
          builder: (context, id) => _AlertsTabBridge(serviceId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Incidents',
          builder: (context, id) => _IncidentsTabBridge(serviceId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Timeline',
          builder: (context, id) => _TimelineTabBridge(serviceId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Audit',
          builder: (context, id) => _AuditTabBridge(serviceId: id),
        ),
      ],
    );
  }

  static String _resolveRps(Map<String, dynamic> d) {
    return '1240';
  }

  @override
  Widget build(BuildContext context) {
    final ops = OperationsEngine.resolve(widget.serviceId);

    return WorkspaceShell(
      definition: _serviceWorkspaceDefinition,
      entityId: widget.serviceId,
      name: ops.name,
      logoText: 'S',
      healthScore: ops.health.score,
      environment: 'Production',
      region: ops.region,
      primaryContact: 'oncall@owanbe.dev',
      createdDate: '2026-06-01',
      lastActivity: 'Healthy heartbeat received now',
      sidebarWidgets: [
        WorkspaceHealthPanel(
          healthScore: ops.health.score,
          factors: [
            'Availability: ${(ops.health.availability * 100).toStringAsFixed(2)}%',
            'Latency: ${ops.health.latencyMs}ms',
            'Trend: ${ops.health.trend}',
          ],
        ),
      ],
    );
  }
}

// ==================== SERVICE TAB BRIDGES ====================

class _OverviewTabBridge extends StatelessWidget {
  const _OverviewTabBridge({required this.serviceId});
  final String serviceId;

  @override
  Widget build(BuildContext context) {
    final ops = OperationsEngine.resolve(serviceId);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        EosSurfaceCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Platform Topology Relations', style: context.eosText.titleMedium),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  children: [
                    for (final dep in ops.dependencies)
                      Chip(label: Text(dep), avatar: const Icon(Icons.link)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricsTabBridge extends StatelessWidget {
  const _MetricsTabBridge({required this.serviceId});
  final String serviceId;

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Service health performance graphs.'));
  }
}

class _DependenciesTabBridge extends StatelessWidget {
  const _DependenciesTabBridge({required this.serviceId});
  final String serviceId;

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Direct dependency relationships mapped.'));
  }
}

class _DeploymentsTabBridge extends StatelessWidget {
  const _DeploymentsTabBridge({required this.serviceId});
  final String serviceId;

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Docker release sequences.'));
  }
}

class _ConfigurationTabBridge extends StatelessWidget {
  const _ConfigurationTabBridge({required this.serviceId});
  final String serviceId;

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Environment configuration keys.'));
  }
}

class _LogsTabBridge extends StatelessWidget {
  const _LogsTabBridge({required this.serviceId});
  final String serviceId;

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Observability standard stdout logs.'));
  }
}

class _AlertsTabBridge extends StatelessWidget {
  const _AlertsTabBridge({required this.serviceId});
  final String serviceId;

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Active warnings list.'));
  }
}

class _IncidentsTabBridge extends StatelessWidget {
  const _IncidentsTabBridge({required this.serviceId});
  final String serviceId;

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Active incidents list.'));
  }
}

class _TimelineTabBridge extends StatelessWidget {
  const _TimelineTabBridge({required this.serviceId});
  final String serviceId;

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Deployments and incidents timeline streams.'));
  }
}

class _AuditTabBridge extends StatelessWidget {
  const _AuditTabBridge({required this.serviceId});
  final String serviceId;

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Deployment audits history logs.'));
  }
}
