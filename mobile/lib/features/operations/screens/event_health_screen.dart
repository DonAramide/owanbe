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
      title: 'Event health',
      subtitle: 'Capacity, queue, throughput, attendance',
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
                _rateCard(context, 'Attendance', h.attendanceRate, Icons.groups_outlined),
                _rateCard(context, 'Capacity fill', h.capacityRate, Icons.meeting_room_outlined),
                _rateCard(context, 'Check-in rate', h.checkInRate, Icons.qr_code_scanner),
                SizedBox(
                  width: 220,
                  child: EosKpiCard(
                    title: 'Queue state',
                    value: h.queueState,
                    subtitle: '${h.checkInThroughputPerHour}/hr throughput',
                    icon: Icons.speed,
                    attention: h.queueState == 'heavy'
                        ? EosKpiAttention.warning
                        : h.queueState == 'busy'
                            ? EosKpiAttention.info
                            : EosKpiAttention.none,
                  ),
                ),
                _rateCard(context, 'Incident load', h.incidentRate, Icons.report_problem_outlined, invert: true),
              ],
            ),
            SizedBox(height: context.eos.spacing.lg),
            kpis.when(
              data: (k) => EosSection(
                title: 'Attendance trend (live)',
                child: EosSurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${k.checkedIn} inside · ${k.remainingGuests} remaining · ${k.attendancePct.toStringAsFixed(1)}%',
                        style: context.eosText.titleSmall,
                      ),
                      SizedBox(height: context.eos.spacing.sm),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: (k.attendancePct / 100).clamp(0.0, 1.0),
                          minHeight: 10,
                        ),
                      ),
                      SizedBox(height: context.eos.spacing.sm),
                      Text(
                        'Last 15m: ${k.checkInsLast15m} check-ins · Last 60m: ${k.checkInsLast60m}',
                        style: context.eosText.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EosAttentionBanner(
          headline: 'Health unavailable',
          message: '$e',
          severity: 'WARNING',
          actionLabel: 'Retry',
          onAction: () => bumpOperationsRevision(ref),
        ),
      ),
    );
  }

  Widget _rateCard(BuildContext context, String title, double rate, IconData icon, {bool invert = false}) {
    final pct = (rate * 100).clamp(0, 100).toStringAsFixed(0);
    final attention = invert
        ? (rate > 0.3
            ? EosKpiAttention.critical
            : rate > 0.15
                ? EosKpiAttention.warning
                : EosKpiAttention.none)
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
