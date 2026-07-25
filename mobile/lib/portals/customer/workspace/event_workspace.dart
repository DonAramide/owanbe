import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/money.dart';
import '../../../eos/eos.dart';
import '../../../eos/layout/workspace/workspace_definition.dart';
import '../../../eos/layout/workspace/workspace_shell.dart';
import '../../../eos/layout/workspace/workspace_widgets.dart';
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
          label: 'Publish Event',
          icon: Icons.publish,
          onPressed: (context, id) async {
            // Simulated actions
          },
        ),
        WorkspaceActionDefinition(
          label: 'Go Live Operations',
          icon: Icons.play_arrow,
          onPressed: (context, id) async {
            // Simulated actions
          },
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
          builder: (context, id) => _VendorsTabBridge(eventId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Finance',
          builder: (context, id) => _FinanceTabBridge(eventId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Operations',
          builder: (context, id) => _OperationsTabBridge(eventId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Analytics',
          builder: (context, id) => _AnalyticsTabBridge(eventId: id),
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
      error: (_, __) => Scaffold(
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
    final snapshot = ref.watch(customerEventCommandProvider(eventId));

    return snapshot.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error: $e'),
      data: (data) {
        final event = data.event;
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Commerce Conversion Funnel', style: context.eosText.titleMedium),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Direct Ticket Commerce'),
              subtitle: Text('${event.ticketsSold} passes registered across active tiers.'),
              trailing: const Icon(Icons.monetization_on_outlined),
            ),
          ],
        );
      },
    );
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

class _VendorsTabBridge extends ConsumerWidget {
  const _VendorsTabBridge({required this.eventId});
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
            Text('Partner Service Hires', style: context.eosText.titleMedium),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Requested Vendors'),
              trailing: Text('${data.vendorRequested}'),
            ),
            ListTile(
              title: const Text('Accepted Hires'),
              trailing: Text('${data.vendorAccepted}'),
            ),
          ],
        );
      },
    );
  }
}

class _FinanceTabBridge extends ConsumerWidget {
  const _FinanceTabBridge({required this.eventId});
  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(customerEventCommandProvider(eventId));

    return snapshot.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error: $e'),
      data: (data) {
        final event = data.event;
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Event Wallet & Budget Splits', style: context.eosText.titleMedium),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Escrow Release Total'),
              trailing: Text(formatRevenue(event.revenueMinor)),
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

class _AnalyticsTabBridge extends ConsumerWidget {
  const _AnalyticsTabBridge({required this.eventId});
  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(customerEventCommandProvider(eventId));

    return snapshot.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error: $e'),
      data: (data) {
        final event = data.event;
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Traffic & Channel Conversion', style: context.eosText.titleMedium),
            const SizedBox(height: 16),
            SizedBox(
              height: 280,
              child: EosTimeSeriesChart(
                series: [
                  EosTimeSeriesSeries(
                    key: 'sales',
                    label: 'Sales Volume',
                    color: context.eosColors.primary,
                  ),
                ],
                points: [
                  const EosTimeSeriesPoint(label: '30d ago', values: {'sales': 12000000}),
                  const EosTimeSeriesPoint(label: '20d ago', values: {'sales': 28000000}),
                  const EosTimeSeriesPoint(label: '10d ago', values: {'sales': 19000000}),
                  EosTimeSeriesPoint(label: 'Now', values: {'sales': event.revenueMinor.toDouble()}),
                ],
              ),
            ),
          ],
        );
      },
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
