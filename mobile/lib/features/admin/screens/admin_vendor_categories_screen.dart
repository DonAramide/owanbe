import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/api/event_config_api.dart';
import '../../../core/api/persistence_providers.dart';
import '../../../eos/eos.dart';
import '../widgets/admin_page_layout.dart';

final adminVendorCategoriesProvider = FutureProvider.autoDispose<List<VendorCategoryConfig>>((ref) async {
  try {
    final api = EventConfigApi(http.Client());
    return await api.listVendorCategories();
  } catch (_) {
    if (!allowMockPersistenceFallback()) rethrow;
    return VendorCategoryConfig.fallbackDefaults;
  }
});

/// Admin-managed vendor service categories (Settings → Vendor categories).
class AdminVendorCategoriesScreen extends ConsumerWidget {
  const AdminVendorCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(adminVendorCategoriesProvider);

    return AdminPageLayout(
      title: 'Vendor service categories',
      subtitle: 'Services used in marketplace filters and the event creation wizard',
      body: categories.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('Could not load vendor categories: $e'),
        data: (items) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EosSurfaceCard(
              elevated: true,
              child: Text(
                '${items.length} service categories configured for this tenant.',
                style: context.eosText.bodyMedium,
              ),
            ),
            SizedBox(height: context.eos.spacing.md),
            for (final cat in items)
              Padding(
                padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                child: EosSurfaceCard(
                  child: ListTile(
                    leading: Icon(Icons.storefront_outlined, color: EosColors.plum),
                    title: Text(cat.label),
                    subtitle: Text(cat.slug),
                  ),
                ),
              ),
            Text(
              'Categories auto-seed on first API call. Manage via POST /admin/settings/vendor-categories or Supabase tenant_vendor_categories.',
              style: context.eosText.bodySmall?.copyWith(color: EosColors.slate500),
            ),
          ],
        ),
      ),
    );
  }
}
