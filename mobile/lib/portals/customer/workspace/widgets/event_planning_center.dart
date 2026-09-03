import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/money.dart';
import '../../../../eos/eos.dart';
import '../../../../core/providers/silent_refresh.dart';
import '../../models/ai_planner_models.dart';
import '../../models/command_center_models.dart';
import '../../models/customer_event_models.dart';
import '../../planning/event_planning_models.dart';
import '../../planning/event_planning_workspace_provider.dart';
import '../../planning/planning_module_navigation.dart';
import '../../widgets/command_center/planning_progress_ring.dart';

/// Planning Center — the event operating office (Phase 3).
///
/// Aggregates existing modules; every action deep-links to production routes.
class EventPlanningCenter extends ConsumerWidget {
  const EventPlanningCenter({
    super.key,
    required this.eventId,
    required this.fallbackSnapshot,
  });

  final String eventId;
  final EventCommandCenterSnapshot fallbackSnapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(eventPlanningWorkspaceProvider(eventId));

    return workspace.whenStable(
      loading: () => _PlanningCenterBody(
        eventId: eventId,
        snapshot: fallbackSnapshot,
        lifecycleStage: deriveEventLifecycleStage(
          event: fallbackSnapshot.event,
          snapshot: fallbackSnapshot,
          crm: null,
          guests: const [],
        ),
        readinessScore: (fallbackSnapshot.progress * 100).round(),
        readinessDimensions: const [],
        checklist: const [],
        outstandingTasks: fallbackSnapshot.tasks.where((t) => !t.done).toList(),
        timeline: const [],
        aiRecommendations: const [],
        nextActionLabel: null,
        nextActionLink: null,
        vendorStatus: buildVendorStatusSummary(null, fallbackSnapshot.event),
        guestStatus: const EventGuestStatusSummary(
          invited: 0,
          accepted: 0,
          pending: 0,
          declined: 0,
          checkedIn: 0,
        ),
        ticketStatus: buildTicketStatusSummary(fallbackSnapshot.event),
        financeStatus: buildFinanceStatusSummary(snapshot: fallbackSnapshot),
        inProgressCount: fallbackSnapshot.tasksRemaining,
        loading: true,
      ),
      error: (_, __) => _PlanningCenterBody(
        eventId: eventId,
        snapshot: fallbackSnapshot,
        lifecycleStage: deriveEventLifecycleStage(
          event: fallbackSnapshot.event,
          snapshot: fallbackSnapshot,
          crm: null,
          guests: const [],
        ),
        readinessScore: (fallbackSnapshot.progress * 100).round(),
        readinessDimensions: const [],
        checklist: const [],
        outstandingTasks: fallbackSnapshot.tasks.where((t) => !t.done).toList(),
        timeline: const [],
        aiRecommendations: const [],
        nextActionLabel: null,
        nextActionLink: null,
        vendorStatus: buildVendorStatusSummary(null, fallbackSnapshot.event),
        guestStatus: EventGuestStatusSummary(
          invited: fallbackSnapshot.guestInvited,
          accepted: fallbackSnapshot.guestRsvp,
          pending: 0,
          declined: 0,
          checkedIn: fallbackSnapshot.guestCheckedIn,
        ),
        ticketStatus: buildTicketStatusSummary(fallbackSnapshot.event),
        financeStatus: buildFinanceStatusSummary(snapshot: fallbackSnapshot),
        inProgressCount: fallbackSnapshot.tasksRemaining,
        loading: false,
      ),
      data: (data) => _PlanningCenterBody(
        eventId: eventId,
        snapshot: data.snapshot,
        lifecycleStage: data.lifecycleStage,
        readinessScore: data.readinessScore,
        readinessDimensions: data.readinessDimensions,
        checklist: data.checklist,
        outstandingTasks: data.outstandingTasks,
        timeline: data.timeline,
        aiRecommendations: data.aiRecommendations,
        nextActionLabel: data.nextActionLabel,
        nextActionLink: data.nextActionLink,
        vendorStatus: data.vendorStatus,
        guestStatus: data.guestStatus,
        ticketStatus: data.ticketStatus,
        financeStatus: data.financeStatus,
        inProgressCount: data.inProgressCount,
        loading: false,
      ),
    );
  }
}

class _PlanningCenterBody extends StatelessWidget {
  const _PlanningCenterBody({
    required this.eventId,
    required this.snapshot,
    required this.lifecycleStage,
    required this.readinessScore,
    required this.readinessDimensions,
    required this.checklist,
    required this.outstandingTasks,
    required this.timeline,
    required this.aiRecommendations,
    required this.nextActionLabel,
    required this.nextActionLink,
    required this.vendorStatus,
    required this.guestStatus,
    required this.ticketStatus,
    required this.financeStatus,
    required this.inProgressCount,
    required this.loading,
  });

