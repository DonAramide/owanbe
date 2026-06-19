import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../eos/eos.dart';
import '../models/operations_models.dart';
import '../providers/operations_providers.dart';
import '../widgets/operations_shared.dart';

class EventHealthScreen extends ConsumerWidget {
  const EventHealthScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(operationsHealthProvider(eventId));
    final kpis = ref.watch(operationsKpisProvider(eventId));

    return EosPageScaffold(
      title: 'Event health engine',
      subtitle: 'Automated operational health scoring',
      body: health.when(
        data: (h) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EosSurfaceCard(
              elevated: true,
              accentColor: switch (h.level) {
                EventHealthLevel.healthy => EosColors.success,
                EventHealthLevel.warning => EosColors.warning,
                EventHealthLevel.critical => EosColors.critical,
              },
              child: Row(
                children: [
                  EventHealthBadge(level: h.level),
                  SizedBox(width: context.eos.spacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          h.level.name.toUpperCase(),
                          style: context.eosText.headlineSmall,
                        ),
                        Text(h.summary, style: context.eosText.bodyMedium),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (h.level != EventHealthLevel.healthy) ...[
              SizedBox(height: context.eos.spacing.md),
              EosAttentionBanner(
                headline: 'Operational alert',
                message: h.summary,
                severity: h.level == EventHealthLevel.critical ? 'CRITICAL' : 'WARNING',
                onAction: () => ref.read(operationsShellTabProvider.notifier).select(5),
                actionLabel: 'View incidents',
              ),
            ],
            SizedBox(height: context.eos.spacing.xl),
            Wrap(
              spacing: context.eos.spacing.md,
              runSpacing: context.eos.spacing.md,
              children: [
                _rateCard(context, 'Attendance rate', h.attendanceRate, Icons.groups_outlined),
                _rateCard(context, 'Check-in rate', h.checkInRate, Icons.qr_code_scanner),
                _rateCard(context, 'Vendor activity', h.vendorActivityRate, Icons.storefront_outlined),
                _rateCard(context, 'Incident rate', h.incidentRate, Icons.report_problem_outlined,
                    invert: true),
              ],
            ),
            SizedBox(height: context.eos.spacing.lg),
            kpis.when(
              data: (k) => EosKpiCard(
                title: 'Revenue velocity',
                value: formatOpsMoney(h.revenueVelocityMinor),
                subtitle: 'Per hour (estimated)',
                icon: Icons.speed,
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('$e'),
      ),
    );
  }

  Widget _rateCard(BuildContext context, String title, double rate, IconData icon, {bool invert = false}) {
    final pct = (rate * 100).clamp(0, 100).toStringAsFixed(0);
    final attention = invert
        ? (rate > 0.3 ? EosKpiAttention.critical : rate > 0.15 ? EosKpiAttention.warning : EosKpiAttention.none)
        : (rate < 0.4 ? EosKpiAttention.warning : EosKpiAttention.info);
    return SizedBox(
      width: 220,
      child: EosKpiCard(
        title: title,
        value: '$pct%',
        icon: icon,
        attention: attention,
      ),
    );
  }
}
