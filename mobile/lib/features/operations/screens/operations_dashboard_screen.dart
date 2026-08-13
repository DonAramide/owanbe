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
    final feed = ref.watch(operationsLiveFeedProvider(eventId));

    return EosPageScaffold(
      title: 'Event day dashboard',
      subtitle: 'Attendance, arrivals, and door activity',
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
        loading: () => const LinearProgressIndicator(minHeight: 2),
        error: (e, _) => Text('$e', style: context.eosText.bodySmall),
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
                _kpi(context, 'Checked in', '${k.checkedIn}', 'of ${k.totalRegistered}', Icons.qr_code_scanner),
                _kpi(context, 'Remaining', '${k.remainingGuests}', 'issued not yet in', Icons.people_outline),
                _kpi(context, 'Capacity', '${k.capacity}', '${k.capacityPct.toStringAsFixed(0)}% filled', Icons.meeting_room_outlined),
                _kpi(context, 'No-shows', '${k.noShows}', 'still outstanding', Icons.person_off_outlined),
                _kpi(
                  context,
                  'Attendance',
                  '${k.attendancePct.toStringAsFixed(0)}%',
                  'status ${k.eventStatus}',
                  Icons.insights_outlined,
                ),
                _kpi(
                  context,
                  'Gate activity',
                  '${k.checkInsLast15m}',
                  'last 15m · queue ${k.queueState}',
                  Icons.sensors,
                  attention: k.queueState == 'heavy' ? EosKpiAttention.warning : EosKpiAttention.info,
                ),
                _kpi(
                  context,
                  'Open incidents',
                  '${k.openIncidents}',
                  k.openIncidents > 0 ? 'Requires ops attention' : 'Clear',
                  Icons.report_problem_outlined,
                  attention: k.openIncidents > 0 ? EosKpiAttention.critical : EosKpiAttention.none,
                ),
              ],
            ),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => EosAttentionBanner(
              headline: 'Could not load door counters',
              message: '$e',
              severity: 'WARNING',
              actionLabel: 'Retry',
              onAction: () => bumpOperationsRevision(ref),
            ),
          ),
          SizedBox(height: context.eos.spacing.xl),
          kpis.when(
            data: (k) {
              if (k.recentArrivals.isEmpty) {
                return EosSection(
                  title: 'Recent arrivals',
                  child: EosSurfaceCard(
                    child: Text('No check-ins yet — door is ready.', style: context.eosText.bodyMedium),
                  ),
                );
              }
              return EosSection(
                title: 'Recent arrivals',
                subtitle: 'Live check-ins from entitlements',
                child: Column(
                  children: [
                    for (final a in k.recentArrivals.take(8))
                      EosFeedItem(
                        title: a.name,
                        subtitle: '${a.tierName} · ${a.ticketCode} · ${a.source}',
                        timestamp: formatOpsTime(a.checkedInAt),
                        leading: Icon(Icons.login, color: context.eosColors.primary),
                      ),
                  ],
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          SizedBox(height: context.eos.spacing.xl),
          EosSection(
            title: 'Live activity',
            subtitle: 'SSE feed with poll fallback',
            trailing: TextButton(
              onPressed: () => ref.read(operationsShellTabProvider.notifier).select(3),
              child: const Text('Full feed'),
            ),
            child: feed.when(
              data: (items) {
                if (items.isEmpty) {
                  return EosSurfaceCard(
                    child: Text('Waiting for door activity…', style: context.eosText.bodyMedium),
                  );
                }
                return Column(
                  children: [
                    for (final item in items.take(5))
                      EosFeedItem(
                        title: item.headline,
                        subtitle: item.detail,
                        timestamp: formatOpsTime(item.timestamp),
                        leading: Icon(feedIcon(item.type), color: context.eosColors.primary),
                      ),
                  ],
                );
              },
              loading: () => const LinearProgressIndicator(minHeight: 2),
              error: (e, _) => Text('$e'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpi(
    BuildContext context,
    String title,
    String value,
    String subtitle,
    IconData icon, {
    EosKpiAttention attention = EosKpiAttention.none,
  }) {
    return SizedBox(
      width: 180,
      child: EosKpiCard(
        title: title,
        value: value,
        subtitle: subtitle,
        icon: icon,
        attention: attention,
      ),
    );
  }
}
