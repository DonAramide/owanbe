import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/money.dart';
import '../../../../eos/eos.dart';
import '../../closing/closing_module_navigation.dart';
import '../../closing/event_closing_actions.dart';
import '../../closing/event_closing_models.dart';
import '../../closing/event_closing_workspace_provider.dart';
import '../../models/command_center_models.dart';
import '../../models/customer_event_models.dart';
import '../../navigation/event_navigator.dart';
import '../../operations/event_operations_models.dart';
import '../../operations/operations_command_navigation.dart';
import 'event_planning_center.dart';

String _formatDateTime(DateTime dt) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final period = dt.hour >= 12 ? 'PM' : 'AM';
  final minute = dt.minute.toString().padLeft(2, '0');
  return '${months[dt.month - 1]} ${dt.day}, ${dt.year} · $hour:$minute $period';
}

/// Closing & Intelligence Workspace — post-event orchestration (Phase 5).
class EventClosingCenter extends ConsumerWidget {
  const EventClosingCenter({
    super.key,
    required this.eventId,
    required this.fallbackSnapshot,
    this.isArchived = false,
  });

  final String eventId;
  final EventCommandCenterSnapshot fallbackSnapshot;
  final bool isArchived;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final closing = ref.watch(eventClosingWorkspaceProvider(eventId));

    return closing.when(
      loading: () => _ClosingBody(
        eventId: eventId,
        event: fallbackSnapshot.event,
        fallbackSnapshot: fallbackSnapshot,
        workspace: null,
        loading: true,
        isArchived: isArchived,
      ),
      error: (_, __) => _ClosingBody(
        eventId: eventId,
        event: fallbackSnapshot.event,
        fallbackSnapshot: fallbackSnapshot,
        workspace: null,
        loading: false,
        isArchived: isArchived,
      ),
      data: (data) => _ClosingBody(
        eventId: eventId,
        event: fallbackSnapshot.event,
        fallbackSnapshot: fallbackSnapshot,
        workspace: data,
        loading: false,
        isArchived: isArchived || data.phase == EventClosingPhase.archived,
      ),
    );
  }
}

class _ClosingBody extends ConsumerWidget {
  const _ClosingBody({
    required this.eventId,
    required this.event,
    required this.fallbackSnapshot,
    required this.workspace,
    required this.loading,
    required this.isArchived,
  });

  final String eventId;
  final CustomerEvent event;
  final EventCommandCenterSnapshot fallbackSnapshot;
  final EventClosingWorkspace? workspace;
  final bool loading;
  final bool isArchived;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateLabel = _formatDateTime(event.startsAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isArchived ? 'Event Archive' : 'Closing & Intelligence',
                    style: context.eosText.titleLarge,
                  ),
                  SizedBox(height: context.eos.spacing.xs),
                  Text(
                    isArchived
                        ? 'Read-only legacy record for ${event.title}'
                        : 'Financial closure, intelligence, and legacy for ${event.title}',
                    style: context.eosText.bodyMedium?.copyWith(color: EosColors.slate500),
                  ),
                ],
              ),
            ),
            if (workspace != null)
              _HistoricalScoreBadge(score: workspace!.historicalScore),
          ],
        ),
        if (loading) ...[
          SizedBox(height: context.eos.spacing.lg),
          const Center(child: CircularProgressIndicator()),
        ],
        if (workspace != null) ...[
          SizedBox(height: context.eos.spacing.lg),
          _ArchiveStatusBar(
            eventId: eventId,
            event: event,
            isArchived: isArchived,
            workspace: workspace!,
          ),
          SizedBox(height: context.eos.spacing.lg),
          _SectionTitle('Event summary'),
          _SummaryGrid(workspace: workspace!, dateLabel: dateLabel),
          SizedBox(height: context.eos.spacing.lg),
          _SectionTitle('Historical success'),
          _HistoricalDimensions(dimensions: workspace!.historicalDimensions),
          SizedBox(height: context.eos.spacing.lg),
          _SectionTitle('Financial closure'),
          _FinancialClosure(
            eventId: eventId,
            event: event,
            financial: workspace!.financial,
            readOnly: isArchived,
          ),
          SizedBox(height: context.eos.spacing.lg),
          _SectionTitle('Guest intelligence'),
          _GuestIntelligence(
            eventId: eventId,
            event: event,
            guestIntel: workspace!.guestIntel,
          ),
          SizedBox(height: context.eos.spacing.lg),
          _SectionTitle('Ticket analytics'),
          _TicketAnalytics(
            eventId: eventId,
            event: event,
            analytics: workspace!.ticketAnalytics,
          ),
          SizedBox(height: context.eos.spacing.lg),
          _SectionTitle('Vendor performance'),
          _VendorPerformance(
            eventId: eventId,
            rows: workspace!.vendorPerformance,
          ),
          SizedBox(height: context.eos.spacing.lg),
          _SectionTitle('Operational incidents'),
          _IncidentsSummary(
            eventId: eventId,
            openCount: workspace!.openIncidents,
          ),
          SizedBox(height: context.eos.spacing.lg),
          _SectionTitle('AI event debrief'),
          _AiDebrief(debrief: workspace!.debrief, eventId: eventId),
          SizedBox(height: context.eos.spacing.lg),
          _SectionTitle('Media summary'),
          _MediaSummary(
            eventId: eventId,
            media: workspace!.media,
          ),
          SizedBox(height: context.eos.spacing.lg),
          _SectionTitle('Feedback & activity'),
          Text(
            '${workspace!.feedbackCount} activity entries recorded during the event lifecycle.',
            style: context.eosText.bodyMedium,
          ),
          SizedBox(height: context.eos.spacing.lg),
          _SectionTitle('Reports & export'),
          _ReportsPanel(workspace: workspace!),
          SizedBox(height: context.eos.spacing.lg),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('Planning history', style: context.eosText.titleSmall),
            subtitle: Text(
              'Secondary — planning workspace for reference',
              style: context.eosText.bodySmall?.copyWith(color: EosColors.slate500),
            ),
            children: [
              EventPlanningCenter(eventId: eventId, fallbackSnapshot: fallbackSnapshot),
            ],
          ),
        ],
      ],
    );
  }
}

