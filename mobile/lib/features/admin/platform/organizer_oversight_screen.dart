import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money.dart';
import '../../../eos/eos.dart';
import 'admin_platform_providers.dart';
import '../widgets/admin_async_body.dart';
import '../widgets/admin_error_states.dart';
import '../widgets/admin_page_layout.dart';

class OrganizerOversightScreen extends ConsumerWidget {
  const OrganizerOversightScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(adminPlatformRevisionProvider);
    final query = ref.watch(adminOrganizerSearchProvider);
    final list = ref.watch(adminOrganizersProvider(query));
    final selected = ref.watch(selectedAdminOrganizerIdProvider);
    final detail = selected == null ? null : ref.watch(adminOrganizerDetailProvider(selected));

    return AdminPageLayout(
      title: 'Tenants',
      subtitle: 'Search, review, and manage organizer accounts',
      header: EosSearchField(
        hint: 'Search organizers…',
        onChanged: (v) => ref.read(adminOrganizerSearchProvider.notifier).state = v,
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: AdminAsyncBody(
              value: list,
              onRetry: () => ref.invalidate(adminOrganizersProvider(query)),
              builder: (items) => EosDataTable(
                columns: const [
                  DataColumn(label: Text('Organizer')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Events')),
                  DataColumn(label: Text('Revenue')),
                ],
                rows: items.map((o) {
                  final id = o['id'] as String;
                  return DataRow(
                    selected: selected == id,
                    onSelectChanged: (_) => ref.read(selectedAdminOrganizerIdProvider.notifier).state = id,
                    cells: [
                      DataCell(Text(o['displayName'] as String? ?? '')),
                      DataCell(EosFinanceChip(label: o['status'] as String? ?? '', compact: true)),
                      DataCell(Text('${o['eventCount']}')),
                      DataCell(Text(formatRevenue(int.tryParse((o['revenueMinor'] ?? '0').toString()) ?? 0))),
                    ],
                  );
                }).toList(),
              ),
              isEmpty: (items) => items.isEmpty,
              empty: const EmptyStateCard(title: 'No organizers found'),
            ),
          ),
          SizedBox(width: context.eos.spacing.lg),
          Expanded(
            child: selected == null
                ? const EmptyStateCard(title: 'Select a tenant', message: 'Choose an organizer from the list to view details.')
                : AdminAsyncBody(
                    value: detail!,
                    onRetry: () => ref.invalidate(adminOrganizerDetailProvider(selected)),
                    builder: (d) => _OrganizerDetailPanel(organizerId: selected, data: d),
                  ),
          ),
        ],
      ),
    );
  }
}

class _OrganizerDetailPanel extends ConsumerWidget {
  const _OrganizerDetailPanel({required this.organizerId, required this.data});
  final String organizerId;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = data['profile'] as Map<String, dynamic>? ?? {};
    final events = (data['events'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final revenue = data['revenue'] as Map<String, dynamic>? ?? {};
    return EosSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(profile['displayName'] as String? ?? '', style: context.eosText.titleLarge),
          SizedBox(height: context.eos.spacing.xs),
          EosFinanceChip(label: profile['status'] as String? ?? '', compact: true),
          SizedBox(height: context.eos.spacing.md),
          Text('Revenue: ${formatRevenue(int.tryParse((revenue['totalMinor'] ?? '0').toString()) ?? 0)}', style: context.eosText.bodyMedium),
          Text('Ticket rail: ${formatRevenue(int.tryParse((revenue['ticketRevenueMinor'] ?? '0').toString()) ?? 0)}', style: context.eosText.labelSmall),
          SizedBox(height: context.eos.spacing.md),
          Text('Events (${events.length})', style: context.eosText.titleSmall),
          for (final e in events.take(5))
            ListTile(
              dense: true,
              title: Text(e['title'] as String? ?? ''),
              subtitle: Text(e['status'] as String? ?? ''),
            ),
          SizedBox(height: context.eos.spacing.sm),
          Wrap(
            spacing: context.eos.spacing.xs,
            children: [
              if (profile['status'] == 'active')
                FilledButton(
                  onPressed: () async {
                    await ref.read(adminPlatformApiProvider).suspendOrganizer(organizerId);
                    bumpAdminPlatformRevision(ref);
                  },
                  child: const Text('Suspend'),
                ),
              if (profile['status'] == 'suspended')
                FilledButton(
                  onPressed: () async {
                    await ref.read(adminPlatformApiProvider).reactivateOrganizer(organizerId);
                    bumpAdminPlatformRevision(ref);
                  },
                  child: const Text('Reactivate'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
