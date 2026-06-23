import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../eos/eos.dart';
import '../platform/admin_platform_providers.dart';
import '../widgets/admin_async_body.dart';
import '../widgets/admin_error_states.dart';
import '../widgets/admin_page_layout.dart';
import '../widgets/admin_timeline_table.dart';

class AdminAuditScreen extends ConsumerWidget {
  const AdminAuditScreen({super.key});

  static const categories = ['all', 'organizer', 'vendor', 'financial', 'admin'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(adminPlatformRevisionProvider);
    final category = ref.watch(adminAuditCategoryProvider);
    final timeline = ref.watch(adminAuditProvider(category));

    return AdminPageLayout(
      title: 'Audit log',
      subtitle: 'Immutable timeline of platform actions',
      header: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: categories.map((c) {
            return Padding(
              padding: EdgeInsets.only(right: context.eos.spacing.sm),
              child: FilterChip(
                label: Text(c),
                selected: category == c,
                onSelected: (_) => ref.read(adminAuditCategoryProvider.notifier).state = c,
              ),
            );
          }).toList(),
        ),
      ),
      body: AdminAsyncBody(
        value: timeline,
        onRetry: () => ref.invalidate(adminAuditProvider(category)),
        skeletonCount: 1,
        isEmpty: (items) => items.isEmpty,
        empty: const EmptyStateCard(
          title: 'No audit events',
          message: 'Platform actions will appear here as admins and systems make changes.',
        ),
        builder: (items) => AdminTimelineTable(
          items: items.take(50).map(timelineRowFromAudit).toList(),
        ),
      ),
    );
  }
}
