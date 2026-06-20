import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../eos/eos.dart';
import 'admin_platform_providers.dart';

class OperationsCenterScreen extends ConsumerWidget {
  const OperationsCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(adminPlatformRevisionProvider);
    final ops = ref.watch(adminOperationsProvider);
    return EosPageScaffold(
      title: 'Operations center',
      subtitle: 'Cross-event check-ins, incidents, and live feed',
      body: ops.when(
        data: (d) {
          final live = (d['liveEvents'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
          final checkIns = (d['checkIns'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
          final incidents = (d['incidents'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
          final feed = (d['feed'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EosSection(
                title: 'Live events',
                child: live.isEmpty
                    ? EosSurfaceCard(child: Text('No live or published events', style: context.eosText.bodyMedium))
                    : Column(
                        children: live.take(6).map((e) => EosFeedItem(
                          title: e['title'] as String? ?? '',
                          subtitle: '${e['organizerName']} · ${e['checkedIn']} checked in',
                          timestamp: _formatTs((e['startsAt'] ?? '').toString()),
                        )).toList(),
                      ),
              ),
              SizedBox(height: context.eos.spacing.lg),
              EosSection(
                title: 'Recent check-ins',
                child: _simpleList(context, checkIns.take(8).map((c) => '${c['holderName']} · ${c['eventTitle']}').toList()),
              ),
              SizedBox(height: context.eos.spacing.lg),
              EosSection(
                title: 'Open incidents',
                child: incidents.isEmpty
                    ? EosSurfaceCard(child: Text('No open incidents', style: context.eosText.bodyMedium))
                    : Column(
                        children: incidents.take(6).map((i) => EosAttentionBanner(
                          headline: i['title'] as String? ?? '',
                          message: '${i['eventTitle']} · ${i['priority']}',
                          severity: i['priority'] == 'critical' ? 'CRITICAL' : 'WARNING',
                        )).toList(),
                      ),
              ),
              SizedBox(height: context.eos.spacing.lg),
              EosSection(
                title: 'Operational feed',
                child: _simpleList(context, feed.take(10).map((f) => '${f['headline']} — ${f['eventTitle']}').toList()),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('$e'),
      ),
    );
  }

  Widget _simpleList(BuildContext context, Iterable<String> lines) {
    if (lines.isEmpty) {
      return EosSurfaceCard(child: Text('No activity', style: context.eosText.bodyMedium));
    }
    return EosSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines.map((l) => Padding(
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
