import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../eos/eos.dart';
import '../../../../features/operations/models/operations_models.dart';
import '../../../../features/operations/widgets/operations_shared.dart';
import '../../models/program_constants.dart';
import '../../models/program_models.dart';
import '../../navigation/event_navigator.dart';
import '../../providers/program_providers.dart';
import '../../widgets/program/program_day_widget.dart';
import '../../widgets/program/program_status_badge.dart';
import '../../operations/event_operations_models.dart';
import '../../operations/event_operations_workspace_provider.dart';
import '../../operations/operations_command_navigation.dart';
import '../../planning/event_planning_models.dart';
import '../../planning/planning_module_navigation.dart';

/// Event Day / Live Operations Center — mission control for execution phase (Phase 4).
class EventOperationsCenter extends ConsumerStatefulWidget {
  const EventOperationsCenter({
    super.key,
    required this.eventId,
    required this.fallbackMode,
  });

  final String eventId;
  final EventDesktopMode fallbackMode;

  @override
  ConsumerState<EventOperationsCenter> createState() => _EventOperationsCenterState();
}

class _EventOperationsCenterState extends ConsumerState<EventOperationsCenter> {
  var _savingProgram = false;

  Future<void> _setProgramStatus(ProgramItem item, String status) async {
    if (_savingProgram) return;
    setState(() => _savingProgram = true);
    try {
      await ref.read(programApiProvider).setStatus(
            widget.eventId,
            item.id,
            status: status,
          );
      refreshProgram(ref);
      ref.invalidate(eventOperationsWorkspaceProvider(widget.eventId));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update program activity')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingProgram = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ops = ref.watch(eventOperationsWorkspaceProvider(widget.eventId));

    return ops.when(
      loading: () => const Center(child: Padding(
        padding: EdgeInsets.all(24),
        child: CircularProgressIndicator(),
      )),
      error: (_, __) => Text('Operations data unavailable', style: context.eosText.bodyMedium),
      data: (data) => _OperationsBody(
        eventId: widget.eventId,
        workspace: data,
        savingProgram: _savingProgram,
        onProgramStatus: _setProgramStatus,
      ),
    );
  }
}

class _OperationsBody extends StatelessWidget {
  const _OperationsBody({
    required this.eventId,
    required this.workspace,
    required this.savingProgram,
    required this.onProgramStatus,
  });

  final String eventId;
  final EventOperationsWorkspace workspace;
  final bool savingProgram;
  final void Function(ProgramItem item, String status) onProgramStatus;

  @override
  Widget build(BuildContext context) {
    final isLive = workspace.lifecycleStage == EventLifecycleStage.liveEvent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (isLive) const EosLiveIndicator(compact: true, label: 'LIVE'),
            if (isLive) SizedBox(width: context.eos.spacing.sm),
            Expanded(
              child: Text('Event Operations Center', style: context.eosText.titleLarge),
            ),
          ],
        ),
        SizedBox(height: context.eos.spacing.xs),
        Text(
          workspace.lifecycleStage.label,
          style: context.eosText.bodyMedium?.copyWith(color: EosColors.slate500),
        ),
        SizedBox(height: context.eos.spacing.md),
        _OperationalHealthCard(workspace: workspace),
        SizedBox(height: context.eos.spacing.md),
        Text('Command actions', style: context.eosText.titleSmall),
        SizedBox(height: context.eos.spacing.sm),
        Wrap(
          spacing: context.eos.spacing.sm,
          runSpacing: context.eos.spacing.sm,
          children: OperationsCommandAction.values.map((action) {
            return FilledButton.tonalIcon(
              onPressed: () => executeOperationsCommand(context, eventId, action),
              icon: Icon(iconForOperationsCommand(action), size: 18),
              label: Text(action.label),
            );
          }).toList(),
        ),
        SizedBox(height: context.eos.spacing.lg),
        Text('Live timeline', style: context.eosText.titleMedium),
        SizedBox(height: context.eos.spacing.sm),
        ProgramDayWidget(
          day: workspace.timeline.day,
          onOpenProgram: () => context.eventNav.openProgram(eventId),
        ),
        if (workspace.timeline.current != null) ...[
          SizedBox(height: context.eos.spacing.sm),
          _ProgramControls(
            item: workspace.timeline.current!,
            busy: savingProgram,
            onStatus: onProgramStatus,
          ),
        ],
        if (workspace.timeline.delayed.isNotEmpty) ...[
          SizedBox(height: context.eos.spacing.sm),
          Text('Delayed', style: context.eosText.labelSmall),
          for (final item in workspace.timeline.delayed.take(3))
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(item.title, style: context.eosText.bodyMedium),
              trailing: ProgramStatusBadge(status: item.status),
              onTap: () => context.eventNav.openProgram(eventId),
            ),
        ],
        SizedBox(height: context.eos.spacing.lg),
        Text('Live operations', style: context.eosText.titleMedium),
        SizedBox(height: context.eos.spacing.sm),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 560;
            final cards = [
              _OpsStatusCard(
                title: 'Guests',
                lines: [
                  'Checked in: ${workspace.guestOps.checkedIn}',
                  'Pending: ${workspace.guestOps.pending}',
                  'VIP arrived: ${workspace.guestOps.vipArrived}',
                  'Capacity: ${workspace.guestOps.capacity}',
                ],
                onTap: () => openPlanningModuleLink(
                  context,
                  eventId,
                  PlanningModuleLink.guests,
                  event: null,
                ),
              ),
              _OpsStatusCard(
                title: 'Vendors',
                lines: [
                  'Expected: ${workspace.vendorOps.expected}',
                  'Arrived: ${workspace.vendorOps.arrived}',
                  'Working: ${workspace.vendorOps.working}',
                  'Completed: ${workspace.vendorOps.completed}',
                ],
                onTap: () => openPlanningModuleLink(
                  context,
                  eventId,
                  PlanningModuleLink.vendors,
                  event: null,
                ),
              ),
            ];
            if (wide) {
              return Row(
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    if (i > 0) SizedBox(width: context.eos.spacing.sm),
                    Expanded(child: cards[i]),
                  ],
                ],
              );
            }
            return Column(
              children: [
                for (final card in cards) ...[card, SizedBox(height: context.eos.spacing.sm)],
              ],
            );
          },
        ),
        SizedBox(height: context.eos.spacing.lg),
        Row(
          children: [
            Expanded(child: Text('Command feed', style: context.eosText.titleMedium)),
            TextButton(
              onPressed: () => context.eventNav.openOpsFeed(eventId),
              child: const Text('View all'),
            ),
          ],
        ),
        SizedBox(height: context.eos.spacing.sm),
        if (workspace.commandFeed.isEmpty)
          EosSurfaceCard(
            child: Text('Waiting for live activity…', style: context.eosText.bodyMedium),
          )
        else
          for (final item in workspace.commandFeed.take(6))
            Padding(
              padding: EdgeInsets.only(bottom: context.eos.spacing.xs),
              child: EosSurfaceCard(
                child: ListTile(
                  dense: true,
                  leading: Icon(feedIcon(item.type), color: EosColors.plum, size: 20),
                  title: Text(item.headline, style: context.eosText.bodyMedium),
                  subtitle: Text(item.detail, style: context.eosText.bodySmall),
                ),
              ),
            ),
        SizedBox(height: context.eos.spacing.md),
        OutlinedButton.icon(
          onPressed: () => context.eventNav.openEventDay(eventId),
          icon: const Icon(Icons.hub_outlined),
          label: const Text('Open full Event Day hub'),
        ),
      ],
    );
  }
}

