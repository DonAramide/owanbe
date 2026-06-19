import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../eos/eos.dart';
import '../providers/operations_providers.dart';
import '../widgets/operations_shared.dart';

class OperationsDashboardScreen extends ConsumerWidget {
  const OperationsDashboardScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpis = ref.watch(operationsKpisProvider(eventId));
    final health = ref.watch(operationsHealthProvider(eventId));
    final feed = ref.watch(operationsFeedProvider(eventId));

    return EosPageScaffold(
      title: 'Event operations',
      subtitle: 'Live health and floor visibility',
      floatingHeader: health.when(
        data: (h) => Row(
          children: [
            const EosLiveIndicator(compact: true),
            SizedBox(width: context.eos.spacing.sm),
            EventHealthBadge(level: h.level),
            SizedBox(width: context.eos.spacing.sm),
            Expanded(child: Text(h.summary, style: context.eosText.bodySmall)),
          ],
        ),
        loading: () => const SizedBox.shrink(),
        error: (_, _) => const SizedBox.shrink(),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => ref.read(operationsShellTabProvider.notifier).select(6),
          child: const Text('Command center'),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          kpis.when(
            data: (k) => Wrap(
              spacing: context.eos.spacing.md,
              runSpacing: context.eos.spacing.md,
              children: [
                SizedBox(
                  width: 180,
                  child: EosKpiCard(
                    title: 'Checked in',
                    value: '${k.checkedIn}',
                    subtitle: 'of ${k.totalRegistered}',
                    icon: Icons.qr_code_scanner,
                    attention: EosKpiAttention.info,
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: EosKpiCard(
                    title: 'Remaining',
                    value: '${k.remainingGuests}',
                    icon: Icons.people_outline,
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: EosKpiCard(
                    title: 'Vendors active',
                    value: '${k.vendorsActive}',
                    icon: Icons.storefront_outlined,
                    attention: k.vendorsActive > 0 ? EosKpiAttention.info : EosKpiAttention.warning,
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: EosKpiCard(
                    title: 'Orders today',
                    value: '${k.ordersToday}',
                    icon: Icons.receipt_long_outlined,
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: EosKpiCard(
                    title: 'Revenue today',
                    value: formatOpsMoney(k.revenueTodayMinor),
                    icon: Icons.payments_outlined,
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: EosKpiCard(
                    title: 'Open incidents',
                    value: '${k.openIncidents}',
                    icon: Icons.report_problem_outlined,
                    attention: k.openIncidents > 0 ? EosKpiAttention.critical : EosKpiAttention.none,
                    attentionSummary: k.openIncidents > 0 ? 'Requires ops attention' : null,
                  ),
                ),
              ],
            ),
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text('$e'),
          ),
          SizedBox(height: context.eos.spacing.xl),
          EosSection(
            title: 'Live activity',
            subtitle: 'Real-time event stream',
            trailing: TextButton(
              onPressed: () => ref.read(operationsShellTabProvider.notifier).select(3),
              child: const Text('Full feed'),
            ),
            child: feed.when(
              data: (items) => Column(
                children: [
                  for (final item in items.take(5))
                    EosFeedItem(
                      title: item.headline,
                      subtitle: item.detail,
                      timestamp: formatOpsTime(item.timestamp),
                      leading: Icon(feedIcon(item.type), color: context.eosColors.primary),
                    ),
                ],
              ),
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('$e'),
            ),
          ),
        ],
      ),
    );
  }
}