  final String eventId;
  final EventCommandCenterSnapshot snapshot;
  final EventLifecycleStage lifecycleStage;
  final int readinessScore;
  final List<EventReadinessDimension> readinessDimensions;
  final List<EventChecklistEntry> checklist;
  final List<PlanningTaskItem> outstandingTasks;
  final List<PlannerTimelineItem> timeline;
  final List<PlannerMissingRequirement> aiRecommendations;
  final String? nextActionLabel;
  final PlanningModuleLink? nextActionLink;
  final EventVendorStatusSummary vendorStatus;
  final EventGuestStatusSummary guestStatus;
  final EventTicketStatusSummary ticketStatus;
  final EventFinanceStatusSummary financeStatus;
  final int inProgressCount;
  final bool loading;

  CustomerEvent get event => snapshot.event;

  void _open(BuildContext context, PlanningModuleLink link, {String? marketplaceCategory}) {
    openPlanningModuleLink(
      context,
      eventId,
      link,
      event: event,
      marketplaceCategory: marketplaceCategory,
    );
  }

  @override
  Widget build(BuildContext context) {
    final outstandingChecklist = checklist.where((c) => !c.done).take(6).toList();
    final completedChecklist = checklist.where((c) => c.done).take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LifecycleBanner(stage: lifecycleStage),
        SizedBox(height: context.eos.spacing.md),
        _ThreeQuestionsHeader(
          outstanding: outstandingTasks.length + outstandingChecklist.length,
          inProgress: inProgressCount,
          nextAction: nextActionLabel,
        ),
        if (nextActionLabel != null && nextActionLink != null) ...[
          SizedBox(height: context.eos.spacing.sm),
          FilledButton.icon(
            onPressed: () => _open(
              context,
              nextActionLink!,
              marketplaceCategory: marketplaceCategoryForChecklistLabel(nextActionLabel!),
            ),
            icon: const Icon(Icons.play_arrow_outlined, size: 18),
            label: Text('Do next: $nextActionLabel'),
          ),
        ],
        SizedBox(height: context.eos.spacing.lg),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: PlanningProgressRing(
                progress: snapshot.progress,
                tasksCompleted: snapshot.tasksCompleted,
                tasksRemaining: snapshot.tasksRemaining,
                tasks: snapshot.tasks,
              ),
            ),
            SizedBox(width: context.eos.spacing.md),
            Expanded(
              child: _ReadinessCard(
                score: readinessScore,
                dimensions: readinessDimensions,
                onDimensionTap: (link) => _open(context, link),
              ),
            ),
          ],
        ),
        SizedBox(height: context.eos.spacing.lg),
        Text('Smart checklist', style: context.eosText.titleMedium),
        SizedBox(height: context.eos.spacing.xs),
        Text(
          'Derived from your event data — tap any item to open the responsible module.',
          style: context.eosText.bodySmall?.copyWith(color: EosColors.slate500),
        ),
        SizedBox(height: context.eos.spacing.sm),
        if (loading)
          const LinearProgressIndicator()
        else if (outstandingChecklist.isEmpty && completedChecklist.isEmpty)
          EosSurfaceCard(
            child: Text('Your checklist will populate as you plan.', style: context.eosText.bodyMedium),
          )
        else ...[
          for (final item in outstandingChecklist)
            _ChecklistTile(
              label: item.label,
              done: item.done,
              onTap: item.moduleLink == null
                  ? null
                  : () => _open(
                        context,
                        item.moduleLink!,
                        marketplaceCategory: item.marketplaceCategory,
                      ),
            ),
          for (final item in completedChecklist)
            _ChecklistTile(
              label: item.label,
              done: true,
              onTap: item.moduleLink == null
                  ? null
                  : () => _open(
                        context,
                        item.moduleLink!,
                        marketplaceCategory: item.marketplaceCategory,
                      ),
            ),
        ],
        if (timeline.isNotEmpty) ...[
          SizedBox(height: context.eos.spacing.lg),
          Text('Upcoming milestones', style: context.eosText.titleMedium),
          SizedBox(height: context.eos.spacing.sm),
          for (final item in timeline)
            _TimelineTile(
              item: item,
              onTap: () => _open(context, PlanningModuleLink.program),
            ),
        ],
        if (outstandingTasks.isNotEmpty) ...[
          SizedBox(height: context.eos.spacing.lg),
          Text('Outstanding tasks', style: context.eosText.titleMedium),
          SizedBox(height: context.eos.spacing.sm),
          for (final task in outstandingTasks)
            _TaskTile(
              label: task.label,
              onTap: () {
                final link = moduleLinkForPlanningTask(task.label);
                if (link != null) _open(context, link);
              },
            ),
        ],
        SizedBox(height: context.eos.spacing.lg),
        Text('Operational status', style: context.eosText.titleMedium),
        SizedBox(height: context.eos.spacing.sm),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 600;
            final cards = [
              _StatusCard(
                title: 'Vendors',
                lines: [
                  'Waiting: ${vendorStatus.waitingForQuotes}',
                  'Quotes: ${vendorStatus.quoteReceived}',
                  'Accepted: ${vendorStatus.accepted}',
                  'Completed: ${vendorStatus.completed}',
                ],
                onTap: () => _open(context, PlanningModuleLink.vendors),
              ),
              _StatusCard(
                title: 'Guests',
                lines: [
                  'Invited: ${guestStatus.invited}',
                  'Accepted: ${guestStatus.accepted}',
                  'Pending: ${guestStatus.pending}',
                  'Checked in: ${guestStatus.checkedIn}',
                ],
                onTap: () => _open(context, PlanningModuleLink.guests),
              ),
              if (event.isPublicTicketed)
                _StatusCard(
                  title: 'Tickets',
                  lines: [
                    'Tiers: ${ticketStatus.tierCount}',
                    'Sold: ${ticketStatus.sales}',
                    'Revenue: ${formatRevenue(ticketStatus.revenueMinor)}',
                    'Capacity: ${ticketStatus.capacity}',
                  ],
                  onTap: () => _open(context, PlanningModuleLink.tickets),
                ),
              if (event.isPrivateCelebration)
                _StatusCard(
                  title: 'Finance',
                  lines: [
                    'Budget: ${formatRevenue(financeStatus.estimatedBudgetMinor)}',
                    'Committed: ${formatRevenue(financeStatus.committedMinor)}',
                    'Outstanding: ${formatRevenue(financeStatus.outstandingMinor)}',
                    'Revenue: ${formatRevenue(financeStatus.revenueMinor)}',
                  ],
                  onTap: () => _open(context, PlanningModuleLink.budget),
                ),
            ];
            if (wide) {
              return Wrap(
                spacing: context.eos.spacing.sm,
                runSpacing: context.eos.spacing.sm,
                children: [
                  for (final card in cards)
                    SizedBox(
                      width: (constraints.maxWidth - context.eos.spacing.sm) / 2,
                      child: card,
                    ),
                ],
              );
            }
            return Column(
              children: [
                for (final card in cards) ...[
                  card,
                  SizedBox(height: context.eos.spacing.sm),
                ],
              ],
            );
          },
        ),
        if (aiRecommendations.isNotEmpty) ...[
          SizedBox(height: context.eos.spacing.lg),
          Text('AI planning suggestions', style: context.eosText.titleMedium),
          SizedBox(height: context.eos.spacing.xs),
          Text(
            'From your AI Planner — each opens the module that resolves it.',
            style: context.eosText.bodySmall?.copyWith(color: EosColors.slate500),
          ),
          SizedBox(height: context.eos.spacing.sm),
          for (final rec in aiRecommendations)
            _AiRecommendationTile(
              recommendation: rec,
              onTap: () {
                final link = moduleLinkForAiAction(rec.actionRoute);
                if (link != null) {
                  _open(context, link);
                } else {
                  _open(context, PlanningModuleLink.aiPlanner);
                }
              },
            ),
        ],
      ],
    );
  }
}

