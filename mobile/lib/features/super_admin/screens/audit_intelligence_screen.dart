import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../eos/eos.dart';
import '../super_admin_providers.dart';

class AuditIntelligenceScreen extends ConsumerWidget {
  const AuditIntelligenceScreen({super.key});

  static const categories = ['all', 'admin', 'financial', 'security', 'tenant'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = ref.watch(superAdminAuditCategoryProvider);
    final timeline = ref.watch(superAdminAuditProvider(category));
    return EosPageScaffold(
      title: 'Audit intelligence',
      subtitle: 'Platform-wide action timeline',
      floatingHeader: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: categories.map((c) => Padding(
            padding: EdgeInsets.only(right: context.eos.spacing.xs),
            child: FilterChip(
              label: Text(c),
              selected: category == c,
              onSelected: (_) => ref.read(superAdminAuditCategoryProvider.notifier).state = c,
            ),
          )).toList(),
        ),
      ),
      body: timeline.when(
        data: (items) => Column(
          children: items.take(50).map((e) => Padding(
            padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
            child: EosFeedItem(
              title: e['action'] as String? ?? '',
              subtitle: '${e['tenantName'] ?? e['tenantId']} · ${e['category']}',
              timestamp: _formatTs((e['timestamp'] ?? '').toString()),
            ),
          )).toList(),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('$e'),
      ),
    );
  }
}

String _formatTs(String raw) {
  final dt = DateTime.tryParse(raw);
  if (dt == null) return raw;
  return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
