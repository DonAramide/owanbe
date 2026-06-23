import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../eos/eos.dart';
import '../widgets/admin_async_body.dart';
import '../widgets/admin_error_states.dart';
import '../widgets/admin_page_layout.dart';
import 'admin_platform_providers.dart';

class OperationsCenterScreen extends ConsumerWidget {
  const OperationsCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(adminPlatformRevisionProvider);
    final ops = ref.watch(adminOperationsProvider);

    return AdminPageLayout(
      title: 'Operations',
      subtitle: 'Cross-event check-ins, incidents, and live feed',
      body: AdminAsyncBody(
        value: ops,
        onRetry: () => ref.invalidate(adminOperationsProvider),
        skeletonCount: 2,
        builder: (d) {
          final live = (d['liveEvents'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
          final checkIns = (d['checkIns'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
          final incidents = (d['incidents'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
          final feed = (d['feed'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 960;
                  final left = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AdminSectionHeader(title: 'Live events'),
                      live.isEmpty
                          ? const EmptyStateCard(title: 'No live events', message: 'Published and live events appear here.')
                          : EosSurfaceCard(
                              elevated: true,
                              child: Column(
                                children: live.take(6).map((e) => EosFeedItem(
                                  title: e['title'] as String? ?? '',
                                  subtitle: '${e['organizerName']} · ${e['checkedIn']} checked in',
                                  timestamp: _formatTs((e['startsAt'] ?? '').toString()),
                                )).toList(),
                              ),
                            ),
                      SizedBox(height: context.eos.spacing.lg),
                      AdminSectionHeader(title: 'Open incidents'),
                      incidents.isEmpty
                          ? const EmptyStateCard(title: 'No open incidents')
                          : Column(
                              children: incidents.take(6).map((i) => Padding(
                                padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                                child: EosAttentionBanner(
                                  headline: i['title'] as String? ?? '',
                                  message: '${i['eventTitle']} · ${i['priority']}',
                                  severity: i['priority'] == 'critical' ? 'CRITICAL' : 'WARNING',
                                ),
                              )).toList(),
                            ),
                    ],
                  );
                  final right = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AdminSectionHeader(title: 'Recent check-ins'),
                      _simpleList(context, checkIns.take(8).map((c) => '${c['holderName']} · ${c['eventTitle']}').toList()),
                      SizedBox(height: context.eos.spacing.lg),
                      AdminSectionHeader(title: 'Operational feed'),
                      _simpleList(context, feed.take(10).map((f) => '${f['headline']} — ${f['eventTitle']}').toList()),
                    ],
                  );
                  if (!wide) {
                    return Column(children: [left, SizedBox(height: context.eos.spacing.lg), right]);
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: left),
                      SizedBox(width: context.eos.spacing.lg),
                      Expanded(child: right),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _simpleList(BuildContext context, Iterable<String> lines) {
    final list = lines.toList();
    if (list.isEmpty) {
      return const EmptyStateCard(title: 'No activity yet');
    }
    return EosSurfaceCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: list.map((l) => Padding(
          padding: EdgeInsets.only(bottom: context.eos.spacing.xs),
          child: Text(l, style: context.eosText.bodySmall),
        )).toList(),
      ),
    );
  }
}

String _formatTs(String raw) {
  final dt = DateTime.tryParse(raw);
  if (dt == null) return raw;
  return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