class _OperationalHealthCard extends StatelessWidget {
  const _OperationalHealthCard({required this.workspace});

  final EventOperationsWorkspace workspace;

  @override
  Widget build(BuildContext context) {
    final levelColor = switch (workspace.healthLevel) {
      EventHealthLevel.healthy => EosColors.success,
      EventHealthLevel.warning => EosColors.warning,
      EventHealthLevel.critical => EosColors.critical,
    };

    return EosSurfaceCard(
      elevated: true,
      child: Padding(
        padding: EdgeInsets.all(context.eos.spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.monitor_heart_outlined, color: levelColor),
                SizedBox(width: context.eos.spacing.sm),
                Text('Operational health', style: context.eosText.titleSmall),
              ],
            ),
            SizedBox(height: context.eos.spacing.sm),
            Text(
              '${workspace.operationalHealthScore}%',
              style: context.eosText.headlineMedium?.copyWith(color: EosColors.plum),
            ),
            Text(workspace.healthSummary, style: context.eosText.bodySmall),
            SizedBox(height: context.eos.spacing.sm),
            for (final dim in workspace.healthDimensions.take(4))
              Padding(
                padding: EdgeInsets.only(bottom: context.eos.spacing.xxs),
                child: Row(
                  children: [
                    Expanded(child: Text(dim.label, style: context.eosText.labelSmall)),
                    Text('${dim.score}%', style: context.eosText.labelSmall),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProgramControls extends StatelessWidget {
  const _ProgramControls({
    required this.item,
    required this.busy,
    required this.onStatus,
  });

  final ProgramItem item;
  final bool busy;
  final void Function(ProgramItem item, String status) onStatus;

  @override
  Widget build(BuildContext context) {
    return EosSurfaceCard(
      child: Padding(
        padding: EdgeInsets.all(context.eos.spacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Control: ${item.title}', style: context.eosText.titleSmall),
            SizedBox(height: context.eos.spacing.sm),
            Wrap(
              spacing: context.eos.spacing.xs,
              runSpacing: context.eos.spacing.xs,
              children: [
                _ProgramActionButton(
                  label: 'Start',
                  enabled: !busy,
                  onPressed: () => onStatus(item, 'in_progress'),
                ),
                _ProgramActionButton(
                  label: 'Pause',
                  enabled: !busy,
                  onPressed: () => onStatus(item, 'ready'),
                ),
                _ProgramActionButton(
                  label: 'Resume',
                  enabled: !busy,
                  onPressed: () => onStatus(item, 'in_progress'),
                ),
                _ProgramActionButton(
                  label: 'Complete',
                  enabled: !busy,
                  onPressed: () => onStatus(item, 'completed'),
                ),
                _ProgramActionButton(
                  label: 'Skip',
                  enabled: !busy,
                  onPressed: () => onStatus(item, 'skipped'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgramActionButton extends StatelessWidget {
  const _ProgramActionButton({
    required this.label,
    required this.onPressed,
    required this.enabled,
  });

  final String label;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: enabled ? onPressed : null,
      child: Text(label),
    );
  }
}

class _OpsStatusCard extends StatelessWidget {
  const _OpsStatusCard({
    required this.title,
    required this.lines,
    required this.onTap,
  });

  final String title;
  final List<String> lines;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return EosSurfaceCard(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.all(context.eos.spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: context.eosText.titleSmall)),
                const Icon(Icons.chevron_right, size: 18),
              ],
            ),
            for (final line in lines)
              Text(line, style: context.eosText.bodySmall),
          ],
        ),
      ),
    );
  }
}
