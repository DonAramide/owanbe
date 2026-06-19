import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money.dart';
import '../../../eos/eos.dart';
import '../models/organizer_models.dart';
import '../providers/organizer_providers.dart';
import '../widgets/organizer_shared.dart';

final _globalAnalyticsPeriodProvider = StateProvider<int>((ref) => 0);

class EventAnalyticsScreen extends ConsumerWidget {
  const EventAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventId = ref.watch(selectedOrganizerEventIdProvider);
    final analytics = eventId == null ? null : ref.watch(organizerAnalyticsProvider(eventId));
    final eventAsync = eventId == null ? null : ref.watch(organizerEventProvider(eventId));
    final period = ref.watch(_globalAnalyticsPeriodProvider);

    return EosPageScaffold(
      title: 'Event analytics',
      subtitle: 'Daily, weekly, and monthly performance',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const OrganizerEventPicker(),
          SizedBox(height: context.eos.spacing.lg),
          if (eventId == null)
            EosSurfaceCard(child: Text('Select an event', style: context.eosText.bodyMedium))
          else
            analytics!.when(
              data: (snap) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (eventAsync != null)
                      eventAsync.when(
                        data: (e) => e != null
                            ? Text(e.title, style: context.eosText.titleLarge)
                            : const SizedBox.shrink(),
                        loading: () => const SizedBox.shrink(),
                        error: (_, _) => const SizedBox.shrink(),
                      ),
                    SizedBox(height: context.eos.spacing.md),
                    Wrap(
                      spacing: context.eos.spacing.md,
                      runSpacing: context.eos.spacing.md,
                      children: [
                        SizedBox(
                          width: 200,
                          child: EosKpiCard(
                            title: 'Page views',
                            value: '${snap.pageViews}',
                            icon: Icons.visibility_outlined,
                            trend: const EosTrendBadge(deltaPercent: 12.4),
                          ),
                        ),
                        SizedBox(
                          width: 200,
                          child: EosKpiCard(title: 'Tickets sold', value: '${snap.ticketsSold}', icon: Icons.confirmation_number_outlined),
                        ),
                        SizedBox(
                          width: 200,
                          child: EosKpiCard(
                            title: 'Revenue',
                            value: ngnFromMinor(snap.revenueMinor.toString()),
                            icon: Icons.payments_outlined,
                          ),
                        ),
                        SizedBox(
                          width: 200,
                          child: EosKpiCard(
                            title: 'Registrations',
                            value: '${snap.registrations}',
                            icon: Icons.how_to_reg,
                          ),
                        ),
                        SizedBox(
                          width: 200,
                          child: EosKpiCard(title: 'Check-ins', value: '${snap.checkIns}', icon: Icons.qr_code_scanner),
                        ),
                        SizedBox(
                          width: 200,
                          child: EosKpiCard(title: 'No-shows', value: '${snap.noShows}', icon: Icons.person_off_outlined),
                        ),
                        SizedBox(
                          width: 200,
                          child: EosKpiCard(
                            title: 'Check-in rate',
                            value: '${(snap.checkInRate * 100).toStringAsFixed(0)}%',
                            icon: Icons.percent,
                            attention: snap.checkInRate > 0.5 ? EosKpiAttention.info : EosKpiAttention.warning,
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
                      onSelectionChanged: (s) => ref.read(_globalAnalyticsPeriodProvider.notifier).state = s.first,
                    ),
                    SizedBox(height: context.eos.spacing.md),
                    EosSection(
                      title: switch (period) {
                        0 => 'Daily sales',
                        1 => 'Weekly sales',
                        _ => 'Monthly sales',
                      },
                      child: EosSurfaceCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            EosSparkline(
                              values: switch (period) {
                                0 => snap.dailySales,
                                1 => snap.weeklySales,
                                _ => snap.monthlySales,
                              },
                              height: 56,
                            ),
                            SizedBox(height: context.eos.spacing.sm),
                            EosChartLegend(
                              items: [
                                EosLegendItem(label: 'Sales volume', color: context.eosColors.primary),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    EosSection(
                      title: 'Sales by tier',
                      child: EosDataTable(
                        columns: const [
                          DataColumn(label: Text('Tier')),
                          DataColumn(label: Text('Sold')),
                        ],
                        rows: snap.tierBreakdown.entries
                            .map((e) => DataRow(cells: [DataCell(Text(e.key)), DataCell(Text('${e.value}'))]))
                            .toList(),
                        emptyMessage: 'No sales yet',
                      ),
                    ),
                    EosSection(
                      title: 'Performance by tier type',
                      child: EosDataTable(
                        columns: const [
                          DataColumn(label: Text('Type')),
                          DataColumn(label: Text('Sold')),
                        ],
                        rows: snap.tierTypeBreakdown.entries
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
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('$e'),
            ),
        ],
      ),
    );
  }
}
