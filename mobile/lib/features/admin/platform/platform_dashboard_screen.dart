import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money.dart';
import '../../../eos/eos.dart';
import '../finance/admin_finance_providers.dart';
import '../platform/admin_platform_providers.dart';
import '../widgets/admin_async_body.dart';
import '../widgets/admin_error_states.dart';
import '../widgets/admin_line_chart.dart';
import '../widgets/admin_page_layout.dart';
import '../widgets/admin_timeline_table.dart';

class PlatformDashboardScreen extends ConsumerWidget {
  const PlatformDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(adminPlatformRevisionProvider);
    final dash = ref.watch(platformDashboardProvider);
    final events = ref.watch(adminEventsProvider(''));
    final vendors = ref.watch(adminVendorsProvider(''));
    final audit = ref.watch(adminAuditProvider('all'));
    final alerts = ref.watch(adminAlertsProvider);

    return AdminPageLayout(
      title: 'Platform dashboard',
      subtitle: 'Executive operational KPIs across Owanbe',
      body: AdminAsyncBody(
        value: dash,
        onRetry: () => ref.invalidate(platformDashboardProvider),
        skeletonCount: 6,
        builder: (d) {
          final health = (d['platformHealth'] ?? 'healthy').toString();
          final revenueMinor = int.tryParse((d['revenueMinor'] ?? '0').toString()) ?? 0;
          final openIncidents = (d['openIncidents'] as num? ?? 0).toInt();
          final reconIssues = (d['reconciliationIssues'] as num? ?? 0).toInt();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EosAttentionBanner(
                headline: 'System health · ${health.toUpperCase()}',
                message: (d['healthSummary'] ?? 'Platform operating normally.').toString(),
                severity: health == 'critical' ? 'CRITICAL' : health == 'warning' ? 'WARNING' : 'INFO',
              ),
              SizedBox(height: context.eos.spacing.lg),
              AdminSectionHeader(title: 'Key metrics', subtitle: 'Live platform snapshot'),
              AdminKpiGrid(
                children: [
                  _kpi(context, 'Total events', '${(d['activeEvents'] as num? ?? 0) + (d['liveEvents'] as num? ?? 0)}', Icons.celebration_outlined),
                  _kpi(context, 'Active vendors', '${d['vendors']}', Icons.storefront_outlined),
                  _kpi(context, 'Revenue', formatRevenue(revenueMinor), Icons.payments_outlined),
                  _kpi(context, 'Disputes', '$openIncidents', Icons.report_problem_outlined, attention: openIncidents > 0 ? EosKpiAttention.warning : EosKpiAttention.none),
                  _kpi(context, 'Active tenants', '${d['organizers']}', Icons.apartment_outlined),
                  _kpi(context, 'System health', health.toUpperCase(), Icons.monitor_heart_outlined, attention: health == 'critical' ? EosKpiAttention.critical : health == 'warning' ? EosKpiAttention.warning : EosKpiAttention.none),
                ],
              ),
              SizedBox(height: context.eos.spacing.xl),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 960;
                  final chart = AdminLineChart(
                    label: 'Revenue trend (7d)',
                    points: syntheticTrend(revenueMinor > 0 ? revenueMinor / 100 : 1000),
                    color: EosColors.plum,
                  );
                  if (!wide) {
                    return Column(
                      children: [
                        chart,
                        SizedBox(height: context.eos.spacing.lg),
                        _alertsSection(context, ref, alerts, openIncidents, reconIssues),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: chart),
                      SizedBox(width: context.eos.spacing.lg),
                      Expanded(flex: 2, child: _alertsSection(context, ref, alerts, openIncidents, reconIssues)),
                    ],
                  );
                },
              ),
              SizedBox(height: context.eos.spacing.xl),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 960;
                  final eventsPanel = _eventsPanel(context, events);
                  final vendorsPanel = _vendorsPanel(context, vendors);
                  if (!wide) {
                    return Column(
                      children: [
                        eventsPanel,
                        SizedBox(height: context.eos.spacing.lg),
                        vendorsPanel,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: eventsPanel),
                      SizedBox(width: context.eos.spacing.lg),
                      Expanded(child: vendorsPanel),
                    ],
                  );
                },
              ),
              SizedBox(height: context.eos.spacing.xl),
              AdminSectionHeader(title: 'Audit feed', subtitle: 'Latest platform actions'),
              AdminAsyncBody(
                value: audit,
                onRetry: () => ref.invalidate(adminAuditProvider('all')),
                skeletonCount: 1,
                isEmpty: (items) => items.isEmpty,
                empty: const EmptyStateCard(title: 'No audit events yet'),
                builder: (items) => AdminTimelineTable(
                  items: items.take(8).map(timelineRowFromAudit).toList(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _kpi(BuildContext context, String title, String value, IconData icon, {EosKpiAttention attention = EosKpiAttention.none}) {
    return EosKpiCard(title: title, value: value, icon: icon, attention: attention);
  }

  Widget _alertsSection(
    BuildContext context,
    WidgetRef ref,
    AsyncValue alerts,
    int openIncidents,
    int reconIssues,
  ) {
    return EosSurfaceCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Alerts center', style: context.eosText.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          SizedBox(height: context.eos.spacing.md),
          _alertRow(context, 'Critical', openIncidents, EosColors.critical),
          _alertRow(context, 'Warning', reconIssues, EosColors.warning),
          alerts.when(
            data: (items) => _alertRow(context, 'Info', items.length, context.eosColors.primary),
            loading: () => const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
            error: (_, _) => _alertRow(context, 'Info', 0, context.eosColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _alertRow(BuildContext context, String label, int count, Color color) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          SizedBox(width: context.eos.spacing.sm),
          Expanded(child: Text(label, style: context.eosText.bodyMedium)),
          Text('$count', style: context.eosText.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _eventsPanel(BuildContext context, AsyncValue<List<Map<String, dynamic>>> events) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AdminSectionHeader(title: 'Event activity', subtitle: 'Recent events on the platform'),
        AdminAsyncBody(
          value: events,
          skeletonCount: 1,
          isEmpty: (items) => items.isEmpty,
          empty: const EmptyStateCard(title: 'No events yet'),
          builder: (items) => EosSurfaceCard(
            elevated: true,
            child: Column(
              children: [
                for (final e in items.take(6))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: context.eosColors.primaryContainer,
                      child: const Icon(Icons.celebration_outlined, size: 18),
                    ),
                    title: Text(e['title'] as String? ?? 'Event', style: context.eosText.bodyMedium),
                    subtitle: Text('${e['organizerName'] ?? 'Organizer'} · ${e['status'] ?? ''}', style: context.eosText.bodySmall),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _vendorsPanel(BuildContext context, AsyncValue<List<Map<String, dynamic>>> vendors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AdminSectionHeader(title: 'Vendor activity', subtitle: 'Latest vendor onboarding'),
        AdminAsyncBody(
          value: vendors,
          skeletonCount: 1,
          isEmpty: (items) => items.isEmpty,
          empty: const EmptyStateCard(title: 'No vendors yet'),
          builder: (items) => EosSurfaceCard(
            elevated: true,
            child: Column(
              children: [
                for (final v in items.take(6))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: context.eosColors.secondaryContainer,
                      child: const Icon(Icons.storefront_outlined, size: 18),
                    ),
                    title: Text(v['businessName'] as String? ?? 'Vendor', style: context.eosText.bodyMedium),
                    subtitle: Text('${v['category'] ?? ''} · ${v['status'] ?? ''}', style: context.eosText.bodySmall),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
