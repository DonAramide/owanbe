import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/money.dart';
import '../../../../eos/eos.dart';
import '../../../../portals/customer/models/command_center_models.dart';
import '../../../../portals/customer/widgets/command_center/planning_progress_ring.dart';
import '../../data/organizer_persistence.dart';
import '../../../operations/providers/operations_providers.dart';
import '../../providers/organizer_providers.dart';
import '../../models/organizer_models.dart';
import '../models/event_command_center_v3_models.dart';
import '../providers/event_command_center_v3_providers.dart';
import '../workspace_tabs.dart';
import '../widgets/cc_v3_event_hero.dart';
import '../widgets/cc_v3_health_cards.dart';
import '../widgets/cc_v3_reminders_panel.dart';

class OverviewTabV3 extends ConsumerWidget {
  const OverviewTabV3({
    super.key,
    required this.eventId,
    this.onNavigateTab,
  });

  final String eventId;
  final void Function(EventWorkspaceTab tab)? onNavigateTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapAsync = ref.watch(eventCommandCenterV3Provider(eventId));

    return snapAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (snap) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(organizerEventProvider(eventId));
          ref.invalidate(eventCommandCenterV3Provider(eventId));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(context.eos.spacing.lg),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CcV3EventHero(
                    event: snap.event,
                    daysUntil: snap.daysUntilEvent,
                    onPublish: snap.event.status == OrganizerEventStatus.draft
                        ? () => publishEvent(ref, eventId)
                        : null,
                    onGoLive: snap.event.status == OrganizerEventStatus.published
                        ? () async {
                            await goLiveEvent(ref, eventId);
                            bumpOperationsRevision(ref);
                            ref.read(liveOpsEventIdProvider.notifier).state = eventId;
                          }
                        : null,
                  ),
                  SizedBox(height: context.eos.spacing.lg),
                  CcV3RemindersPanel(
                    reminders: snap.reminders,
                    daysUntil: snap.daysUntilEvent,
                    onNavigateTab: onNavigateTab,
                  ),
                  if (snap.reminders.isNotEmpty) SizedBox(height: context.eos.spacing.lg),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _planningRing(context, snap)),
                        SizedBox(width: context.eos.spacing.lg),
                        Expanded(child: _healthColumn(context, snap)),
                      ],
                    )
                  else ...[
                    _planningRing(context, snap),
                    SizedBox(height: context.eos.spacing.lg),
                    _healthColumn(context, snap),
                  ],
                  SizedBox(height: context.eos.spacing.xl),
                  const CcV3SectionHeader(
                    title: 'Event timeline',
                    subtitle: 'Recent planning and celebration activity',
                  ),
                  CcV3Timeline(items: _timelineItems(snap.activities)),
                  if (snap.event.refundRequests > 0) ...[
                    SizedBox(height: context.eos.spacing.md),
                    EosAttentionBanner(
                      headline: '${snap.event.refundRequests} refund request(s)',
                      message: 'Review in Finance',
                      severity: 'CRITICAL',
                      actionLabel: 'Open finance',
                      onAction: () => onNavigateTab?.call(EventWorkspaceTab.finance),
                    ),
                  ],
                  SizedBox(height: context.eos.spacing.lg),
                  _actionRow(context, ref, snap),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _planningRing(BuildContext context, EventCommandCenterV3Snapshot snap) {
    final tasks = buildPlanningTasks(snap.event);
    final done = tasks.where((t) => t.done).length;
    return PlanningProgressRing(
      progress: snap.planningProgress,
      tasksCompleted: done,
      tasksRemaining: tasks.length - done,
      tasks: tasks,
    );
  }

  Widget _healthColumn(BuildContext context, EventCommandCenterV3Snapshot snap) {
    return Column(
      children: [
        if (snap.isPrivate) ...[
          CcV3HealthCard(
            title: 'Financial health',
            progressPercent: snap.financial.utilizationPercent,
            onTap: () => onNavigateTab?.call(EventWorkspaceTab.finance),
            metrics: [
              CcV3MetricItem(label: 'Budget', value: formatRevenue(snap.financial.budgetMinor)),
              CcV3MetricItem(label: 'Wallet', value: formatRevenue(snap.financial.walletBalanceMinor)),
              CcV3MetricItem(label: 'Released', value: formatRevenue(snap.financial.fundsReleasedMinor)),
              CcV3MetricItem(label: 'Remaining', value: formatRevenue(snap.financial.remainingBudgetMinor)),
            ],
          ),
        ] else if (snap.publicMetrics != null) ...[
          CcV3HealthCard(
            title: 'Ticket performance',
            progressPercent: snap.publicMetrics!.conversionPercent,
            onTap: () => onNavigateTab?.call(EventWorkspaceTab.tickets),
            metrics: [
              CcV3MetricItem(label: 'Tickets sold', value: '${snap.publicMetrics!.ticketsSold}'),
              CcV3MetricItem(label: 'Revenue', value: formatRevenue(snap.publicMetrics!.revenueMinor)),
              CcV3MetricItem(label: 'Attendees', value: '${snap.publicMetrics!.attendees}'),
              CcV3MetricItem(
                label: 'Conversion',
                value: '${snap.publicMetrics!.conversionPercent.round()}%',
              ),
            ],
          ),
        ],
        SizedBox(height: context.eos.spacing.md),
        CcV3HealthCard(
          title: 'Vendor health',
          progressPercent: snap.vendorHealth.progressPercent,
          onTap: () => onNavigateTab?.call(EventWorkspaceTab.vendors),
          metrics: [
            CcV3MetricItem(label: 'Requested', value: '${snap.vendorHealth.requested}'),
            CcV3MetricItem(label: 'Negotiating', value: '${snap.vendorHealth.negotiating}'),
            CcV3MetricItem(label: 'Confirmed', value: '${snap.vendorHealth.confirmed}'),
            CcV3MetricItem(label: 'Completed', value: '${snap.vendorHealth.completed}'),
          ],
        ),
        SizedBox(height: context.eos.spacing.md),
        CcV3HealthCard(
          title: 'Guest health',
          progressPercent: snap.guestHealth.responsePercent,
          onTap: () => onNavigateTab?.call(EventWorkspaceTab.attendees),
          metrics: [
            CcV3MetricItem(label: 'Invited', value: '${snap.guestHealth.invited}'),
            CcV3MetricItem(label: 'RSVP yes', value: '${snap.guestHealth.rsvpAccepted}'),
            CcV3MetricItem(label: 'Pending', value: '${snap.guestHealth.rsvpPending}'),
            CcV3MetricItem(label: 'Checked in', value: '${snap.guestHealth.checkedIn}'),
          ],
        ),
      ],
    );
  }

  List<CcV3TimelineItem> _timelineItems(List<CommandActivityItem> activities) {
    return activities
        .map(
          (a) => CcV3TimelineItem(
            icon: _iconFor(a.type),
            title: a.title,
            subtitle: a.subtitle,
            timeAgo: formatTimeAgo(a.at),
          ),
        )
        .toList();
  }

  IconData _iconFor(CommandActivityType type) => switch (type) {
        CommandActivityType.vendorAccepted => Icons.handshake_outlined,
        CommandActivityType.vendorDeclined => Icons.cancel_outlined,
        CommandActivityType.rsvpSubmitted => Icons.how_to_reg,
        CommandActivityType.invitationSent => Icons.mail_outline,
        CommandActivityType.budgetReleased => Icons.payments_outlined,
        CommandActivityType.vendorArrived => Icons.storefront_outlined,
        CommandActivityType.ticketSold => Icons.confirmation_number_outlined,
        CommandActivityType.guestCheckedIn => Icons.qr_code_scanner,
      };

  Widget _actionRow(BuildContext context, WidgetRef ref, EventCommandCenterV3Snapshot snap) {
    return Wrap(
      spacing: context.eos.spacing.sm,
      children: [
        if (snap.event.status == OrganizerEventStatus.draft)
          FilledButton(onPressed: () => publishEvent(ref, eventId), child: const Text('Publish event')),
        OutlinedButton.icon(
          onPressed: () => context.push('/events/$eventId/invitations'),
          icon: const Icon(Icons.card_giftcard_outlined, size: 18),
          label: const Text('Invitation cards'),
        ),
        OutlinedButton.icon(
          onPressed: () => onNavigateTab?.call(EventWorkspaceTab.marketplace),
          icon: const Icon(Icons.storefront_outlined, size: 18),
          label: const Text('Find vendors'),
        ),
      ],
    );
  }
}
