import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../features/organizer/command_center_v3/tabs/analytics_tab_v3.dart';
import '../../../features/organizer/command_center_v3/tabs/finance_tab_v3.dart';
import '../../../features/organizer/command_center_v3/tabs/reports_tab_v3.dart';
import '../../../features/organizer/command_center_v3/tabs/tickets_tab_v3.dart';
import '../../../features/organizer/command_center_v3/tabs/vendors_tab_v3.dart';
import '../../../eos/eos.dart';
import '../../../eos/layout/workspace/workspace_definition.dart';
import '../../../eos/layout/workspace/workspace_shell.dart';
import '../../../eos/layout/workspace/workspace_widgets.dart';
import '../navigation/event_navigator.dart';
import '../providers/customer_event_command_providers.dart';
import 'widgets/event_desktop.dart';
import 'widgets/event_error_view.dart';
import 'widgets/event_loading_skeleton.dart';

class EventWorkspace extends ConsumerStatefulWidget {
  const EventWorkspace({super.key, required this.eventId});
  final String eventId;

  @override
  ConsumerState<EventWorkspace> createState() => _EventWorkspaceState();
}

class _EventWorkspaceState extends ConsumerState<EventWorkspace> {
  late WorkspaceDefinition _eventWorkspaceDefinition;

  @override
  void initState() {
    super.initState();
    _eventWorkspaceDefinition = WorkspaceDefinition(
      entityType: WorkspaceEntityType.event,
      title: 'Event Command Center',
      icon: Icons.event,
      metrics: const [
        WorkspaceMetricDefinition(
          label: 'Total Revenue',
          valueResolver: _resolveRevenue,
          subtitle: 'Gross ticket earnings',
        ),
      ],
      quickActions: [
        WorkspaceActionDefinition(
          label: 'Create Ticket',
          icon: Icons.confirmation_number_outlined,
          onPressed: (context, id) async => EventNavigator(context).openTicketsManage(id),
        ),
        WorkspaceActionDefinition(
          label: 'Manage Tickets',
          icon: Icons.edit_note_outlined,
          onPressed: (context, id) async => EventNavigator(context).openTicketsManage(id),
        ),
        WorkspaceActionDefinition(
          label: 'View Sales',
          icon: Icons.insights_outlined,
          onPressed: (context, id) async => EventNavigator(context).openTicketsManage(id),
        ),
      ],
      tabs: [
        WorkspaceTabDefinition(
          label: 'Overview',
          builder: (context, id) => _EventDesktopBridge(eventId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Tickets & Commerce',
          builder: (context, id) => _CommerceTabBridge(eventId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Attendees',
          builder: (context, id) => _AttendeesTabBridge(eventId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Vendors',
          builder: (context, id) => VendorsTabV3(eventId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Finance',
          builder: (context, id) => FinanceTabV3(eventId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Operations',
          builder: (context, id) => _OperationsTabBridge(eventId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Analytics',
          builder: (context, id) => AnalyticsTabV3(eventId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Reports',
          builder: (context, id) => ReportsTabV3(eventId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Timeline',
          builder: (context, id) => _TimelineTabBridge(eventId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Audit',
          builder: (context, id) => _AuditTabBridge(eventId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Settings',
          builder: (context, id) => _SettingsTabBridge(eventId: id),
        ),
      ],
    );
  }

  static String _resolveRevenue(Map<String, dynamic> d) {
    final event = d['event'] as Map<String, dynamic>? ?? {};
    return event['revenueMinor']?.toString() ?? '0';
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(customerEventCommandProvider(widget.eventId));

    return snapshot.when(
      loading: () => const EventLoadingSkeleton(variant: EventLoadingVariant.workspace),
      error: (_, _) => Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            EventErrorView.workspace(
              onRetry: () {
                ref.invalidate(customerEventCommandProvider(widget.eventId));
              },
              onBackToEvents: () => context.pop(),
            ),
          ],
        ),
      ),
      data: (data) {
        final event = data.event;
        final name = event.title;

        // Health Index based on tasks completed vs tasks remaining
        int healthScore = 100;
        if (data.tasksRemaining > 0) {
          final totalTasks = data.tasksCompleted + data.tasksRemaining;
          healthScore = ((data.tasksCompleted / totalTasks) * 100).round();
        }

        return WorkspaceShell(
          definition: _eventWorkspaceDefinition,
          entityId: widget.eventId,
          name: name,
          logoText: name.isNotEmpty ? name[0].toUpperCase() : 'E',
          healthScore: healthScore,
          environment: 'Production',
          region: 'NG-LAGOS',
          primaryContact: 'organizer@owanbe.dev',
          createdDate: '2026-06-01',
          lastActivity: 'Updated 5 minutes ago',
          sidebarWidgets: [
            WorkspaceHealthPanel(
              healthScore: healthScore,
              factors: [
                '${data.tasksCompleted} planning tasks completed',
                '${data.tasksRemaining} tasks outstanding',
                '${data.guestRsvp} total guest RSVPs accepted',
              ],
            ),
          ],
        );
      },
    );
  }
}

// ==================== EVENT DESKTOP (Phase 1) ====================

class _EventDesktopBridge extends ConsumerWidget {
  const _EventDesktopBridge({required this.eventId});
  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(customerEventCommandProvider(eventId));

    return snapshot.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (data) => EventDesktop(eventId: eventId, snapshot: data),
    );
  }
}

// ==================== LEGACY TAB BRIDGES (monitoring — secondary tabs) ====================

class _CommerceTabBridge extends ConsumerWidget {
  const _CommerceTabBridge({required this.eventId});
  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TicketsTabV3(eventId: eventId);
  }
}

class _AttendeesTabBridge extends ConsumerWidget {
  const _AttendeesTabBridge({required this.eventId});
  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(customerEventCommandProvider(eventId));

    return snapshot.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error: $e'),
      data: (data) {
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Check-ins & RSVPs', style: context.eosText.titleMedium),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('RSVP Registrations'),
              trailing: Text('${data.guestRsvp}'),
            ),
            ListTile(
              title: const Text('Checked-in Guests'),
              trailing: Text('${data.guestCheckedIn}'),
            ),
          ],
        );
      },
    );
  }
}