class _HistoricalScoreBadge extends StatelessWidget {
  const _HistoricalScoreBadge({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.eos.spacing.md,
        vertical: context.eos.spacing.sm,
      ),
      decoration: BoxDecoration(
        color: EosColors.champagne.withValues(alpha: 0.15),
        borderRadius: context.eos.radius.chip,
      ),
      child: Column(
        children: [
          Text('$score', style: context.eosText.headlineSmall),
          Text('Success', style: context.eosText.labelSmall),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
      child: Text(label, style: context.eosText.titleMedium),
    );
  }
}

class _ArchiveStatusBar extends ConsumerWidget {
  const _ArchiveStatusBar({
    required this.eventId,
    required this.event,
    required this.isArchived,
    required this.workspace,
  });

  final String eventId;
  final CustomerEvent event;
  final bool isArchived;
  final EventClosingWorkspace workspace;

  Future<void> _snack(BuildContext context, String message) async {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: context.eos.spacing.sm,
      runSpacing: context.eos.spacing.sm,
      children: [
        if (!isArchived) ...[
          FilledButton.icon(
            onPressed: () {
              archiveEvent(ref, eventId);
              ref.invalidate(eventClosingWorkspaceProvider(eventId));
              _snack(context, 'Event archived — read-only mode enabled');
            },
            icon: const Icon(Icons.archive_outlined, size: 18),
            label: const Text('Archive'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              final draft = buildDuplicateEventDraft(event: event, workspace: workspace);
              seedDuplicateEvent(ref, draft);
              context.go('/events/create');
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Duplicate'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              final draft = buildDuplicateEventDraft(
                event: event,
                workspace: workspace,
                similar: true,
              );
              seedDuplicateEvent(ref, draft);
              context.go('/events/create');
            },
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: const Text('Similar event'),
          ),
        ] else
          OutlinedButton.icon(
            onPressed: () {
              restoreEvent(ref, eventId);
              ref.invalidate(eventClosingWorkspaceProvider(eventId));
              _snack(context, 'Event restored from archive');
            },
            icon: const Icon(Icons.unarchive_outlined, size: 18),
            label: const Text('Restore'),
          ),
        OutlinedButton.icon(
          onPressed: () async {
            await exportEventBundle(workspace);
            if (!context.mounted) return;
            await _snack(context, 'Full event export copied to clipboard');
          },
          icon: const Icon(Icons.download_outlined, size: 18),
          label: const Text('Export event'),
        ),
      ],
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.workspace, required this.dateLabel});

  final EventClosingWorkspace workspace;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    final s = workspace.summary;
    final cards = [
      ('Venue', '${s.venue}, ${s.city}'),
      ('Date', dateLabel),
      ('Duration', '${s.durationHours.toStringAsFixed(1)} hrs'),
      ('Status', s.status.name),
      ('Invited', '${s.guestsInvited}'),
      ('Attended', '${s.guestsAttended}'),
      ('Tickets sold', '${s.ticketsSold}'),
      ('Revenue', formatRevenue(s.revenueMinor)),
      ('Expenses', formatRevenue(s.expensesMinor)),
      ('Profit', formatRevenue(s.profitMinor)),
      ('Vendors', '${s.vendorsUsed}'),
      ('Timeline', '${s.timelineCompletionPct}%'),
      ('Check-in rate', '${s.checkInRatePct}%'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 600;
        final itemWidth = wide ? (constraints.maxWidth - context.eos.spacing.sm) / 2 : constraints.maxWidth;
        return Wrap(
          spacing: context.eos.spacing.sm,
          runSpacing: context.eos.spacing.sm,
          children: [
            for (final (title, value) in cards)
              SizedBox(
                width: itemWidth,
                child: EosKpiCard(title: title, value: value, subtitle: ''),
              ),
          ],
        );
      },
    );
  }
}

