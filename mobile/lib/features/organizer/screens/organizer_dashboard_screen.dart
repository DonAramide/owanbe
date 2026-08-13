import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';
import '../../../portals/customer/router/customer_routes.dart';
import '../../../portals/customer/router/event_route_registry.dart';
import '../../../portals/customer/providers/vendor_crm_providers.dart';
import '../finance/organizer_finance_providers.dart';
import '../models/organizer_models.dart';
import '../providers/organizer_event_list_filters.dart';
import '../providers/organizer_providers.dart';
import '../widgets/organizer_command_center.dart';
import '../widgets/organizer_dashboard_kpi_strip.dart';
import '../widgets/organizer_shared.dart';
import 'organizer_profile_edit_sheet.dart';

class OrganizerDashboardScreen extends ConsumerWidget {
  const OrganizerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attention = ref.watch(organizerAttentionProvider);
    final events = ref.watch(organizerEventsProvider);
    final tabSelect = ref.read(organizerShellTabProvider.notifier);

    return EosPageScaffold(
      title: 'Organizer dashboard',
      subtitle: 'Command center for events, vendors, and attendees',
      actions: EosAdaptive.isCompact(context)
          ? const []
          : [
              OutlinedButton.icon(
                onPressed: () => showOrganizerProfileEditor(context, ref),
                icon: const Icon(Icons.manage_accounts_outlined, size: 18),
                label: const Text('Edit Organizer Profile'),
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
            OrganizerDashboardKpiStrip(
              onEventsTap: () => tabSelect.select(1),
              onTicketsTap: () => tabSelect.select(2),
              onVendorsTap: () => tabSelect.select(3),
              onAttendeesTap: () => tabSelect.select(4),
              onAnalyticsTap: () => tabSelect.select(5),
            ),
            SizedBox(height: context.eos.spacing.lg),
            const _OrganizerFinanceHubStrip(),
            SizedBox(height: context.eos.spacing.xl),
            const _OrganizerVendorCrmStrip(),
            SizedBox(height: context.eos.spacing.xl),
            const _OrganizerAnalyticsPortfolioStrip(),
            SizedBox(height: context.eos.spacing.xl),
            EosSection(
              title: 'Command center',
              subtitle: 'Create, duplicate, and resume events',
              child: Wrap(
                spacing: context.eos.spacing.sm,
                runSpacing: context.eos.spacing.sm,
                children: [
                  FilledButton.icon(
                    onPressed: () => context.push('/organizer/events/new'),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Create event'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => showOrganizerTemplatePicker(context, ref),
                    icon: const Icon(Icons.dashboard_customize_outlined, size: 18),
                    label: const Text('Event templates'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => showOrganizerDuplicatePicker(context, ref),
                    icon: const Icon(Icons.copy_outlined, size: 18),
                    label: const Text('Duplicate event'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      tabSelect.select(1);
                      ref.read(organizerEventStatusFilterProvider.notifier).state =
                          OrganizerEventStatus.draft;
                    },
                    icon: const Icon(Icons.edit_note_outlined, size: 18),
                    label: const Text('Continue draft'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.push(EventRouteRegistry.portfolio),
                    icon: const Icon(Icons.insights_outlined, size: 18),
                    label: const Text('Portfolio workspace'),
                  ),
                ],
              ),
            ),
            SizedBox(height: context.eos.spacing.xl),
            EosSection(
              title: 'Recent drafts',
              subtitle: 'Quick resume unpublished events',
              child: events.when(
                data: (list) {
                  final drafts = list
                      .where((e) => e.status == OrganizerEventStatus.draft)
                      .toList()
                    ..sort((a, b) {
                      final ac = a.createdAt ?? a.startsAt;
                      final bc = b.createdAt ?? b.startsAt;
                      return bc.compareTo(ac);
                    });
                  if (drafts.isEmpty) {
                    return EosSurfaceCard(
                      child: Text(
                        'No drafts — start from Create event or a template.',
                        style: context.eosText.bodyMedium,
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final e in drafts.take(4))
                        Padding(
                          padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                          child: EosSurfaceCard(
                            onTap: () => context.push('/organizer/events/${e.id}'),
                            child: ListTile(
                              leading: const Icon(Icons.edit_note_outlined),
                              title: Text(e.title),
                              subtitle: Text(
                                '${e.city} · ${formatEventDateRange(e.startsAt, e.endsAt)}',
                              ),
                              trailing: TextButton(
                                onPressed: () => context.push('/organizer/events/${e.id}'),
                                child: const Text('Resume'),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => _errorCard(context, e, () => ref.invalidate(organizerEventsProvider)),
              ),
            ),
            SizedBox(height: context.eos.spacing.xl),
            EosSection(
              title: 'Attention center',
              subtitle: 'Recent activity and items needing review',
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
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => _errorCard(context, e, () => ref.invalidate(organizerAttentionProvider)),
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
              subtitle: 'Open workspace for full Command Center V3',
              child: events.when(
                data: (list) {
                  if (list.isEmpty) {
                    return EosSurfaceCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('No events yet — create your first event.', style: context.eosText.bodyMedium),
                          SizedBox(height: context.eos.spacing.sm),
                          FilledButton(
                            onPressed: () => context.push('/organizer/events/new'),
                            child: const Text('Create event'),
                          ),
                        ],
                      ),
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
                    rows: list.take(8).map((e) {
                      return DataRow(
                        cells: [
                          DataCell(Text(e.title, style: context.eosText.titleSmall)),
                          DataCell(EosFinanceChip(label: organizerStatusLabel(e.status), compact: true)),
                          DataCell(Text('${e.ticketsSold}/${e.totalCapacity}')),
                          DataCell(OrganizerMoneyText(minor: e.revenueMinor, compact: true)),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton(
                                  onPressed: () => context.push('/organizer/events/${e.id}'),
                                  child: const Text('Open'),
                                ),
                                IconButton(
                                  tooltip: 'Duplicate',
                                  icon: const Icon(Icons.copy_outlined, size: 20),
                                  onPressed: () {
                                    duplicateOrganizerEvent(ref, e);
                                    context.push('/organizer/events/new');
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => _errorCard(context, e, () => ref.invalidate(organizerEventsProvider)),
              ),
            ),
          ],
        ),
    );
  }

  Widget _errorCard(BuildContext context, Object e, VoidCallback onRetry) {
    return EosSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Something went wrong', style: context.eosText.titleSmall),
          SizedBox(height: context.eos.spacing.xs),
          Text('$e', style: context.eosText.bodySmall),
          SizedBox(height: context.eos.spacing.sm),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }

  int _tabForAttention(OrganizerAttentionType type) => switch (type) {
        OrganizerAttentionType.pendingVendorApproval => 3,
        OrganizerAttentionType.lowTicketSales => 1,
        OrganizerAttentionType.refundRequest => 4,
        OrganizerAttentionType.unpublishedDraft => 0,
      };
}

/// Thin portfolio finance KPIs — deep-links into Events (open event → Finance tab).
class _OrganizerFinanceHubStrip extends ConsumerWidget {
  const _OrganizerFinanceHubStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hub = ref.watch(organizerFinanceHubProvider);
    final events = ref.watch(organizerEventsProvider);

    return EosSection(
      title: 'Finance overview',
      subtitle: 'Portfolio KPIs — open an event Finance tab for detail',
      trailing: TextButton(
        onPressed: () => ref.read(organizerShellTabProvider.notifier).select(1),
        child: const Text('Events'),
      ),
      child: hub.when(
        loading: () => const LinearProgressIndicator(minHeight: 2),
        error: (e, _) => EosSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Finance hub unavailable', style: context.eosText.titleSmall),
              Text('$e', style: context.eosText.bodySmall),
              TextButton(
                onPressed: () => ref.invalidate(organizerFinanceHubProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (h) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: context.eos.spacing.md,
              runSpacing: context.eos.spacing.md,
              children: [
                SizedBox(
                  width: 200,
                  child: EosKpiCard(
                    title: 'Gross',
                    value: formatRevenue(int.tryParse(h.grossCollectedMinor) ?? 0),
                    icon: Icons.trending_up,
                    onTap: () => ref.read(organizerShellTabProvider.notifier).select(1),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: EosKpiCard(
                    title: 'Available payout',
                    value: formatRevenue(int.tryParse(h.availableForPayoutMinor) ?? 0),
                    icon: Icons.payments_outlined,
                    onTap: () => ref.read(organizerShellTabProvider.notifier).select(1),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: EosKpiCard(
                    title: 'In escrow',
                    value: formatRevenue(int.tryParse(h.heldInEscrowMinor) ?? 0),
                    icon: Icons.lock_clock_outlined,
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: EosKpiCard(
                    title: 'Open refunds',
                    value: '${h.openRefundRequests}',
                    icon: Icons.undo_outlined,
                    attention: h.openRefundRequests > 0 ? EosKpiAttention.warning : EosKpiAttention.none,
                    onTap: () => ref.read(organizerShellTabProvider.notifier).select(1),
                  ),
                ),
              ],
            ),
            SizedBox(height: context.eos.spacing.sm),
            events.when(
              data: (list) {
                final live = list
                    .where((e) =>
                        e.status == OrganizerEventStatus.live ||
                        e.status == OrganizerEventStatus.published)
                    .take(3)
                    .toList();
                if (live.isEmpty) {
                  return Text(
                    'Publish an event, then open its Finance tab for orders, refunds, and payouts.',
                    style: context.eosText.bodySmall,
                  );
                }
                return Wrap(
                  spacing: context.eos.spacing.sm,
                  children: [
                    for (final e in live)
                      ActionChip(
                        label: Text('${e.title} · Finance'),
                        onPressed: () => context.push(EventRouteRegistry.event(e.id)),
                      ),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Portfolio comparison — deep-links into Event Workspace (Analytics tab).
class _OrganizerAnalyticsPortfolioStrip extends ConsumerWidget {
  const _OrganizerAnalyticsPortfolioStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final portfolio = ref.watch(organizerAnalyticsPortfolioProvider);

    return EosSection(
      title: 'Portfolio analytics',
      subtitle: 'Event comparison from canonical sales and check-ins — open workspace Analytics',
      trailing: TextButton(
        onPressed: () => ref.read(organizerShellTabProvider.notifier).select(5),
        child: const Text('Analytics'),
      ),
      child: portfolio.when(
        loading: () => const LinearProgressIndicator(minHeight: 2),
        error: (e, _) => EosSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Portfolio analytics unavailable', style: context.eosText.titleSmall),
              Text('$e', style: context.eosText.bodySmall),
              TextButton(
                onPressed: () => ref.invalidate(organizerAnalyticsPortfolioProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return EosSurfaceCard(
              child: Text(
                'No events yet — create and sell tickets to see portfolio comparison.',
                style: context.eosText.bodyMedium,
              ),
            );
          }
          return EosDataTable(
            columns: const [
              DataColumn(label: Text('Event')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Sold')),
              DataColumn(label: Text('Revenue')),
              DataColumn(label: Text('Attendance')),
              DataColumn(label: Text('')),
            ],
            rows: items.take(8).map((e) {
              return DataRow(
                cells: [
                  DataCell(Text(e.title, style: context.eosText.titleSmall)),
                  DataCell(EosFinanceChip(label: e.status, compact: true)),
                  DataCell(Text('${e.ticketsSold}')),
                  DataCell(Text(formatRevenue(e.revenueMinor))),
                  DataCell(Text('${e.attendancePct.toStringAsFixed(1)}%')),
                  DataCell(
                    TextButton(
                      onPressed: () => context.push(EventRouteRegistry.event(e.eventId)),
                      child: const Text('Analytics'),
                    ),
                  ),
                ],
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

/// Thin CRM rollup — deep-links into Event Workspace Vendors (no duplicate CRM).
class _OrganizerVendorCrmStrip extends ConsumerWidget {
  const _OrganizerVendorCrmStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(organizerEventsProvider);
    final alerts = ref.watch(organizerVendorCrmAlertsProvider);

    return EosSection(
      title: 'Vendor CRM',
      subtitle: 'Pipeline summary — open an event Workspace Vendors tab for detail',
      trailing: TextButton(
        onPressed: () => ref.read(organizerShellTabProvider.notifier).select(3),
        child: const Text('Vendors'),
      ),
      child: events.when(
        loading: () => const LinearProgressIndicator(minHeight: 2),
        error: (e, _) => EosSurfaceCard(child: Text('$e')),
        data: (list) {
          if (list.isEmpty) {
            return EosSurfaceCard(
              child: Text('Create an event, then hire vendors from Marketplace.', style: context.eosText.bodyMedium),
            );
          }
          final alertCount = alerts.valueOrNull?.length ?? 0;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: context.eos.spacing.md,
                runSpacing: context.eos.spacing.md,
                children: [
                  SizedBox(
                    width: 200,
                    child: EosKpiCard(
                      title: 'Events',
                      value: '${list.length}',
                      icon: Icons.celebration_outlined,
                      onTap: () => ref.read(organizerShellTabProvider.notifier).select(1),
                    ),
                  ),
                  SizedBox(
                    width: 200,
                    child: EosKpiCard(
                      title: 'CRM alerts',
                      value: '$alertCount',
                      icon: Icons.handshake_outlined,
                      attention: alertCount > 0 ? EosKpiAttention.warning : EosKpiAttention.none,
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.eos.spacing.sm),
              Wrap(
                spacing: context.eos.spacing.sm,
                children: [
                  for (final e in list.take(4))
                    ActionChip(
                      label: Text('${e.title} · Vendors'),
                      onPressed: () => context.push(EventRouteRegistry.event(e.id)),
                    ),
                  ActionChip(
                    label: const Text('Marketplace'),
                    onPressed: () => context.push(CustomerRoutes.vendors),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
