import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/event_config_api.dart';
import '../../../core/api/owambe_http_client.dart';
import '../../../eos/eos.dart';
import '../widgets/admin_page_layout.dart';

final adminVendorCategoriesProvider = FutureProvider.autoDispose<List<VendorCategoryConfig>>((ref) async {
  try {
    final api = EventConfigApi(createOwambeHttpClient());
    return await api.adminListVendorCategories();
  } catch (_) {
    try {
      return await EventConfigApi(createOwambeHttpClient()).listVendorCategories();
    } catch (_) {
      return VendorCategoryConfig.fallbackDefaults;
    }
  }
});

/// Admin list of marketplace service categories. Open a row to edit capabilities.
class AdminVendorCategoriesScreen extends ConsumerWidget {
  const AdminVendorCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(adminVendorCategoriesProvider);

    return AdminPageLayout(
      title: 'Service Categories & Capability Catalogue',
      subtitle:
          'Admin defines marketplace categories and capability catalogues. '
          'Vendors select what they provide. Organizers request from that intersection. '
          'This does not change pricing or past requests.',
      actions: [
        TextButton.icon(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/super-admin');
            }
          },
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('Back'),
        ),
      ],
      body: categories.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('Could not load vendor categories: $e'),
        data: (items) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EosSurfaceCard(
              elevated: true,
              child: Text(
                '${items.length} marketplace service categories. Open a category to manage '
                'its capability catalogue and Marketplace visibility.',
                style: context.eosText.bodyMedium,
              ),
            ),
            SizedBox(height: context.eos.spacing.md),
            for (final cat in items)
              Padding(
                padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                child: EosSurfaceCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.storefront_outlined, color: EosColors.plum),
                    title: Text(cat.label),
                    subtitle: Text(
                      [
                        cat.slug,
                        cat.isActive ? 'Active' : 'Inactive',
                        cat.capabilities.isEmpty
                            ? 'No capabilities configured'
                            : '${cat.capabilities.where((c) => c.enabled).length} enabled · ${cat.capabilities.length} total',
                      ].join(' · '),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(
                      '/super-admin/commerce/vendor-capabilities/${cat.id}',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
