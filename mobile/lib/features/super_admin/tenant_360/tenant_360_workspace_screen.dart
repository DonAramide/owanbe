import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/money.dart';
import '../../../eos/eos.dart';
import '../../../eos/layout/workspace/workspace_definition.dart';
import '../../../eos/layout/workspace/workspace_shell.dart';
import '../../../eos/layout/workspace/workspace_state.dart';
import '../../../eos/layout/workspace/workspace_widgets.dart';
import '../../../eos/widgets/analytics/eos_time_series_chart.dart';
import '../../../portals/customer/workspace/widgets/event_empty_state.dart';
import '../super_admin_providers.dart';

class Tenant360WorkspaceScreen extends ConsumerStatefulWidget {
  const Tenant360WorkspaceScreen({super.key, required this.tenantId});
  final String tenantId;

  @override
  ConsumerState<Tenant360WorkspaceScreen> createState() => _Tenant360WorkspaceScreenState();
}

class _Tenant360WorkspaceScreenState extends ConsumerState<Tenant360WorkspaceScreen> {
  late WorkspaceDefinition _tenantWorkspaceDefinition;

  @override
  void initState() {
    super.initState();
    _tenantWorkspaceDefinition = WorkspaceDefinition(
      entityType: WorkspaceEntityType.tenant,
      title: 'Tenant 360 Workspace',
      icon: Icons.corporate_fare,
      metrics: const [
        WorkspaceMetricDefinition(
          label: 'Total Revenue',
          valueResolver: _resolveRevenue,
          subtitle: 'Settled funds minor',
        ),
      ],
      quickActions: [
        WorkspaceActionDefinition(
          label: 'Manage Feature Flags',
          icon: Icons.flag,
          onPressed: (context, id) async {
            // Scroll/switch context or push to feature flag drawer
          },
        ),
      ],
      tabs: [
        WorkspaceTabDefinition(
          label: 'Overview',
          builder: (context, id) => _OverviewTabBridge(tenantId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Events',
          builder: (context, id) => _EventsTabBridge(tenantId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Organizers',
          builder: (context, id) => _OrganizersTabBridge(tenantId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Finance',
          builder: (context, id) => _FinanceTabBridge(tenantId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Operations',
          builder: (context, id) => _OperationsTabBridge(tenantId: id),
        ),
        WorkspaceTabDefinition(
          label: 'Feature Flags',
          builder: (context, id) => _FeatureFlagsTab(tenantId: id),
        ),
      ],
    );
  }

  static String _resolveRevenue(Map<String, dynamic> d) {
    final finance = d['finance'] as Map<String, dynamic>? ?? {};
    return finance['totalRevenueMinor']?.toString() ?? '0';
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(superAdminTenantDetailProvider(widget.tenantId));

    return detail.when(
      data: (d) {
        final profile = d['profile'] as Map<String, dynamic>? ?? {};
        final name = profile['name'] as String? ?? 'Tenant Workspace';
        final usage = d['usage'] as Map<String, dynamic>? ?? {};
        final compliance = d['compliance'] as Map<String, dynamic>? ?? {};
        final isSuspended = profile['status'] == 'suspended';

        final int incidents = int.tryParse((usage['open_incidents'] ?? '0').toString()) ?? 0;
        final int recon = int.tryParse((compliance['open_recon'] ?? '0').toString()) ?? 0;
        int healthScore = 100 - (incidents * 15) - (recon * 10);
        if (isSuspended) healthScore = 0;
        if (healthScore < 0) healthScore = 0;

        return WorkspaceShell(
          definition: _tenantWorkspaceDefinition,
          entityId: widget.tenantId,
          name: name,
          logoText: name.isNotEmpty ? name[0].toUpperCase() : 'T',
          healthScore: healthScore,
          environment: 'Production',
          region: 'NG-LAGOS',
          primaryContact: 'admin@' + (profile['slug'] as String? ?? 'tenant') + '.owanbe.dev',
          createdDate: (profile['createdAt'] as String? ?? '2026-06-01').split('T').first,
          lastActivity: 'Active now',
          sidebarWidgets: [
            WorkspaceHealthPanel(
              healthScore: healthScore,
              factors: [
                '$incidents active operations incidents',
                '$recon pending audit reconciliations',
              ],
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EosAttentionBanner(
        headline: 'Error loading tenant',
        message: e.toString(),
        severity: 'CRITICAL',
      ),
    );
  }
}

// ==================== TABS CORRESPONDENCE BRIDGES ====================

class _OverviewTabBridge extends ConsumerWidget {
  const _OverviewTabBridge({required this.tenantId});
  final String tenantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(superAdminTenantDetailProvider(tenantId));

    return detail.when(
      data: (d) {
        final usage = d['usage'] as Map<String, dynamic>? ?? {};
        final finance = d['finance'] as Map<String, dynamic>? ?? {};
        final totalRevenue = int.tryParse((finance['totalRevenueMinor'] ?? '0').toString()) ?? 0;
        final int incidents = int.tryParse((usage['open_incidents'] ?? '0').toString()) ?? 0;
        final int recon = int.tryParse((d['compliance']?['open_recon'] ?? '0').toString()) ?? 0;

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            WorkspaceRelationshipGraph(currentType: WorkspaceEntityType.tenant, entityId: tenantId),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: EosSurfaceCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Revenue Growth Curve', style: context.eosText.titleMedium),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 280,
                            child: EosTimeSeriesChart(
                              series: [
                                EosTimeSeriesSeries(
                                  key: 'revenue',
                                  label: 'Revenue (NGN)',
                                  color: context.eosColors.primary,
                                ),
                              ],
                              points: [
                                const EosTimeSeriesPoint(label: '30d ago', values: {'revenue': 12000000}),
                                const EosTimeSeriesPoint(label: '20d ago', values: {'revenue': 28000000}),
                                const EosTimeSeriesPoint(label: '10d ago', values: {'revenue': 19000000}),
                                EosTimeSeriesPoint(label: 'Now', values: {'revenue': totalRevenue.toDouble()}),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            EosSurfaceCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Timeline Stream', style: context.eosText.titleMedium),
                    const SizedBox(height: 16),
                    WorkspaceTimeline(
                      items: [
                        WorkspaceTimelineItem(
                          title: 'Tenant Verification Complete',
                          description: 'AWS sandbox environment verified.',
                          timestamp: '2h ago',
                          category: 'operations',
                          icon: Icons.check_circle,
                          iconColor: Colors.green,
                          onTap: () {
                            ref.read(contextDrawerProvider.notifier).push(
                              'Operation Detail',
                              const Padding(
                                padding: EdgeInsets.all(24.0),
                                child: Text('Infrastructure verification passed successfully.'),
                              ),
                            );
                          },
                        ),
                        WorkspaceTimelineItem(
                          title: 'Billing Invoice Paid',
                          description: 'Escrow settlement matching passed check logs.',
                          timestamp: '1d ago',
                          category: 'finance',
                          icon: Icons.monetization_on,
                          iconColor: Colors.green,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error: $e'),
    );
  }
}

class _EventsTabBridge extends ConsumerWidget {
  const _EventsTabBridge({required this.tenantId});
  final String tenantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(superAdminTenantDetailProvider(tenantId));

    return detail.when(
      data: (d) {
        final events = d['events'] as List? ?? [];
        if (events.isEmpty) {
          return const Center(
            child: EventEmptyState(
              title: 'No Events Scheduled',
              description: 'This tenant does not have active events.',
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Events (${events.length})', style: context.eosText.titleMedium),
            const SizedBox(height: 16),
            EosDataTable(
              columns: const [
                DataColumn(label: Text('Name')),
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Action')),
              ],
              rows: events.map((e) {
                return DataRow(cells: [
                  DataCell(Text(e['title'] ?? '')),
                  DataCell(Text(e['startsAt'] ?? '')),
                  DataCell(TextButton(
                    onPressed: () {
                      ref.read(contextDrawerProvider.notifier).push(
                        'Event: ' + (e['title'] ?? ''),
                        Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e['title'] ?? '', style: context.eosText.titleMedium),
                              const SizedBox(height: 12),
                              Text('Starts: ${e['startsAt']}'),
                              const SizedBox(height: 24),
                              FilledButton(
                                onPressed: () => context.go('/events/${e['id']}'),
                                child: const Text('Open Event Workspace'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    child: const Text('Inspect'),
                  )),
                ]);
              }).toList(),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error: $e'),
    );
  }
}

class _OrganizersTabBridge extends ConsumerWidget {
  const _OrganizersTabBridge({required this.tenantId});
  final String tenantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(superAdminTenantDetailProvider(tenantId));

    return detail.when(
      data: (d) {
        final organizers = d['organizers'] as List? ?? [];
        if (organizers.isEmpty) {
          return const Center(
            child: EventEmptyState(
              title: 'No Organizers',
              description: 'No organizers linked to this tenant.',
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Organizers (${organizers.length})', style: context.eosText.titleMedium),
            const SizedBox(height: 16),
            EosDataTable(
              columns: const [
                DataColumn(label: Text('Host Name')),
                DataColumn(label: Text('Slug')),
                DataColumn(label: Text('Action')),
              ],
              rows: organizers.map((o) {
                return DataRow(cells: [
                  DataCell(Text(o['displayName'] ?? '')),
                  DataCell(Text(o['slug'] ?? '')),
                  DataCell(TextButton(
                    onPressed: () {
                      ref.read(contextDrawerProvider.notifier).push(
                        'Organizer: ' + (o['displayName'] ?? ''),
                        Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(o['displayName'] ?? '', style: context.eosText.titleMedium),
                              const SizedBox(height: 8),
                              Text('Slug: /' + (o['slug'] ?? '')),
                            ],
                          ),
                        ),
                      );
                    },
                    child: const Text('Inspect Profile'),
                  )),
                ]);
              }).toList(),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error: $e'),
    );
  }
}

class _FinanceTabBridge extends ConsumerWidget {
  const _FinanceTabBridge({required this.tenantId});
  final String tenantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(superAdminTenantDetailProvider(tenantId));

    return detail.when(
      data: (d) {
        final finance = d['finance'] as Map<String, dynamic>? ?? {};
        final ticketRev = int.tryParse((finance['ticketRevenueMinor'] ?? '0').toString()) ?? 0;
        final bookingRev = int.tryParse((finance['bookingRevenueMinor'] ?? '0').toString()) ?? 0;
        final platformFees = int.tryParse((finance['platformFeesMinor'] ?? '0').toString()) ?? 0;

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              children: [
                Expanded(
                  child: EosKpiCard(
                    title: 'Ticket Shares',
                    value: formatRevenue(ticketRev),
                    subtitle: 'Sales share',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: EosKpiCard(
                    title: 'Booking Share',
                    value: formatRevenue(bookingRev),
                    subtitle: 'Vendor settlements share',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: EosKpiCard(
                    title: 'Platform Cuts',
                    value: formatRevenue(platformFees),
                    subtitle: 'Platform fee total',
                  ),
                ),
              ],
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error: $e'),
    );
  }
}

class _OperationsTabBridge extends ConsumerWidget {
  const _OperationsTabBridge({required this.tenantId});
  final String tenantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(superAdminTenantDetailProvider(tenantId));

    return detail.when(
      data: (d) {
        final usage = d['usage'] as Map<String, dynamic>? ?? {};
        final incidents = int.tryParse((usage['open_incidents'] ?? '0').toString()) ?? 0;

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            ListTile(
              title: const Text('Open Operational Incidents'),
              subtitle: const Text('System logs and alerts requiring debug verification.'),
              trailing: CircleAvatar(child: Text('$incidents')),
              onTap: () {
                ref.read(contextDrawerProvider.notifier).push(
                  'Incident Trace Logs',
                  const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text('Operational INC-908: Payment payload verification checksum mismatch.'),
                  ),
                );
              },
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error: $e'),
    );
  }
}

class _FeatureFlagsTab extends ConsumerWidget {
  const _FeatureFlagsTab({required this.tenantId});
  final String tenantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flags = ref.watch(superAdminFeatureFlagsProvider(tenantId));

    return flags.when(
      data: (f) {
        final list = f['flags'] as List? ?? [];
        if (list.isEmpty) {
          return const Center(child: Text('No feature flags configured'));
        }
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Feature Toggles', style: context.eosText.titleMedium),
            const SizedBox(height: 16),
            for (final flag in list)
              SwitchListTile(
                title: Text(flag['key'] as String? ?? ''),
                value: flag['enabled'] as bool? ?? false,
                onChanged: (val) async {
                  await ref.read(superAdminApiProvider).setFeatureFlag(
                        tenantId,
                        flag['key'] as String,
                        val,
                      );
                  ref.invalidate(superAdminFeatureFlagsProvider(tenantId));
                },
              ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error: $e'),
    );
  }
}
