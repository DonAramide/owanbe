import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../eos/eos.dart';
import 'admin_platform_providers.dart';

class ComplianceAuditScreen extends ConsumerWidget {
  const ComplianceAuditScreen({super.key});

  static const categories = ['all', 'organizer', 'vendor', 'financial', 'admin'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(adminPlatformRevisionProvider);
    final category = ref.watch(adminAuditCategoryProvider);
    final timeline = ref.watch(adminAuditProvider(category));
    return EosPageScaffold(
      title: 'Compliance & audit',
      subtitle: 'Platform action timeline',
      floatingHeader: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: categories.map((c) => Padding(
            padding: EdgeInsets.only(right: context.eos.spacing.xs),
            child: FilterChip(
              label: Text(c),
              selected: category == c,
              onSelected: (_) => ref.read(adminAuditCategoryProvider.notifier).state = c,
            ),
          )).toList(),
        ),
      ),
      body: timeline.when(
        data: (items) {
          if (items.isEmpty) {
            return EosSurfaceCard(child: Text('No audit events', style: context.eosText.bodyMedium));
          }
          return Column(
            children: items.take(50).map((e) => Padding(
              padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
              child: EosFeedItem(
                title: e['action'] as String? ?? '',
                subtitle: '${e['category']} · ${e['resourceType']} ${e['resourceId']}',
                timestamp: _formatTs((e['timestamp'] ?? '').toString()),
              ),
            )).toList(),
          );
        },
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