class _LifecycleBanner extends StatelessWidget {
  const _LifecycleBanner({required this.stage});

  final EventLifecycleStage stage;

  @override
  Widget build(BuildContext context) {
    return EosSurfaceCard(
      elevated: true,
      child: Row(
        children: [
          Icon(Icons.flag_outlined, color: context.eosColors.primary),
          SizedBox(width: context.eos.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Lifecycle stage', style: context.eosText.labelSmall),
                Text(stage.label, style: context.eosText.titleSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreeQuestionsHeader extends StatelessWidget {
  const _ThreeQuestionsHeader({
    required this.outstanding,
    required this.inProgress,
    required this.nextAction,
  });

  final int outstanding;
  final int inProgress;
  final String? nextAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Planning Center', style: context.eosText.titleLarge),
        SizedBox(height: context.eos.spacing.xs),
        Text(
          '$outstanding still to do · $inProgress in progress',
          style: context.eosText.bodyMedium?.copyWith(color: EosColors.slate500),
        ),
        if (nextAction != null)
          Text(
            'Next: $nextAction',
            style: context.eosText.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
      ],
    );
  }
}

class _ReadinessCard extends StatelessWidget {
  const _ReadinessCard({
    required this.score,
    required this.dimensions,
    required this.onDimensionTap,
  });

  final int score;
  final List<EventReadinessDimension> dimensions;
  final void Function(PlanningModuleLink link) onDimensionTap;

  @override
  Widget build(BuildContext context) {
    return EosSurfaceCard(
      elevated: true,
      child: Padding(
        padding: EdgeInsets.all(context.eos.spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Event readiness', style: context.eosText.titleSmall),
            SizedBox(height: context.eos.spacing.sm),
            Text(
              '$score%',
              style: context.eosText.headlineMedium?.copyWith(color: EosColors.plum),
            ),
            SizedBox(height: context.eos.spacing.sm),
            if (dimensions.isEmpty)
              Text('Computing from your modules…', style: context.eosText.bodySmall)
            else
              for (final dim in dimensions.take(4))
                Padding(
                  padding: EdgeInsets.only(bottom: context.eos.spacing.xs),
                  child: InkWell(
                    onTap: dim.moduleLink == null ? null : () => onDimensionTap(dim.moduleLink!),
                    child: Row(
                      children: [
                        Expanded(child: Text(dim.label, style: context.eosText.labelSmall)),
                        Text('${dim.score}%', style: context.eosText.labelSmall),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _ChecklistTile extends StatelessWidget {
  const _ChecklistTile({required this.label, required this.done, this.onTap});

  final String label;
  final bool done;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.eos.spacing.xs),
      child: EosSurfaceCard(
        onTap: onTap,
        child: ListTile(
          dense: true,
          leading: Icon(
            done ? Icons.check_circle : Icons.radio_button_unchecked,
            color: done ? EosColors.success : context.eosColors.onSurfaceVariant,
            size: 20,
          ),
          title: Text(label, style: context.eosText.bodyMedium),
          trailing: onTap != null ? const Icon(Icons.chevron_right, size: 18) : null,
        ),
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({required this.item, required this.onTap});

  final PlannerTimelineItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (item.status) {
      PlannerTimelineStatus.overdue => EosColors.critical,
      PlannerTimelineStatus.dueSoon => EosColors.champagne,
      PlannerTimelineStatus.complete => EosColors.success,
      PlannerTimelineStatus.upcoming => context.eosColors.onSurfaceVariant,
    };

    return Padding(
      padding: EdgeInsets.only(bottom: context.eos.spacing.xs),
      child: EosSurfaceCard(
        onTap: onTap,
        child: ListTile(
          dense: true,
          leading: Icon(Icons.event_note_outlined, color: statusColor, size: 20),
          title: Text(item.label, style: context.eosText.bodyMedium),
          subtitle: Text(
            item.weeksBefore == 0 ? 'Event day' : '${item.weeksBefore}w before',
            style: context.eosText.bodySmall,
          ),
          trailing: const Icon(Icons.chevron_right, size: 18),
        ),
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.eos.spacing.xs),
      child: EosSurfaceCard(
        onTap: onTap,
        child: ListTile(
          dense: true,
          leading: Icon(Icons.task_alt_outlined, color: context.eosColors.primary, size: 20),
          title: Text(label, style: context.eosText.bodyMedium),
          trailing: const Icon(Icons.chevron_right, size: 18),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.title, required this.lines, required this.onTap});

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
            SizedBox(height: context.eos.spacing.xs),
            for (final line in lines)
              Text(line, style: context.eosText.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _AiRecommendationTile extends StatelessWidget {
  const _AiRecommendationTile({required this.recommendation, required this.onTap});

  final PlannerMissingRequirement recommendation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = switch (recommendation.severity) {
      PlannerRequirementSeverity.critical => Icons.error_outline,
      PlannerRequirementSeverity.important => Icons.warning_amber_outlined,
      PlannerRequirementSeverity.suggestion => Icons.lightbulb_outline,
    };
    return Padding(
      padding: EdgeInsets.only(bottom: context.eos.spacing.xs),
      child: EosSurfaceCard(
        onTap: onTap,
        child: ListTile(
          dense: true,
          leading: Icon(icon, size: 20),
          title: Text(recommendation.title, style: context.eosText.titleSmall),
          subtitle: Text(recommendation.description, style: context.eosText.bodySmall),
          trailing: const Icon(Icons.chevron_right, size: 18),
        ),
      ),
    );
  }
}