class _OperationsTabBridge extends ConsumerWidget {
  const _OperationsTabBridge({required this.eventId});
  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Operational Incidents', style: context.eosText.titleMedium),
        const SizedBox(height: 16),
        const ListTile(
          title: Text('No active incidents reported.'),
          trailing: Icon(Icons.check_circle_outline, color: Colors.green),
        ),
      ],
    );
  }
}

class _TimelineTabBridge extends ConsumerWidget {
  const _TimelineTabBridge({required this.eventId});
  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(customerEventCommandProvider(eventId));

    return snapshot.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error: $e'),
      data: (data) {
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Lifecycle Timeline', style: context.eosText.titleMedium),
            const SizedBox(height: 16),
            WorkspaceTimeline(
              items: [
                WorkspaceTimelineItem(
                  title: 'Event Created',
                  description: 'Draft workspace initiated.',
                  timestamp: '3d ago',
                  category: 'operations',
                  icon: Icons.create,
                  iconColor: Colors.blue,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _AuditTabBridge extends ConsumerWidget {
  const _AuditTabBridge({required this.eventId});
  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Platform Audit History', style: context.eosText.titleMedium),
        const SizedBox(height: 16),
        const ListTile(
          title: Text('No system configuration audits recorded.'),
        ),
      ],
    );
  }
}

class _SettingsTabBridge extends ConsumerWidget {
  const _SettingsTabBridge({required this.eventId});
  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Branding & Visibility Policies', style: context.eosText.titleMedium),
        const SizedBox(height: 16),
        const ListTile(
          title: Text('Search Visibility: PUBLIC'),
        ),
      ],
    );
  }
}
