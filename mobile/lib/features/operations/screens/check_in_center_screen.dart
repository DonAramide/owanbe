import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../eos/eos.dart';
import '../models/operations_models.dart';
import '../providers/operations_providers.dart';
import '../widgets/operations_shared.dart';

class CheckInCenterScreen extends ConsumerWidget {
  const CheckInCenterScreen({super.key, required this.eventId});

  final String eventId;

  static const _filters = [
    (CheckInFilter.all, 'All Guests'),
    (CheckInFilter.checkedIn, 'Checked In'),
    (CheckInFilter.notCheckedIn, 'Not Checked In'),
    (CheckInFilter.vip, 'VIP'),
    (CheckInFilter.vvip, 'VVIP'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guests = ref.watch(operationsGuestsProvider(eventId));
    final filter = ref.watch(checkInFilterProvider);

    return EosPageScaffold(
      title: 'Check-in center',
      subtitle: 'Guest arrival and entry management',
      actions: [
        FilledButton.icon(
          onPressed: () => ref.read(operationsShellTabProvider.notifier).select(2),
          icon: const Icon(Icons.qr_code_scanner, size: 18),
          label: const Text('Scan ticket'),
        ),
      ],
      floatingHeader: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final f in _filters)
              Padding(
                padding: EdgeInsets.only(right: context.eos.spacing.xs),
                child: FilterChip(
                  label: Text(f.$2),
                  selected: filter == f.$1,
                  onSelected: (_) => ref.read(checkInFilterProvider.notifier).state = f.$1,
                ),
              ),
          ],
        ),
      ),
      body: guests.when(
        data: (list) {
          final filtered = filterGuests(list, filter);
          if (filtered.isEmpty) {
            return EosSurfaceCard(
              child: Text('No guests in this view', style: context.eosText.bodyMedium),
            );
          }
          return Column(
            children: [
              for (final g in filtered)
                Padding(
                  padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                  child: OpsGuestCard(
                    guest: g,
                    onCheckIn: g.checkedIn
                        ? null
                        : () async {
                            await performManualCheckIn(ref, eventId, g);
                          },
                    onResend: g.checkedIn
                        ? () => ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Ticket resent to ${g.email}')),
                            )
                        : null,
                    onHistory: () => ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('History for ${g.name}')),
                    ),
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('$e'),
      ),
    );
  }
}
