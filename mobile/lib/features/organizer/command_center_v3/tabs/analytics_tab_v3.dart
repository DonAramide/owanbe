import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../auth/auth_notifier.dart';
import '../../../../core/utils/export_helper.dart';
import '../../../../core/utils/money.dart';
import '../../../../eos/eos.dart';
import '../../analytics/organizer_analytics_api.dart';
import '../../analytics/organizer_analytics_providers.dart';
import '../providers/event_command_center_v3_providers.dart';
import '../widgets/cc_v3_analytics_charts.dart';
import '../widgets/cc_v3_health_cards.dart';
import '../widgets/cc_v3_reminders_panel.dart';
import '../workspace_tabs.dart';

final _analyticsChartPeriodProvider = StateProvider.autoDispose<int>((ref) => 0);

class AnalyticsTabV3 extends ConsumerWidget {
  const AnalyticsTabV3({
    super.key,
    required this.eventId,
    this.onNavigateTab,
    this.nestedInParentScroll = false,
  });

  final String eventId;
  final void Function(EventWorkspaceTab tab)? onNavigateTab;
  /// When true, omit RefreshIndicator / own scroll (parent EosPageScaffold scrolls).
  final bool nestedInParentScroll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapAsync = ref.watch(eventCommandCenterV3Provider(eventId));
    final analytics = ref.watch(organizerAnalyticsProvider(eventId));
    final days = ref.watch(organizerAnalyticsDaysProvider(eventId));
    final chartPeriod = ref.watch(_analyticsChartPeriodProvider);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text('Event intelligence', style: context.eosText.headlineSmall),
        ),
        SizedBox(height: context.eos.spacing.xs),
        Text(
          'Read-only metrics from orders, entitlements, check-ins, invitations, and finance.',
          style: context.eosText.bodySmall,
        ),
        SizedBox(height: context.eos.spacing.md),
        Wrap(
          spacing: context.eos.spacing.sm,
          runSpacing: context.eos.spacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Window', style: context.eosText.labelMedium),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 7, label: Text('7d')),
                ButtonSegment(value: 30, label: Text('30d')),
                ButtonSegment(value: 90, label: Text('90d')),
              ],
              selected: {days},
              onSelectionChanged: (s) {
                ref.read(organizerAnalyticsDaysProvider(eventId).notifier).state = s.first;
              },
            ),
            OutlinedButton.icon(
              onPressed: () => _exportCsv(context, ref),
              icon: const Icon(Icons.download_outlined, size: 18),
              label: const Text('Export CSV'),
            ),
          ],
        ),
        SizedBox(height: context.eos.spacing.lg),
        snapAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (snap) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CcV3RemindersPanel(
                reminders: snap.reminders,
                daysUntil: snap.daysUntilEvent,
                onNavigateTab: onNavigateTab,
              ),
              if (snap.reminders.isNotEmpty) SizedBox(height: context.eos.spacing.lg),
              if (snap.isPrivate) CcV3AnalyticsOverviewCharts(snap: snap),
            ],
          ),
        ),
        analytics.when(
          loading: () => const _AnalyticsSkeleton(),
          error: (e, _) => EosAttentionBanner(
            headline: 'Analytics unavailable',
            message: '$e',
            severity: 'WARNING',
            actionLabel: 'Retry',
            onAction: () => invalidateEventAnalytics(ref, eventId),
          ),
          data: (a) => _AnalyticsBody(
            snapshot: a,
            chartPeriod: chartPeriod,
            onChartPeriod: (v) => ref.read(_analyticsChartPeriodProvider.notifier).state = v,
            onNavigateFinance: () => onNavigateTab?.call(EventWorkspaceTab.finance),
          ),
        ),
      ],
    );

    if (nestedInParentScroll) {
      return content;
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(eventCommandCenterV3Provider(eventId));
        invalidateEventAnalytics(ref, eventId);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(context.eos.spacing.lg),
        child: content,
      ),
    );
  }

  Future<void> _exportCsv(BuildContext context, WidgetRef ref) async {
    try {
      final session = ref.read(authSessionProvider);
      final bytes = await ref.read(organizerAnalyticsApiProvider).exportEventCsvBytes(
            eventId: eventId,
            session: session,
          );
      final filename = 'owanbe-analytics-$eventId-${DateTime.now().toIso8601String().substring(0, 10)}.csv';
      final path = await ExportHelper.downloadBytes(filename, bytes, mimeType: 'text/csv; charset=utf-8');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            path == null || path == filename
                ? 'Downloaded $filename'
                : 'Saved $filename → $path',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }
}

class _AnalyticsBody extends StatelessWidget {
  const _AnalyticsBody({
    required this.snapshot,
    required this.chartPeriod,
    required this.onChartPeriod,
    this.onNavigateFinance,
  });

  final EventAnalyticsSnapshot snapshot;
  final int chartPeriod;
  final ValueChanged<int> onChartPeriod;
  final VoidCallback? onNavigateFinance;

