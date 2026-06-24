import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/money.dart';
import '../../../../eos/eos.dart';
import '../../models/organizer_models.dart';
import '../../providers/organizer_providers.dart';
import '../../widgets/organizer_shared.dart';
import '../providers/event_command_center_v3_providers.dart';
import '../widgets/cc_v3_analytics_charts.dart';
import '../widgets/cc_v3_health_cards.dart';
import '../widgets/cc_v3_reminders_panel.dart';
import '../workspace_tabs.dart';

final _analyticsPeriodProvider = StateProvider.autoDispose<int>((ref) => 0);

class AnalyticsTabV3 extends ConsumerWidget {
  const AnalyticsTabV3({
    super.key,
    required this.eventId,
    this.onNavigateTab,
  });

  final String eventId;
  final void Function(EventWorkspaceTab tab)? onNavigateTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapAsync = ref.watch(eventCommandCenterV3Provider(eventId));
    final analytics = ref.watch(organizerAnalyticsProvider(eventId));
    final period = ref.watch(_analyticsPeriodProvider);

    return snapAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (snap) => analytics.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (a) => SingleChildScrollView(
          padding: EdgeInsets.all(context.eos.spacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CcV3SectionHeader(
                title: snap.isPrivate ? 'Celebration analytics' : 'Ticket analytics',
                subtitle: snap.isPrivate
                    ? 'Budget, vendors, guest response, and planning reminders'
                    : 'Revenue, attendance, conversion, and pipeline',
              ),
              CcV3RemindersPanel(
                reminders: snap.reminders,
                daysUntil: snap.daysUntilEvent,
                onNavigateTab: onNavigateTab,
              ),
              if (snap.reminders.isNotEmpty) SizedBox(height: context.eos.spacing.lg),
              CcV3AnalyticsOverviewCharts(snap: snap),
              SizedBox(height: context.eos.spacing.lg),
              if (!snap.isPrivate) ...[
                Wrap(
                  spacing: context.eos.spacing.md,
                  runSpacing: context.eos.spacing.md,
                  children: [
                    SizedBox(
                      width: 200,
                      child: EosKpiCard(
                        title: 'Tickets sold',
                        value: '${snap.publicMetrics?.ticketsSold ?? a.registrations}',
                        icon: Icons.confirmation_number_outlined,
                      ),
                    ),
                    SizedBox(
                      width: 200,
                      child: EosKpiCard(
                        title: 'Revenue',
                        value: formatRevenue(snap.publicMetrics?.revenueMinor ?? a.revenueMinor),
                        icon: Icons.payments_outlined,
                      ),
                    ),
                    SizedBox(
                      width: 200,
                      child: EosKpiCard(
                        title: 'Conversion',
                        value: '${(snap.publicMetrics?.conversionPercent ?? 0).round()}%',
                        icon: Icons.trending_up,
                      ),
                    ),
                    SizedBox(
                      width: 200,
                      child: EosKpiCard(
                        title: 'Check-ins',
                        value: '${a.checkIns}',
                        icon: Icons.qr_code_scanner,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: context.eos.spacing.lg),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('Daily')),
                    ButtonSegment(value: 1, label: Text('Weekly')),
                    ButtonSegment(value: 2, label: Text('Monthly')),
                  ],
                  selected: {period},
                  onSelectionChanged: (s) => ref.read(_analyticsPeriodProvider.notifier).state = s.first,
                ),
                SizedBox(height: context.eos.spacing.md),
                EosSurfaceCard(
                  child: EosSparkline(
                    values: switch (period) {
                      0 => a.dailySales,
                      1 => a.weeklySales,
                      _ => a.monthlySales,
                    },
                    height: 72,
                  ),
                ),
                SizedBox(height: context.eos.spacing.lg),
                EosSection(
                  title: 'Tier performance',
                  child: EosDataTable(
                    columns: const [
                      DataColumn(label: Text('Tier type')),
                      DataColumn(label: Text('Sold')),
                    ],
                    rows: a.tierTypeBreakdown.entries
                        .map(
                          (e) => DataRow(cells: [
                            DataCell(Text(ticketTierTypeLabel(e.key))),
                            DataCell(Text('${e.value}')),
                          ]),
                        )
                        .toList(),
                    emptyMessage: 'No sales yet',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