class _HistoricalDimensions extends StatelessWidget {
  const _HistoricalDimensions({required this.dimensions});

  final List<HistoricalSuccessDimension> dimensions;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final d in dimensions)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(d.label),
            subtitle: Text(d.summary),
            trailing: Text('${d.score}%', style: context.eosText.titleSmall),
          ),
      ],
    );
  }
}

class _FinancialClosure extends StatelessWidget {
  const _FinancialClosure({
    required this.eventId,
    required this.event,
    required this.financial,
    required this.readOnly,
  });

  final String eventId;
  final CustomerEvent event;
  final EventFinancialClosureSnapshot financial;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Budget', formatRevenue(financial.budgetMinor), ClosingModuleLink.budget),
      ('Actual spend', formatRevenue(financial.actualSpendMinor), ClosingModuleLink.budget),
      ('Outstanding', formatRevenue(financial.outstandingMinor), ClosingModuleLink.budget),
      ('Vendor payments', formatRevenue(financial.vendorPaymentsMinor), ClosingModuleLink.vendors),
      ('Ticket revenue', formatRevenue(financial.ticketRevenueMinor), ClosingModuleLink.tickets),
      ('Refunds', '${financial.refundsMinor}', ClosingModuleLink.tickets),
      ('Settlement', financial.settlementEligible ? 'Eligible' : 'Pending', ClosingModuleLink.budget),
      ('Profit/Loss', formatRevenue(financial.profitLossMinor), ClosingModuleLink.budget),
    ];

    return Column(
      children: [
        for (final (label, value, link) in items)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(label),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value, style: context.eosText.titleSmall),
                if (!readOnly) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.open_in_new, size: 18),
                    onPressed: () => openClosingModuleLink(context, eventId, link, event: event),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _GuestIntelligence extends StatelessWidget {
  const _GuestIntelligence({
    required this.eventId,
    required this.event,
    required this.guestIntel,
  });

  final String eventId;
  final CustomerEvent event;
  final EventGuestIntelligenceSnapshot guestIntel;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      ('Invited', guestIntel.invited),
      ('Accepted', guestIntel.accepted),
      ('Declined', guestIntel.declined),
      ('Checked in', guestIntel.checkedIn),
      ('Walk-ins', guestIntel.walkIns),
      ('No-shows', guestIntel.noShows),
      ('VIP attendance', guestIntel.vipAttendance),
    ];

    return Column(
      children: [
        for (final (label, value) in metrics)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(label),
            trailing: Text('$value'),
            onTap: () => openClosingModuleLink(context, eventId, ClosingModuleLink.guests, event: event),
          ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Average arrival'),
          trailing: Text(guestIntel.averageArrivalLabel),
          onTap: () => openClosingModuleLink(context, eventId, ClosingModuleLink.guests, event: event),
        ),
      ],
    );
  }
}

class _TicketAnalytics extends StatelessWidget {
  const _TicketAnalytics({
    required this.eventId,
    required this.event,
    required this.analytics,
  });