  @override
  Widget build(BuildContext context) {
    final a = snapshot;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CcV3SectionHeader(
          title: 'Overview',
          subtitle: 'Canonical sales · attendance · orders',
        ),
        Wrap(
          spacing: context.eos.spacing.md,
          runSpacing: context.eos.spacing.md,
          children: [
            _Kpi(title: 'Orders', value: '${a.ordersCount}', icon: Icons.receipt_long_outlined),
            _Kpi(title: 'Tickets sold', value: '${a.ticketsSold}', icon: Icons.confirmation_number_outlined),
            _Kpi(title: 'Revenue', value: formatRevenue(a.revenueMinor), icon: Icons.payments_outlined),
            _Kpi(title: 'Check-ins', value: '${a.checkIns}', icon: Icons.qr_code_scanner),
            _Kpi(
              title: 'Attendance',
              value: '${a.attendancePct.toStringAsFixed(1)}%',
              icon: Icons.groups_outlined,
            ),
            _Kpi(
              title: 'Page views',
              value: a.pageViewsAvailable ? '${a.pageViews}' : 'Unavailable',
              icon: Icons.visibility_outlined,
            ),
          ],
        ),
        if (a.engagementSummary.isNotEmpty) ...[
          SizedBox(height: context.eos.spacing.md),
          EosSurfaceCard(
            child: Text(a.engagementSummary, style: context.eosText.bodyMedium),
          ),
        ],
        SizedBox(height: context.eos.spacing.xl),
        const CcV3SectionHeader(
          title: 'Sales',
          subtitle: 'Orders · revenue over time · tier performance · paid vs complimentary',
        ),
        Wrap(
          spacing: context.eos.spacing.md,
          runSpacing: context.eos.spacing.md,
          children: [
            _Kpi(title: 'Paid tickets', value: '${a.paidTickets}', icon: Icons.paid_outlined),
            _Kpi(
              title: 'Complimentary',
              value: '${a.complimentaryTickets}',
              icon: Icons.card_giftcard_outlined,
            ),
          ],
        ),
        SizedBox(height: context.eos.spacing.md),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('Daily')),
            ButtonSegment(value: 1, label: Text('Weekly')),
            ButtonSegment(value: 2, label: Text('Monthly')),
          ],
          selected: {chartPeriod},
          onSelectionChanged: (s) => onChartPeriod(s.first),
        ),
        SizedBox(height: context.eos.spacing.md),
        EosSection(
          title: 'Sales trend',
          child: EosSurfaceCard(
            child: a.dailySales.isEmpty
                ? Text('No sales in this window', style: context.eosText.bodySmall)
                : EosSparkline(
                    values: switch (chartPeriod) {
                      0 => a.dailySales,
                      1 => a.weeklySales,
                      _ => a.monthlySales,
                    },
                    height: 72,
                  ),
          ),
        ),
        EosSection(
          title: 'Revenue over time',
          child: EosSurfaceCard(
            child: a.revenueDaily.isEmpty
                ? Text('No revenue in this window', style: context.eosText.bodySmall)
                : EosSparkline(values: a.revenueDaily, height: 72),
          ),
        ),
        EosSection(
          title: 'Ticket tier performance',
          child: EosDataTable(
            columns: const [
              DataColumn(label: Text('Tier')),
              DataColumn(label: Text('Sold')),
            ],
            rows: a.tierBreakdown.entries
                .map((e) => DataRow(cells: [DataCell(Text(e.key)), DataCell(Text('${e.value}'))]))
                .toList(),
            emptyMessage: 'No entitlements issued yet',
          ),
        ),
        SizedBox(height: context.eos.spacing.xl),
        const CcV3SectionHeader(
          title: 'Attendance & check-ins',
          subtitle: 'From ticket_entitlements + event_check_ins',
        ),
        Wrap(
          spacing: context.eos.spacing.md,
          runSpacing: context.eos.spacing.md,
          children: [
            _Kpi(title: 'Registered', value: '${a.registrations}', icon: Icons.how_to_reg),
            _Kpi(title: 'Checked in', value: '${a.checkIns}', icon: Icons.login),
            _Kpi(title: 'No-shows', value: '${a.noShows}', icon: Icons.person_off_outlined),
            _Kpi(
              title: 'No-show %',
              value: '${a.noShowPct.toStringAsFixed(1)}%',
              icon: Icons.percent,
            ),
          ],
        ),
        SizedBox(height: context.eos.spacing.md),
        EosSection(
          title: 'Check-ins (daily)',
          child: EosSurfaceCard(
            child: a.checkInsDaily.isEmpty
                ? Text('No check-ins in this window', style: context.eosText.bodySmall)
                : EosSparkline(values: a.checkInsDaily, height: 56),
          ),
        ),
        EosSection(
          title: 'Hourly arrivals',
          child: EosSurfaceCard(
            child: a.checkInsHourly.every((p) => p.value == 0)
                ? Text('No check-in timestamps yet', style: context.eosText.bodySmall)
                : SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: a.checkInsHourly.length,
                      itemBuilder: (context, i) {
                        final p = a.checkInsHourly[i];
                        final max = a.checkInsHourly.map((e) => e.value).fold<double>(1, (m, v) => v > m ? v : m);
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text('${p.value.toInt()}', style: context.eosText.labelSmall),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Container(
                                    width: 10,
                                    height: (p.value / max) * 72,
                                    color: context.eosColors.primary.withValues(alpha: 0.75),
                                  ),
                                ),
                              ),
                              Text(p.label.substring(0, 2), style: context.eosText.labelSmall),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ),
        SizedBox(height: context.eos.spacing.xl),
        const CcV3SectionHeader(
          title: 'Invitations & RSVP',
          subtitle: 'From invitation + guest RSVP system',
        ),
        if (!a.invitationsAvailable)
          EosSurfaceCard(
            child: Text(
              'Invitation metrics unavailable — no guests or invitations for this event yet.',
              style: context.eosText.bodySmall,
            ),
          )
        else
          Wrap(
            spacing: context.eos.spacing.md,
            runSpacing: context.eos.spacing.md,
            children: [
              _Kpi(title: 'Invitations sent', value: '${a.invitationsSent}', icon: Icons.mail_outline),
              _Kpi(title: 'Pending', value: '${a.invitationsPending}', icon: Icons.hourglass_empty),
              _Kpi(title: 'Accepted', value: '${a.invitationsAccepted}', icon: Icons.check_circle_outline),
              _Kpi(title: 'Declined', value: '${a.invitationsDeclined}', icon: Icons.cancel_outlined),
              _Kpi(
                title: 'RSVP conversion',
                value: '${a.rsvpConversionPct.toStringAsFixed(1)}%',
                icon: Icons.trending_up,
              ),
            ],
          ),
        SizedBox(height: context.eos.spacing.xl),
        const CcV3SectionHeader(
          title: 'Finance',
          subtitle: 'Gross · net · fees · refunds · settlement · payout',
        ),
        if (onNavigateFinance != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: onNavigateFinance, child: const Text('Open Finance tab')),
          ),
        Wrap(
          spacing: context.eos.spacing.md,
          runSpacing: context.eos.spacing.md,
          children: [
            _Kpi(title: 'Gross', value: ngnFromMinor(a.grossCollectedMinor), icon: Icons.account_balance_wallet_outlined),
            _Kpi(title: 'Net', value: ngnFromMinor(a.netEarningsMinor), icon: Icons.savings_outlined),
            _Kpi(title: 'Fees', value: ngnFromMinor(a.platformFeeMinor), icon: Icons.account_balance_outlined),
            _Kpi(title: 'Refunds', value: ngnFromMinor(a.refundedTotalMinor), icon: Icons.undo),
            _Kpi(title: 'Escrow', value: ngnFromMinor(a.heldInEscrowMinor), icon: Icons.lock_outline),
            _Kpi(title: 'Pending payout', value: ngnFromMinor(a.pendingPayoutMinor), icon: Icons.payments_outlined),
            _Kpi(title: 'Settlement', value: a.settlementStatus, icon: Icons.verified_outlined),
          ],
        ),
        SizedBox(height: context.eos.spacing.xl),
        const CcV3SectionHeader(
          title: 'Event intelligence',
          subtitle: 'Derived only from the metrics above — never invented',
        ),
        EosSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IntelRow('Best-selling tier', a.bestSellingTier ?? 'Unavailable'),
              _IntelRow(
                'Peak attendance period',
                a.peakAttendanceHour == null
                    ? 'Unavailable'
                    : '${a.peakAttendanceHour} (${a.peakAttendanceCount} check-ins)',
              ),
              _IntelRow('Engagement', a.engagementSummary.isEmpty ? 'Unavailable' : a.engagementSummary),
              if (!a.trafficSourcesAvailable)
                const _IntelRow('Traffic sources', 'Unavailable — no instrumentation'),
            ],
          ),
        ),
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.title, required this.value, required this.icon});
  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: EosKpiCard(title: title, value: value, icon: icon),
    );
  }
}

class _IntelRow extends StatelessWidget {
  const _IntelRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 160, child: Text(label, style: context.eosText.labelMedium)),
          Expanded(child: Text(value, style: context.eosText.bodyMedium)),
        ],
      ),
    );
  }
}

class _AnalyticsSkeleton extends StatelessWidget {
  const _AnalyticsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 3; i++) ...[
          Container(
            height: 88,
            margin: EdgeInsets.only(bottom: context.eos.spacing.md),
            decoration: BoxDecoration(
              color: context.eosColors.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ],
        const LinearProgressIndicator(minHeight: 2),
      ],
    );
  }
}
