import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../eos/eos.dart';
import '../widgets/admin_async_body.dart';
import '../widgets/admin_error_states.dart';
import '../widgets/admin_page_layout.dart';
import 'admin_platform_providers.dart';

class EventOversightScreen extends ConsumerWidget {
  const EventOversightScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(adminPlatformRevisionProvider);
    final query = ref.watch(adminEventSearchProvider);
    final list = ref.watch(adminEventsProvider(query));
    final selected = ref.watch(selectedAdminEventIdProvider);
    final detail = selected == null ? null : ref.watch(adminEventDetailProvider(selected));

    return AdminPageLayout(
      title: 'Events',
      subtitle: 'Monitor events, health, and force-close when needed',
      header: EosSearchField(
        hint: 'Search events…',
        onChanged: (v) => ref.read(adminEventSearchProvider.notifier).state = v,
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: AdminAsyncBody(
              value: list,
              onRetry: () => ref.invalidate(adminEventsProvider(query)),
              builder: (items) => EosDataTable(
                columns: const [
                  DataColumn(label: Text('Event')),
                  DataColumn(label: Text('Organizer')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Sold')),
                ],
                rows: items.map((e) {
                  final id = e['id'] as String;
                  return DataRow(
                    selected: selected == id,
                    onSelectChanged: (_) => ref.read(selectedAdminEventIdProvider.notifier).state = id,
                    cells: [
                      DataCell(Text(e['title'] as String? ?? '')),
                      DataCell(Text(e['organizerName'] as String? ?? '')),
                      DataCell(EosFinanceChip(label: e['status'] as String? ?? '', compact: true)),
                      DataCell(Text('${e['ticketsSold']}')),
                    ],
                  );
                }).toList(),
              ),
              isEmpty: (items) => items.isEmpty,
              empty: const EmptyStateCard(title: 'No events found'),
            ),
          ),
          SizedBox(width: context.eos.spacing.lg),
          Expanded(
            child: selected == null
                ? const EmptyStateCard(title: 'Select an event')
                : AdminAsyncBody(
                    value: detail!,
                    onRetry: () => ref.invalidate(adminEventDetailProvider(selected)),
                    builder: (d) => _EventDetailPanel(eventId: selected, data: d),
                  ),
          ),
        ],
      ),
    );
  }
}

class _EventDetailPanel extends ConsumerWidget {
  const _EventDetailPanel({required this.eventId, required this.data});
  final String eventId;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = data['overview'] as Map<String, dynamic>? ?? {};
    final health = data['health'] as Map<String, dynamic>? ?? {};
    final finance = data['finance'] as Map<String, dynamic>? ?? {};
    final ops = data['operations'] as Map<String, dynamic>? ?? {};
    final vendors = (data['vendors'] as List<dynamic>? ?? []).length;
    final attendees = (data['attendees'] as List<dynamic>? ?? []).length;
    return EosSurfaceCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(overview['title'] as String? ?? '', style: context.eosText.titleLarge),
          EosAttentionBanner(
            headline: 'Health: ${health['level'] ?? 'unknown'}',
            message: health['summary'] as String? ?? '',
            severity: health['level'] == 'critical' ? 'CRITICAL' : health['level'] == 'warning' ? 'WARNING' : 'INFO',
          ),
          SizedBox(height: context.eos.spacing.sm),
          Text('Finance · ${finance['fulfilledOrders']} orders', style: context.eosText.bodySmall),
          Text('Operations · ${ops['checkedIn']}/${ops['registered']} checked in', style: context.eosText.bodySmall),
          Text('Vendors: $vendors · Attendees: $attendees', style: context.eosText.bodySmall),
          SizedBox(height: context.eos.spacing.md),
          if (overview['status'] != 'completed' && overview['status'] != 'cancelled')
            FilledButton(
              onPressed: () async {
                await ref.read(adminPlatformApiProvider).forceCloseEvent(eventId);
                bumpAdminPlatformRevision(ref);
              },
              child: const Text('Force close event'),
            ),
        ],
      ),
    );
  }
}
