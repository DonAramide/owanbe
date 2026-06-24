import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';
import '../../../portals/customer/router/customer_routes.dart';
import '../models/organizer_models.dart';
import '../providers/organizer_providers.dart';
import '../widgets/organizer_shared.dart';

class OrganizerDashboardScreen extends ConsumerWidget {
  const OrganizerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(organizerDashboardStatsProvider);
    final attention = ref.watch(organizerAttentionProvider);
    final events = ref.watch(organizerEventsProvider);

    return EosPageScaffold(
      title: 'Organizer dashboard',
      subtitle: 'Command center for events, vendors, and attendees',
      actions: [
        OutlinedButton.icon(
          onPressed: () => context.push('/attendee'),
          icon: const Icon(Icons.confirmation_number_outlined, size: 18),
          label: const Text('Events I\'m attending'),
        ),
        OutlinedButton.icon(
          onPressed: () => context.push(CustomerRoutes.vendors),
          icon: const Icon(Icons.storefront_outlined, size: 18),
          label: const Text('Browse marketplace'),
        ),
        FilledButton.icon(
          onPressed: () => context.push('/organizer/events/new'),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Create event'),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          stats.when(
            data: (s) => Wrap(
              spacing: context.eos.spacing.md,
              runSpacing: context.eos.spacing.md,
              children: [
                _kpi(
                  context,
                  ref,
                  'Active events',
                  '${s.activeEvents}',
                  Icons.celebration_outlined,
                  s.activeEvents > 0 ? EosKpiAttention.info : EosKpiAttention.none,
                  tabIndex: 1,
                ),
                _kpi(
                  context,
                  ref,
                  'Upcoming',
                  '${s.upcomingEvents}',
                  Icons.event_outlined,
                  EosKpiAttention.none,
                  tabIndex: 1,
                ),
                _kpi(
                  context,
                  ref,
                  'Tickets sold',
                  '${s.ticketsSold}',
                  Icons.confirmation_number_outlined,
                  s.ticketsSold > 0 ? EosKpiAttention.info : EosKpiAttention.none,
                  tabIndex: 2,
                ),
                SizedBox(
                  width: 260,
                  child: EosKpiCard(
                    title: 'Revenue',
                    value: formatRevenue(s.revenueMinor),
                    icon: Icons.payments_outlined,
                    actionLabel: 'View analytics',
                    onTap: () => ref.read(organizerShellTabProvider.notifier).select(5),
                  ),
                ),
                _kpi(
                  context,
                  ref,
                  'Vendors',
                  '${s.vendorCount}',
                  Icons.storefront_outlined,
                  EosKpiAttention.none,
                  tabIndex: 3,
                ),
                _kpi(
                  context,
                  ref,
                  'Attendees',
                  '${s.attendeeCount}',
                  Icons.people_outline,
                  EosKpiAttention.none,
                  tabIndex: 4,
                ),
              ],
            ),
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text('$e'),
          ),
          SizedBox(height: context.eos.spacing.xl),
          EosSection(
            title: 'Attention center',
            subtitle: 'Items needing your review',
            child: attention.when(
              data: (items) => items.isEmpty
                  ? EosSurfaceCard(
                      child: Text('All clear — no pending actions.', style: context.eosText.bodyMedium),
                    )
                  : Column(
                      children: [
                        for (final item in items.take(5))
                          EosAttentionBanner(
                            headline: item.headline,
                            message: item.message,
                            severity: item.severity,
                            actionLabel: 'Open event',
                            onAction: item.eventId == null
                                ? null
                                : () => context.push(
                                      '/organizer/events/${item.eventId}?tab=${_tabForAttention(item.type)}',
                                    ),
                          ),
                      ],
                    ),
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('$e'),
            ),
          ),
          SizedBox(height: context.eos.spacing.xl),
          const EosSection(
            title: 'Quick actions',
            child: OrganizerQuickActions(),
          ),
          SizedBox(height: context.eos.spacing.xl),
          EosSection(
            title: 'Recent events',
            subtitle: 'Open workspace for full management',
            child: events.when(
              data: (list) {
                if (list.isEmpty) {
                  return EosSurfaceCard(
                    child: Text('No events yet — create your first event.', style: context.eosText.bodyMedium),
                  );
                }
                return EosDataTable(
                  columns: const [
                    DataColumn(label: Text('Event')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Sold')),
                    DataColumn(label: Text('Revenue')),
                    DataColumn(label: Text('')),
                  ],
                  rows: list.take(6).map((e) {
                    return DataRow(
                      cells: [
                        DataCell(Text(e.title, style: context.eosText.titleSmall)),
                        DataCell(EosFinanceChip(label: organizerStatusLabel(e.status), compact: true)),
                        DataCell(Text('${e.ticketsSold}/${e.totalCapacity}')),
                        DataCell(OrganizerMoneyText(minor: e.revenueMinor, compact: true)),
                        DataCell(
                          TextButton(
                            onPressed: () => context.push('/organizer/events/${e.id}'),
                            child: const Text('Open'),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('$e'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpi(
    BuildContext context,
    WidgetRef ref,
    String title,
    String value,
    IconData icon,
    EosKpiAttention attention, {
    String? subtitle,
    required int tabIndex,
  }) {
    return SizedBox(
      width: 260,
      child: EosKpiCard(
        title: title,
        value: value,
        subtitle: subtitle,
        icon: icon,
        attention: attention,
        actionLabel: 'View details',
        onTap: () => ref.read(organizerShellTabProvider.notifier).select(tabIndex),
      ),
    );
  }

  int _tabForAttention(OrganizerAttentionType type) => switch (type) {
        OrganizerAttentionType.pendingVendorApproval => 3,
        OrganizerAttentionType.lowTicketSales => 1,
        OrganizerAttentionType.refundRequest => 4,
        OrganizerAttentionType.unpublishedDraft => 7,
      };
}
