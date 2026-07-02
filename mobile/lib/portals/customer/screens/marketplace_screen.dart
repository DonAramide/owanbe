import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';
import '../models/marketplace_filters.dart';
import '../models/marketplace_models.dart';
import '../providers/marketplace_providers.dart';
import '../navigation/event_navigator.dart';
import '../workspace/widgets/event_friendly_errors.dart';
import '../workspace/widgets/event_loading_skeleton.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/marketplace/marketplace_filter_bar.dart';
import '../widgets/marketplace/premium_vendor_card.dart';
import '../widgets/section_header.dart';

/// Premium vendor marketplace at `/vendors`.
class MarketplaceScreen extends ConsumerWidget {
  const MarketplaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendors = ref.watch(marketplaceVendorsProvider);
    final filtered = ref.watch(marketplaceFilteredVendorsProvider);
    final categories = ref.watch(marketplaceCategoriesProvider);
    final cities = ref.watch(marketplaceCitiesProvider);
    final guestCount = ref.watch(marketplaceExpectedGuestsProvider);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.eventNav.goHome();
            }
          },
        ),
        title: const Text('Vendor marketplace'),
      ),
      body: vendors.when(
        loading: () => const EventLoadingSkeleton(variant: EventLoadingVariant.list),
        error: (_, _) => ListView(
          padding: EdgeInsets.all(context.eos.spacing.lg),
          children: [
            EmptyStateCard(
              title: EventFriendlyErrors.genericHeadline,
              message: EventFriendlyErrors.genericMessage,
              actionLabel: 'Back home',
              onAction: () => context.eventNav.goHome(),
            ),
          ],
        ),
        data: (_) {
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
                  subtitle: 'Search by service, name, city, price, or rating.',
                ),
                SizedBox(height: context.eos.spacing.md),
                OutlinedButton.icon(
                  onPressed: () => context.eventNav.openRentalsMarketplace(),
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text('Browse rentals'),
                ),
                SizedBox(height: context.eos.spacing.md),
                MarketplaceFilterBar(categories: categories, cities: cities),
                SizedBox(height: context.eos.spacing.sm),
                Text(
                  'Expected attendees: $guestCount (used for per-guest price estimates)',
                  style: context.eosText.bodySmall,
                ),
                Slider(
                  value: guestCount.toDouble(),
                  min: 50,
                  max: 500,
                  divisions: 18,
                  label: '$guestCount',
                  onChanged: (v) =>
                      ref.read(marketplaceExpectedGuestsProvider.notifier).state = v.round(),
                ),
                SizedBox(height: context.eos.spacing.lg),
                Text(
                  '${filtered.length} vendor${filtered.length == 1 ? '' : 's'}',
                  style: context.eosText.labelLarge,
                ),
                SizedBox(height: context.eos.spacing.sm),
                if (filtered.isEmpty)
                  const EmptyStateCard(
                    title: 'No vendors found',
                    message: 'Try another service, city, or filter.',
                    icon: Icons.storefront_outlined,
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = EosResponsive.columnsFor(context).clamp(1, 3);
                      final width =
                          (constraints.maxWidth - (columns - 1) * context.eos.spacing.md) / columns;

                      return Wrap(
                        spacing: context.eos.spacing.md,
                        runSpacing: context.eos.spacing.md,
                        children: [
                          for (final vendor in filtered)
                            SizedBox(
                              width: width,
                              child: PremiumVendorCard(
                                vendor: vendor,
                                coverColorStart: buildVendorProfile(vendor).coverColorStart,
                                coverColorEnd: buildVendorProfile(vendor).coverColorEnd,
                                priceLabel: buildVendorProfile(vendor).priceLabel,
                                guestCount: guestCount,
                                onTap: () => context.eventNav.openVendorDetail(vendor.id),
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
