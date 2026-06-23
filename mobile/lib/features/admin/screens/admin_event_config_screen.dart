import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../eos/eos.dart';
import '../../../core/api/event_config_api.dart';
import '../../../core/api/persistence_providers.dart';
import '../../../shared/models/event_access_mode.dart';
import '../widgets/admin_page_layout.dart';

final adminEventCategoriesProvider = FutureProvider.autoDispose<List<EventCategoryConfig>>((ref) async {
  try {
    final api = EventConfigApi(http.Client());
    return await api.listCategories();
  } catch (_) {
    if (!allowMockPersistenceFallback()) rethrow;
    return EventCategoryConfig.fallbackDefaults;
  }
});

/// Admin-managed event categories at `/admin/settings/event-categories`.
class AdminEventCategoriesScreen extends ConsumerWidget {
  const AdminEventCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(adminEventCategoriesProvider);

    return AdminPageLayout(
      title: 'Event categories',
      subtitle: 'Celebration types shown in the creation wizard',
      body: categories.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('Could not load categories: $e'),
        data: (items) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final cat in items)
              Padding(
                padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                child: EosSurfaceCard(
                  child: ListTile(
                    leading: Icon(Icons.celebration_outlined, color: EosColors.plum),
                    title: Text(cat.label),
                    subtitle: Text('${cat.slug} · ${cat.accessMode.apiValue}'),
                  ),
                ),
              ),
            Text(
              'Use the API POST /admin/settings/event-categories to add or edit entries.',
              style: context.eosText.bodySmall?.copyWith(color: EosColors.slate500),
            ),
          ],
        ),
      ),
    );
  }
}
