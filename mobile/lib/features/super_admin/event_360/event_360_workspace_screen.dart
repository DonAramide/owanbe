import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../eos/eos.dart';
import '../../../eos/layout/workspace/workspace_definition.dart';
import '../../../eos/layout/workspace/workspace_shell.dart';
import '../../../eos/layout/workspace/workspace_widgets.dart';

class Event360WorkspaceScreen extends ConsumerStatefulWidget {
  const Event360WorkspaceScreen({super.key, required this.eventId});
  final String eventId;

  @override
  ConsumerState<Event360WorkspaceScreen> createState() => _Event360WorkspaceScreenState();
}

class _Event360WorkspaceScreenState extends ConsumerState<Event360WorkspaceScreen> {
  late WorkspaceDefinition _eventWorkspaceDefinition;

  @override
  void initState() {
    super.initState();
    _eventWorkspaceDefinition = WorkspaceDefinition(
      entityType: WorkspaceEntityType.event,
      title: 'Event Operations 360',
      icon: Icons.event,
      metrics: const [
        WorkspaceMetricDefinition(
          label: 'Event Ticket Sales Conversion',
          valueResolver: _resolveConversion,
          subtitle: 'Active conversion standard',
        ),
      ],
      quickActions: [
        WorkspaceActionDefinition(
          label: 'Flag Event',
          icon: Icons.flag,
          onPressed: (context, id) async {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Event flagged for review.')),
            );
          },
        ),
      ],
      tabs: [
        WorkspaceTabDefinition(
          label: 'Overview',
          builder: (context, id) => _OverviewTabBridge(eventId: id),
        ),
      ],
    );
  }

  static String _resolveConversion(Map<String, dynamic> d) {
    return '84%';
  }

  @override
  Widget build(BuildContext context) {
    return WorkspaceShell(
      definition: _eventWorkspaceDefinition,
      entityId: widget.eventId,
      name: 'Owambe Staging Gala',
      logoText: 'E',
      healthScore: 94,
      environment: 'Production',
      region: 'NG-LAGOS',
      primaryContact: 'gala@alphaevents.owanbe',
      createdDate: '2026-06-01',
      lastActivity: 'Workspace synced 1m ago',
      sidebarWidgets: const [
        WorkspaceHealthPanel(
          healthScore: 94,
          factors: [
            'Ticket limits: NORMAL',
            'Guest checkins pipeline: Optimal',
          ],
        ),
      ],
    );
  }
}

class _OverviewTabBridge extends StatelessWidget {
  const _OverviewTabBridge({required this.eventId});
  final String eventId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        WorkspaceRelationshipGraph(currentType: WorkspaceEntityType.event, entityId: eventId),
        const SizedBox(height: 24),
        Text('Event Portfolio Overview', style: context.eosText.titleMedium),
        const SizedBox(height: 12),
        const Text('Active guest registrations, check-in operations telemetry, and venue configuration controls.'),
      ],
    );
  }
}
