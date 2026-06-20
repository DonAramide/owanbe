import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../eos/eos.dart';
import '../super_admin_providers.dart';

class SystemHealthScreen extends ConsumerWidget {
  const SystemHealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(superAdminSystemHealthProvider);
    return EosPageScaffold(
      title: 'System health',
      subtitle: 'API, database, queue, webhook, and reconciliation status',
      body: health.when(
        data: (d) {
          final overall = (d['overall'] ?? 'operational').toString();
          final components = d['components'] as Map<String, dynamic>? ?? {};
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EosAttentionBanner(
                headline: 'Overall: ${overall.toUpperCase()}',
                message: 'Checked at ${d['checkedAt']}',
                severity: overall == 'critical' ? 'CRITICAL' : overall == 'degraded' ? 'WARNING' : 'INFO',
              ),
              SizedBox(height: context.eos.spacing.lg),
              ...components.entries.map((e) => Padding(
                padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                child: EosSurfaceCard(
                  child: Row(
                    children: [
                      Expanded(child: Text(e.key, style: context.eosText.titleSmall)),
                      EosFinanceChip(label: '${e.value}', compact: true),
                    ],
                  ),
                ),
              )),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('$e'),
      ),
    );
  }
}
