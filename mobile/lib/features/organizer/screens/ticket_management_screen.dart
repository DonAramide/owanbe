import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/money.dart';
import '../../../eos/eos.dart';
import '../data/organizer_event_store.dart';
import '../models/organizer_models.dart';
import '../providers/organizer_providers.dart';
import '../widgets/organizer_shared.dart';

class TicketManagementScreen extends ConsumerWidget {
  const TicketManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventId = ref.watch(selectedOrganizerEventIdProvider);
    final eventAsync = eventId == null ? null : ref.watch(organizerEventProvider(eventId));

    return EosPageScaffold(
      title: 'Ticket management',
      subtitle: 'Pricing, capacity, sales windows, and visibility',
      actions: [
        if (eventId != null)
          FilledButton.icon(
            onPressed: () => context.push('/organizer/events/$eventId?tab=1'),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('Workspace'),
          ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const OrganizerEventPicker(),
          SizedBox(height: context.eos.spacing.lg),
          if (eventId == null)
            EosSurfaceCard(child: Text('Select an event', style: context.eosText.bodyMedium))
          else
            eventAsync!.when(
              data: (event) {
                if (event == null) return const Text('Event not found');
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: context.eos.spacing.md,
                      runSpacing: context.eos.spacing.md,
                      children: [
                        SizedBox(
                          width: 220,
                          child: EosKpiCard(
                            title: 'Sold',
                            value: '${event.ticketsSold}',
                            subtitle: 'of ${event.totalCapacity} capacity',
                            icon: Icons.confirmation_number_outlined,
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: EosKpiCard(
                            title: 'Revenue',
                            value: formatRevenue(event.revenueMinor),
                            icon: Icons.payments_outlined,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: context.eos.spacing.lg),
                    EosDataTable(
                      columns: const [
                        DataColumn(label: Text('Tier')),
                        DataColumn(label: Text('Type')),
                        DataColumn(label: Text('Price')),
                        DataColumn(label: Text('Sold')),
                        DataColumn(label: Text('Remaining')),
                        DataColumn(label: Text('Window')),
                        DataColumn(label: Text('Visibility')),
                        DataColumn(label: Text('Status')),
                      ],
                      rows: event.ticketTiers.map((t) {
                        final sold = t.capacity - t.remaining;
                        final window = t.salesWindowStart == null
                            ? '—'
                            : '${t.salesWindowStart!.month}/${t.salesWindowStart!.day}–${t.salesWindowEnd?.month}/${t.salesWindowEnd?.day}';
                        return DataRow(
                          cells: [
                            DataCell(Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t.name, style: context.eosText.titleSmall),
                                Text(t.description, style: context.eosText.bodySmall),
                              ],
                            )),
                            DataCell(Text(ticketTierTypeLabel(t.tierType))),
                            DataCell(Text(ngnFromMinor(t.priceMinor.toString()))),
                            DataCell(Text('$sold')),
                            DataCell(Text('${t.remaining}')),
                            DataCell(Text(window, style: context.eosText.labelSmall)),
                            DataCell(EosFinanceChip(
                              label: t.visibility == TicketVisibility.publicListing ? 'public' : 'hidden',
                              compact: true,
                            )),
                            DataCell(EosFinanceChip(
                              label: t.salesPaused ? 'paused' : (t.remaining == 0 ? 'sold_out' : 'on_sale'),
                              compact: true,
                            )),
                          ],
                        );
                      }).toList(),
                    ),
                    SizedBox(height: context.eos.spacing.md),
                    OutlinedButton.icon(
                      onPressed: () => _showAddTier(context, ref, event.id),
                      icon: const Icon(Icons.add),
                      label: const Text('Add ticket tier'),
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

  Future<void> _showAddTier(BuildContext context, WidgetRef ref, String eventId) async {
    final name = TextEditingController(text: 'Early Bird');
    var tierType = TicketTierType.earlyBird;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quick add tier'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            EosTextField(controller: name, label: 'Name'),
            EosSelectField<TicketTierType>(
              label: 'Type',
              value: tierType,
              items: TicketTierType.values
                  .map((t) => DropdownMenuItem(value: t, child: Text(ticketTierTypeLabel(t))))
                  .toList(),
              onChanged: (v) => tierType = v ?? tierType,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              OrganizerEventStore.instance.addTicketTier(
                eventId,
                OrganizerTicketTier(
                  id: 'tier_${DateTime.now().millisecondsSinceEpoch}',
                  name: name.text.trim(),
                  description: ticketTierTypeLabel(tierType),
                  priceMinor: 1000000,
                  currency: 'NGN',
                  capacity: 100,
                  remaining: 100,
                  tierType: tierType,
                  salesWindowStart: DateTime.now(),
                  salesWindowEnd: DateTime.now().add(const Duration(days: 30)),
                ),
              );
              bumpOrganizerRevision(ref);
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    name.dispose();
  }
}
