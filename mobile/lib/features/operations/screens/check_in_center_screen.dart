import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/events_api.dart';
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
    final kpis = ref.watch(operationsKpisProvider(eventId));

    return EosPageScaffold(
      title: 'Check-in center',
      subtitle: 'Entitlement-backed door admissions',
      actions: [
        FilledButton.icon(
          onPressed: () => ref.read(operationsShellTabProvider.notifier).select(2),
          icon: const Icon(Icons.qr_code_scanner, size: 18),
          label: const Text('Scan ticket'),
        ),
      ],
      floatingHeader: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          kpis.when(
            data: (k) => Padding(
              padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
              child: Text(
                '${k.checkedIn} inside · ${k.remainingGuests} remaining · ${k.attendancePct.toStringAsFixed(0)}%',
                style: context.eosText.labelMedium,
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          SingleChildScrollView(
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
        ],
      ),
      body: guests.when(
        data: (list) {
          final filtered = filterGuests(list, filter);
          if (filtered.isEmpty) {
            return EosSurfaceCard(
              child: Text(
                list.isEmpty
                    ? 'No issued entitlements yet. Sell tickets or confirm invitation RSVPs first.'
                    : 'No guests in this view',
                style: context.eosText.bodyMedium,
              ),
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
                            try {
                              await performManualCheckIn(ref, eventId, g);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('${g.name} checked in')),
                                );
                              }
                            } on EventsApiException catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.message)),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('$e')),
                                );
                              }
                            }
                          },
                    onHistory: () => ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${g.name}: ${g.doorStatusLabel}')),
                    ),
                  ),
                ),
            ],
          );
        },
        loading: () => Column(
          children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                child: const EosSurfaceCard(
                  child: SizedBox(height: 72, child: Center(child: CircularProgressIndicator())),
                ),
              ),
          ],
        ),
        error: (e, _) => EosAttentionBanner(
          headline: 'Check-in list unavailable',
          message: '$e',
          severity: 'WARNING',
          actionLabel: 'Retry',
          onAction: () => bumpOperationsRevision(ref),
        ),
      ),
    );
  }
}
