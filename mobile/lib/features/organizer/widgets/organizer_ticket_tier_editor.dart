import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../eos/eos.dart';
import '../data/organizer_persistence.dart';
import '../models/organizer_models.dart';

/// Full ticket (tier) create/edit dialog — pricing, capacity, window, visibility, purchase rules.
Future<void> showOrganizerTicketTierEditor(
  BuildContext context,
  WidgetRef ref, {
  required String eventId,
  OrganizerTicketTier? existing,
}) async {
  final name = TextEditingController(text: existing?.name ?? '');
  final desc = TextEditingController(text: existing?.description ?? '');
  final price = TextEditingController(
    text: existing != null ? '${existing.priceMinor ~/ 100}' : '15000',
  );
  final cap = TextEditingController(text: existing != null ? '${existing.capacity}' : '100');
  final minQty = TextEditingController(text: '${existing?.minQuantity ?? 1}');
  final maxQty = TextEditingController(text: existing?.maxQuantity?.toString() ?? '');
  final maxPerUser = TextEditingController(text: existing?.maxPerUser?.toString() ?? '');
  var tierType = existing?.tierType ?? TicketTierType.regular;
  var visibility = existing?.visibility ?? TicketVisibility.publicListing;
  var salesPaused = existing?.salesPaused ?? false;
  var unlimited = existing?.unlimitedCapacity ?? false;
  var salesStart = existing?.salesWindowStart ?? DateTime.now();
  var salesEnd = existing?.salesWindowEnd ?? DateTime.now().add(const Duration(days: 30));

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            title: Text(existing == null ? 'Create ticket' : 'Edit ticket'),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Set price, inventory, sales window, visibility, and purchase limits.',
                      style: context.eosText.bodySmall,
                    ),
                    SizedBox(height: context.eos.spacing.md),
                    EosTextField(controller: name, label: 'Ticket name'),
                    SizedBox(height: context.eos.spacing.sm),
                    EosTextField(controller: desc, label: 'Description'),
                    SizedBox(height: context.eos.spacing.sm),
                    EosTextField(
                      controller: price,
                      label: tierType == TicketTierType.complimentary ? 'Price (NGN) — use 0 for free' : 'Price (NGN)',
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(height: context.eos.spacing.sm),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Unlimited quantity'),
                      subtitle: const Text('Skip capacity tracking for this tier'),
                      value: unlimited,
                      onChanged: (v) => setLocal(() => unlimited = v),
                    ),
                    if (!unlimited)
                      EosTextField(
                        controller: cap,
                        label: 'Capacity',
                        keyboardType: TextInputType.number,
                      ),
                    SizedBox(height: context.eos.spacing.sm),
                    EosSelectField<TicketTierType>(
                      label: 'Ticket type',
                      value: tierType,
                      items: TicketTierType.values
                          .map((t) => DropdownMenuItem(value: t, child: Text(ticketTierTypeLabel(t))))
                          .toList(),
                      onChanged: (v) => setLocal(() {
                        tierType = v ?? tierType;
                        if (tierType == TicketTierType.complimentary && price.text.trim().isEmpty) {
                          price.text = '0';
                        }
                      }),
                    ),
                    SizedBox(height: context.eos.spacing.sm),
                    EosSelectField<TicketVisibility>(
                      label: 'Visibility',
                      value: visibility,
                      items: const [
                        DropdownMenuItem(
                          value: TicketVisibility.publicListing,
                          child: Text('Public listing'),
                        ),
                        DropdownMenuItem(
                          value: TicketVisibility.hidden,
                          child: Text('Hidden'),
                        ),
                      ],
                      onChanged: (v) => setLocal(() => visibility = v ?? visibility),
                    ),
                    SizedBox(height: context.eos.spacing.sm),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Pause sales'),
                      value: salesPaused,
                      onChanged: (v) => setLocal(() => salesPaused = v),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Sales start'),
                      subtitle: Text(
                        '${salesStart.year}-${salesStart.month.toString().padLeft(2, '0')}-${salesStart.day.toString().padLeft(2, '0')}',
                      ),
                      trailing: const Icon(Icons.calendar_today_outlined, size: 18),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: salesStart,
                          firstDate: DateTime.now().subtract(const Duration(days: 1)),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                        );
                        if (picked != null) setLocal(() => salesStart = picked);
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Sales end'),
                      subtitle: Text(
                        '${salesEnd.year}-${salesEnd.month.toString().padLeft(2, '0')}-${salesEnd.day.toString().padLeft(2, '0')}',
                      ),
                      trailing: const Icon(Icons.event_outlined, size: 18),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: salesEnd.isAfter(salesStart) ? salesEnd : salesStart,
                          firstDate: salesStart,
                          lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                        );
                        if (picked != null) setLocal(() => salesEnd = picked);
                      },
                    ),
                    SizedBox(height: context.eos.spacing.md),
                    Text('Purchase rules', style: context.eosText.titleSmall),
                    SizedBox(height: context.eos.spacing.sm),
                    EosTextField(
                      controller: minQty,
                      label: 'Minimum quantity',
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(height: context.eos.spacing.sm),
                    EosTextField(
                      controller: maxQty,
                      label: 'Maximum quantity (optional)',
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(height: context.eos.spacing.sm),
                    EosTextField(
                      controller: maxPerUser,
                      label: 'Per-attendee limit (optional)',
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () async {
                  final trimmed = name.text.trim();
                  if (trimmed.isEmpty) return;
                  var priceMinor = (int.tryParse(price.text) ?? 0) * 100;
                  if (tierType == TicketTierType.complimentary) priceMinor = 0;
                  final capacity = unlimited ? 0 : (int.tryParse(cap.text) ?? 100);
                  final minQ = int.tryParse(minQty.text) ?? 1;
                  final maxQ = int.tryParse(maxQty.text.trim());
                  final maxUser = int.tryParse(maxPerUser.text.trim());
                  if (existing == null) {
                    await addTicketTier(
                      ref,
                      eventId,
                      OrganizerTicketTier(
                        id: 'tier_${DateTime.now().millisecondsSinceEpoch}',
                        name: trimmed,
                        description: desc.text.trim(),
                        priceMinor: priceMinor,
                        currency: 'NGN',
                        capacity: capacity,
                        remaining: capacity,
                        tierType: tierType,
                        visibility: visibility,
                        salesWindowStart: salesStart,
                        salesWindowEnd: salesEnd,
                        salesPaused: salesPaused,
                        unlimitedCapacity: unlimited,
                        minQuantity: minQ < 1 ? 1 : minQ,
                        maxQuantity: maxQ,
                        maxPerUser: maxUser,
                      ),
                    );
                  } else {
                    await updateTicketTier(ref, eventId, existing, (t) {
                      final sold = t.capacity - t.remaining;
                      final nextCap = unlimited ? 0 : capacity;
                      return t.copyWith(
                        name: trimmed,
                        description: desc.text.trim(),
                        priceMinor: priceMinor,
                        capacity: nextCap,
                        remaining: unlimited ? 0 : (nextCap - sold).clamp(0, nextCap),
                        tierType: tierType,
                        visibility: visibility,
                        salesWindowStart: salesStart,
                        salesWindowEnd: salesEnd,
                        salesPaused: salesPaused,
                        unlimitedCapacity: unlimited,
                        minQuantity: minQ < 1 ? 1 : minQ,
                        maxQuantity: maxQ,
                        maxPerUser: maxUser,
                        clearMaxQuantity: maxQ == null,
                        clearMaxPerUser: maxUser == null,
                      );
                    });
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Text(existing == null ? 'Create ticket' : 'Save'),
              ),
            ],
          );
        },
      );
    },
  );

  name.dispose();
  desc.dispose();
  price.dispose();
  cap.dispose();
  minQty.dispose();
  maxQty.dispose();
  maxPerUser.dispose();
}

Future<bool> confirmDeleteTicketTier(BuildContext context, OrganizerTicketTier tier) async {
  final sold = tier.capacity - tier.remaining;
  final willArchive = sold > 0 || tier.unlimitedCapacity;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(willArchive ? 'Archive ticket?' : 'Delete ticket?'),
      content: Text(
        willArchive
            ? '"${tier.name}" has sales history and will be archived (hidden from purchase).'
            : 'Permanently delete "${tier.name}"? This cannot be undone.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(willArchive ? 'Archive' : 'Delete'),
        ),
      ],
    ),
  );
  return result == true;
}
