import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';
import '../models/marketplace_models.dart';
import '../providers/marketplace_providers.dart';
import '../router/customer_routes.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/marketplace/premium_vendor_card.dart';
import '../widgets/section_header.dart';

/// Premium vendor marketplace at `/vendors`.
class MarketplaceScreen extends ConsumerWidget {
  const MarketplaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendors = ref.watch(marketplaceVendorsProvider);
    final categories = ref.watch(marketplaceCategoriesProvider);
    final selectedCategory = ref.watch(marketplaceCategoryProvider);

    return Scaffold(
      backgroundColor: EosColors.canvas,
      appBar: AppBar(
        backgroundColor: EosColors.canvas,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(CustomerRoutes.home);
            }
          },
        ),
        title: const Text('Vendor marketplace'),
      ),
      body: vendors.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ListView(
          padding: EdgeInsets.all(context.eos.spacing.lg),
          children: [
            EmptyStateCard(
              title: 'Could not load vendors',
              message: error.toString(),
              actionLabel: 'Back home',
              onAction: () => context.go(CustomerRoutes.home),
            ),
          ],
        ),
        data: (list) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(marketplaceVendorsProvider);
              await ref.read(marketplaceVendorsProvider.future);
            },
            child: ListView(
              padding: EdgeInsets.all(context.eos.spacing.lg),
              children: [
                const SectionHeader(
                  title: 'Find your dream team',
                  subtitle: 'Premium caterers, DJs, photographers, and décor for your celebration.',
                ),
                SizedBox(height: context.eos.spacing.md),
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search vendors, categories, or cities',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => ref.read(marketplaceSearchProvider.notifier).state = v,
                ),
                SizedBox(height: context.eos.spacing.md),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (_, _) => SizedBox(width: context.eos.spacing.xs),
                    itemBuilder: (context, index) {
                      final cat = categories[index];
                      return FilterChip(
                        label: Text(cat),
                        selected: selectedCategory == cat,
                        onSelected: (_) => ref.read(marketplaceCategoryProvider.notifier).state = cat,
                      );
                    },
                  ),
                ),
                SizedBox(height: context.eos.spacing.lg),
                if (list.isEmpty)
                  const EmptyStateCard(
                    title: 'No vendors found',
                    message: 'Try another search or category.',
                    icon: Icons.storefront_outlined,
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = EosResponsive.columnsFor(context).clamp(1, 3);
                      final width = (constraints.maxWidth - (columns - 1) * context.eos.spacing.md) / columns;

                      return Wrap(
                        spacing: context.eos.spacing.md,
                        runSpacing: context.eos.spacing.md,
                        children: [
                          for (final vendor in list)
                            SizedBox(
                              width: width,
                              child: PremiumVendorCard(
                                vendor: vendor,
                                coverColorStart: buildVendorProfile(vendor).coverColorStart,
                                coverColorEnd: buildVendorProfile(vendor).coverColorEnd,
                                onTap: () => context.push(CustomerRoutes.vendorDetail(vendor.id)),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                SizedBox(height: context.eos.spacing.xl),
              ],
            ),
          );
        },
      ),
    );
  }
}