  final String eventId;
  final CustomerEvent event;
  final EventTicketAnalyticsSnapshot analytics;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => openClosingModuleLink(context, eventId, ClosingModuleLink.tickets, event: event),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: EosKpiCard(title: 'Sales', value: '${analytics.sales}', subtitle: 'Tickets sold')),
              SizedBox(width: context.eos.spacing.sm),
              Expanded(child: EosKpiCard(title: 'Revenue', value: formatRevenue(analytics.revenueMinor), subtitle: 'Gross')),
            ],
          ),
          SizedBox(height: context.eos.spacing.sm),
          Row(
            children: [
              Expanded(child: EosKpiCard(title: 'Capacity', value: '${analytics.capacity}', subtitle: 'Total seats')),
              SizedBox(width: context.eos.spacing.sm),
              Expanded(child: EosKpiCard(title: 'Sell-through', value: '${analytics.sellThroughPct}%', subtitle: 'QR scans ${analytics.qrScans}')),
            ],
          ),
          if (analytics.tierBreakdown.isNotEmpty) ...[
            SizedBox(height: context.eos.spacing.sm),
            for (final tier in analytics.tierBreakdown)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(tier.$1),
                trailing: Text('${tier.$2}/${tier.$3}'),
              ),
          ],
        ],
      ),
    );
  }
}

class _VendorPerformance extends StatelessWidget {
  const _VendorPerformance({required this.eventId, required this.rows});

  final String eventId;
  final List<EventVendorPerformanceRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Text('No vendor records', style: context.eosText.bodyMedium);
    }

    return Column(
      children: [
        for (final row in rows)
          Card(
            margin: EdgeInsets.only(bottom: context.eos.spacing.sm),
            child: ListTile(
              title: Text(row.businessName),
              subtitle: Text('${row.service} · ${row.arrivalLabel} · ${row.completionStatus}'),
              trailing: row.repeatHire ? const Icon(Icons.replay, size: 18) : null,
              onTap: () => context.eventNav.openVendorPipeline(eventId),
            ),
          ),
      ],
    );
  }
}

class _IncidentsSummary extends StatelessWidget {
  const _IncidentsSummary({required this.eventId, required this.openCount});

  final String eventId;
  final int openCount;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(openCount == 0 ? 'No open incidents' : '$openCount open incident(s)'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => executeOperationsCommand(context, eventId, OperationsCommandAction.logIncident),
    );
  }
}

class _AiDebrief extends StatelessWidget {
  const _AiDebrief({required this.debrief, required this.eventId});

  final EventAiDebrief debrief;
  final String eventId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DebriefSection('What went well', debrief.wentWell),
        _DebriefSection('Delays', debrief.delays),
        _DebriefSection('Vendor observations', debrief.vendorObservations),
        _DebriefSection('Guest observations', debrief.guestObservations),
        _DebriefSection('Financial observations', debrief.financialObservations),
        _DebriefSection('Recommendations', debrief.recommendations),
        _DebriefSection('Missing opportunities', debrief.missingOpportunities),
        _DebriefSection('Improvements', debrief.improvements),
        TextButton(
          onPressed: () => context.eventNav.openAiPlanner(eventId),
          child: const Text('Open AI Planner'),
        ),
      ],
    );
  }
}

class _DebriefSection extends StatelessWidget {
  const _DebriefSection(this.title, this.items);

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(bottom: context.eos.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.eosText.titleSmall),
          SizedBox(height: context.eos.spacing.xs),
          for (final item in items)
            Padding(
              padding: EdgeInsets.only(left: context.eos.spacing.sm, bottom: 4),
              child: Text('• $item', style: context.eosText.bodySmall),
            ),
        ],
      ),
    );
  }
}

class _MediaSummary extends StatelessWidget {
  const _MediaSummary({required this.eventId, required this.media});

  final String eventId;
  final EventMediaSummary media;

  @override
  Widget build(BuildContext context) {
    final groups = [
      ('Photos', media.photos),
      ('Videos', media.videos),
      ('Documents', media.documents),
      ('Highlights', media.highlights),
    ];

    return Column(
      children: [
        for (final (label, items) in groups)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(label),
            trailing: Text('${items.length}'),
            onTap: () => context.eventNav.openWall(eventId),
          ),
      ],
    );
  }
}

class _ReportsPanel extends StatelessWidget {
  const _ReportsPanel({required this.workspace});

  final EventClosingWorkspace workspace;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final kind in ClosingReportKind.values)
          ActionChip(
            label: Text(kind.name),
            onPressed: () async {
              await exportClosingReport(kind: kind, workspace: workspace);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${kind.name} report copied to clipboard')),
                );
              }
            },
          ),
      ],
    );
  }
}
