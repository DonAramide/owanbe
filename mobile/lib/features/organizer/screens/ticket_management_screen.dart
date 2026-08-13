import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/money.dart';
import '../../../eos/eos.dart';
import '../models/organizer_models.dart';
import '../providers/organizer_providers.dart';
import '../widgets/organizer_shared.dart';
import '../widgets/organizer_ticket_tier_editor.dart';
import '../data/organizer_persistence.dart';

class TicketManagementScreen extends ConsumerWidget {
  const TicketManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventId = ref.watch(selectedOrganizerEventIdProvider);
    final eventAsync = eventId == null ? null : ref.watch(organizerEventProvider(eventId));

    return EosPageScaffold(
      title: 'Tickets',
      subtitle: 'Create tickets with pricing, capacity, sales windows, and visibility',
      actions: [
        if (eventId != null) ...[
          FilledButton.icon(
            onPressed: () => showOrganizerTicketTierEditor(context, ref, eventId: eventId),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Create ticket'),
          ),
          OutlinedButton.icon(
            onPressed: () => context.push('/organizer/events/$eventId?tabKey=tickets'),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('Event workspace'),
          ),
        ],
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const OrganizerEventPicker(),
          SizedBox(height: context.eos.spacing.lg),
          if (eventId == null)
            EosSurfaceCard(
              child: Text(
                'Select an event to manage tickets.',
                style: context.eosText.bodyMedium,
              ),
            )
          else
            eventAsync!.when(
              data: (event) {
                if (event == null) {
                  return Text('Event not found', style: context.eosText.bodyMedium);
                }
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
                        SizedBox(
                          width: 220,
                          child: EosKpiCard(
                            title: 'Tiers',
                            value: '${event.ticketTiers.length}',
                            icon: Icons.layers_outlined,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: context.eos.spacing.lg),
                    if (event.ticketTiers.isEmpty)
                      EosSurfaceCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('No tickets yet', style: context.eosText.titleSmall),
                            SizedBox(height: context.eos.spacing.xs),
                            Text(
                              'Create a ticket to set price, capacity, sales dates, and visibility.',
                              style: context.eosText.bodyMedium,
                            ),
                            SizedBox(height: context.eos.spacing.sm),
                            FilledButton.icon(
                              onPressed: () =>
                                  showOrganizerTicketTierEditor(context, ref, eventId: event.id),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Create ticket'),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      EosDataTable(
                        columns: const [
                          DataColumn(label: Text('Ticket')),
                          DataColumn(label: Text('Type')),
                          DataColumn(label: Text('Price')),
                          DataColumn(label: Text('Sold')),
                          DataColumn(label: Text('Remaining')),
                          DataColumn(label: Text('Window')),
                          DataColumn(label: Text('Visibility')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('')),
                        ],
                        rows: event.ticketTiers.map((t) {
                          final sold = t.capacity - t.remaining;
                          final window = t.salesWindowStart == null
                              ? '—'
                              : '${t.salesWindowStart!.month}/${t.salesWindowStart!.day}–${t.salesWindowEnd?.month}/${t.salesWindowEnd?.day}';
                          return DataRow(
                            cells: [
                              DataCell(
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(t.name, style: context.eosText.titleSmall),
                                    Text(t.description, style: context.eosText.bodySmall),
                                  ],
                                ),
                              ),
                              DataCell(Text(ticketTierTypeLabel(t.tierType))),
                              DataCell(Text(ngnFromMinor(t.priceMinor.toString()))),
                              DataCell(Text('$sold')),
                              DataCell(Text(t.unlimitedCapacity ? '∞' : '${t.remaining}')),
                              DataCell(Text(window, style: context.eosText.labelSmall)),
                              DataCell(
                                EosFinanceChip(
                                  label: t.archived
                                      ? 'archived'
                                      : t.visibility == TicketVisibility.publicListing
                                          ? 'public'
                                          : 'hidden',
                                  compact: true,
                                ),
                              ),
                              DataCell(
                                EosFinanceChip(
                                  label: t.archived
                                      ? 'archived'
                                      : t.salesPaused
                                          ? 'paused'
                                          : (t.isSoldOut ? 'sold_out' : 'on_sale'),
                                  compact: true,
                                ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextButton(
                                      onPressed: () => showOrganizerTicketTierEditor(
                                        context,
                                        ref,
                                        eventId: event.id,
                                        existing: t,
                                      ),
                                      child: const Text('Edit'),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        final ok = await confirmDeleteTicketTier(context, t);
                                        if (!ok) return;
                                        try {
                                          await deleteTicketTier(ref, t);
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Removed "${t.name}"')),
                                            );
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Delete failed: $e')),
                                            );
                                          }
                                        }
                                      },
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                      SizedBox(height: context.eos.spacing.md),
                      OutlinedButton.icon(
                        onPressed: () =>
                            showOrganizerTicketTierEditor(context, ref, eventId: event.id),
                        icon: const Icon(Icons.add),
                        label: const Text('Create ticket'),
                      ),
                    ],
                  ],
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => EosSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Could not load tickets', style: context.eosText.titleSmall),
                    Text('$e', style: context.eosText.bodySmall),
                    OutlinedButton(
                      onPressed: () => ref.invalidate(organizerEventProvider(eventId)),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
