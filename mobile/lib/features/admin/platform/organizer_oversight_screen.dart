import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money.dart';
import '../../../eos/eos.dart';
import 'admin_platform_providers.dart';

class OrganizerOversightScreen extends ConsumerWidget {
  const OrganizerOversightScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(adminPlatformRevisionProvider);
    final query = ref.watch(adminOrganizerSearchProvider);
    final list = ref.watch(adminOrganizersProvider(query));
    final selected = ref.watch(selectedAdminOrganizerIdProvider);
    final detail = selected == null ? null : ref.watch(adminOrganizerDetailProvider(selected));

    return EosPageScaffold(
      title: 'Organizer oversight',
      subtitle: 'Search, review, and manage organizer accounts',
      floatingHeader: EosSearchField(
        hint: 'Search organizers…',
        onChanged: (v) => ref.read(adminOrganizerSearchProvider.notifier).state = v,
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: list.when(
              data: (items) => EosDataTable(
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
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('$e'),
            ),
          ),
          SizedBox(width: context.eos.spacing.lg),
          Expanded(
            child: selected == null
                ? EosSurfaceCard(child: Text('Select an organizer', style: context.eosText.bodyMedium))
                : detail!.when(
                    data: (d) => _OrganizerDetailPanel(organizerId: selected, data: d),
                    loading: () => const CircularProgressIndicator(),
                    error: (e, _) => Text('$e'),
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
