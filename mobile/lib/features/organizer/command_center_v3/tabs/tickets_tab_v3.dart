import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/money.dart';
import '../../../../eos/eos.dart';
import '../../data/organizer_persistence.dart';
import '../../models/organizer_models.dart';
import '../../providers/organizer_providers.dart';
import '../../widgets/organizer_shared.dart';

class TicketsTabV3 extends ConsumerStatefulWidget {
  const TicketsTabV3({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<TicketsTabV3> createState() => _TicketsTabV3State();
}

class _TicketsTabV3State extends ConsumerState<TicketsTabV3> {
  @override
  Widget build(BuildContext context) {
    final event = ref.watch(organizerEventProvider(widget.eventId)).value;
    if (event == null) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: EdgeInsets.all(context.eos.spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ticket tiers', style: context.eosText.titleLarge),
                    Text(
                      '${event.ticketsSold} sold · ${formatRevenue(event.revenueMinor)} revenue',
                      style: context.eosText.bodySmall,
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => _showTierDialog(context, event.id),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add tier'),
              ),
            ],
          ),
          SizedBox(height: context.eos.spacing.md),
          if (event.ticketTiers.isEmpty)
            EosSurfaceCard(
              child: Text('Add ticket tiers for your public event.', style: context.eosText.bodyMedium),
            )
          else
            for (final t in event.ticketTiers)
              Padding(
                padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                child: EosSurfaceCard(
                  elevated: true,
                  child: ListTile(
                    title: Text(t.name, style: context.eosText.titleSmall),
                    subtitle: Text('${ticketTierTypeLabel(t.tierType)} · ${t.capacity - t.remaining}/${t.capacity} sold'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(ngnFromMinor(t.priceMinor.toString()), style: context.eosText.titleSmall),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: () => _showTierDialog(context, event.id, existing: t),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _showTierDialog(BuildContext context, String eventId, {OrganizerTicketTier? existing}) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final desc = TextEditingController(text: existing?.description ?? '');
    final price = TextEditingController(text: existing != null ? '${existing.priceMinor ~/ 100}' : '15000');
    final cap = TextEditingController(text: existing != null ? '${existing.capacity}' : '100');
    var tierType = existing?.tierType ?? TicketTierType.regular;
    var visibility = existing?.visibility ?? TicketVisibility.publicListing;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Create ticket tier' : 'Edit ticket tier'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                EosTextField(controller: name, label: 'Name'),
                SizedBox(height: context.eos.spacing.sm),
                EosTextField(controller: desc, label: 'Description'),
                SizedBox(height: context.eos.spacing.sm),
                EosTextField(controller: price, label: 'Price (NGN)', keyboardType: TextInputType.number),
                SizedBox(height: context.eos.spacing.sm),
                EosTextField(controller: cap, label: 'Capacity', keyboardType: TextInputType.number),
                SizedBox(height: context.eos.spacing.sm),
                EosSelectField<TicketTierType>(
                  label: 'Tier type',
                  value: tierType,
                  items: TicketTierType.values
                      .map((t) => DropdownMenuItem(value: t, child: Text(ticketTierTypeLabel(t))))
                      .toList(),
                  onChanged: (v) => tierType = v ?? tierType,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final priceMinor = (int.tryParse(price.text) ?? 0) * 100;
              final capacity = int.tryParse(cap.text) ?? 100;
              if (existing == null) {
                await addTicketTier(
                  ref,
                  eventId,
                  OrganizerTicketTier(
                    id: 'tier_${DateTime.now().millisecondsSinceEpoch}',
                    name: name.text.trim(),
                    description: desc.text.trim(),
                    priceMinor: priceMinor,
                    currency: 'NGN',
                    capacity: capacity,
                    remaining: capacity,
                    tierType: tierType,
                    visibility: visibility,
                  ),
                );
              } else {
                await updateTicketTier(ref, eventId, existing, (t) {
                  final sold = t.capacity - t.remaining;
                  return t.copyWith(
                    name: name.text.trim(),
                    priceMinor: priceMinor,
                    capacity: capacity,
                    remaining: (capacity - sold).clamp(0, capacity),
                    tierType: tierType,
                  );
                });
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(existing == null ? 'Create' : 'Save'),
          ),
        ],
      ),
    );
    name.dispose();
    desc.dispose();
    price.dispose();
    cap.dispose();
  }
}
