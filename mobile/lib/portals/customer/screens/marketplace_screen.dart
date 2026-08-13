import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';
import '../models/marketplace_filters.dart';
import '../models/marketplace_models.dart';
import '../models/vendor_crm_models.dart';
import '../providers/marketplace_providers.dart';
import '../providers/vendor_crm_providers.dart';
import '../navigation/event_navigator.dart';
import '../workspace/widgets/event_friendly_errors.dart';
import '../workspace/widgets/event_loading_skeleton.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/marketplace/marketplace_filter_bar.dart';
import '../widgets/marketplace/premium_vendor_card.dart';
import '../widgets/section_header.dart';

/// Premium vendor marketplace at `/vendors`.
class MarketplaceScreen extends ConsumerStatefulWidget {
  const MarketplaceScreen({
    super.key,
    this.eventId,
    this.initialCategory,
  });

  /// When set, vendor requests and back navigation are scoped to this event.
  final String? eventId;

  /// Service category from planning task (e.g. Catering, DJ, Photographer).
  final String? initialCategory;

  @override
  ConsumerState<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends ConsumerState<MarketplaceScreen> {
  @override
  void initState() {
    super.initState();
    final category = widget.initialCategory?.trim();
    if (category != null && category.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final current = ref.read(marketplaceFiltersProvider);
        ref.read(marketplaceFiltersProvider.notifier).state = current.copyWith(
          serviceCategory: category,
        );
      });
    }
  }

  void _handleBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else if (widget.eventId != null && widget.eventId!.isNotEmpty) {
      context.eventNav.backToOverview(widget.eventId!);
    } else {
      context.eventNav.goHome();
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventId = widget.eventId;
    final vendors = ref.watch(marketplaceVendorsProvider);
    final discover = ref.watch(marketplaceDiscoverVendorsProvider(eventId));
    final categories = ref.watch(marketplaceCategoriesProvider);
    final cities = ref.watch(marketplaceCitiesProvider);
    final guestCount = ref.watch(marketplaceExpectedGuestsProvider);
    final filters = ref.watch(marketplaceFiltersProvider);
    final booked = eventId != null && eventId.isNotEmpty
        ? ref.watch(eventBookedVendorRequestsProvider(eventId))
        : const <VendorRequest>[];

    final categoryTitle = filters.serviceCategory != 'All' ? filters.serviceCategory : null;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _handleBack(context),
        ),
        title: Text(
          categoryTitle != null ? '$categoryTitle marketplace' : 'Vendor marketplace',
        ),
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
              if (eventId != null) {
                refreshVendorCrm(ref);
                ref.invalidate(eventVendorCrmProvider(eventId));
              }
              await ref.read(marketplaceVendorsProvider.future);
            },
            child: ListView(
              padding: EdgeInsets.all(context.eos.spacing.lg),
              children: [
                SectionHeader(
                  title: categoryTitle != null
                      ? 'Find $categoryTitle vendors'
                      : 'Find your dream team',
                  subtitle: categoryTitle != null
                      ? 'Only vendors matching $categoryTitle. Booked vendors are listed separately.'
                      : 'Search by service, name, city, price, or rating.',
                ),
                SizedBox(height: context.eos.spacing.md),
                OutlinedButton.icon(
                  onPressed: () => context.eventNav.openRentalsMarketplace(eventId: eventId),
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
                if (booked.isNotEmpty) ...[
                  SizedBox(height: context.eos.spacing.lg),
                  const SectionHeader(
                    title: 'My Booked Vendors',
                    subtitle: 'Already requested or booked for this event — not shown in discovery.',
                  ),
                  SizedBox(height: context.eos.spacing.sm),
                  for (final req in booked)
                    Card(
                      margin: EdgeInsets.only(bottom: context.eos.spacing.sm),
                      child: ListTile(
                        title: Text(req.vendorName ?? 'Vendor'),
                        subtitle: Text(
                          [
                            if (req.serviceLabel != null && req.serviceLabel!.isNotEmpty) req.serviceLabel!,
                            vendorCrmStageLabels[req.stage] ?? req.stage,
                          ].join(' · '),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: eventId == null
                            ? null
                            : () => context.eventNav.openVendorPipeline(eventId),
                      ),
                    ),
                ],
                SizedBox(height: context.eos.spacing.lg),
                Text(
                  '${discover.length} available vendor${discover.length == 1 ? '' : 's'}',
                  style: context.eosText.labelLarge,
                ),
                SizedBox(height: context.eos.spacing.sm),
                if (discover.isEmpty)
                  EmptyStateCard(
                    title: 'No vendors found',
                    message: categoryTitle != null
                        ? 'No available $categoryTitle vendors match your filters.'
                        : 'Try another service, city, or filter.',
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
                          for (final vendor in discover)
                            SizedBox(
                              width: width,
                              child: PremiumVendorCard(
                                vendor: vendor,
                                coverColorStart: buildVendorProfile(vendor).coverColorStart,
                                coverColorEnd: buildVendorProfile(vendor).coverColorEnd,
                                priceLabel: buildVendorProfile(vendor).priceLabel,
                                guestCount: guestCount,
                                onTap: () => context.eventNav.openVendorDetail(
                                  vendor.id,
                                  eventId: eventId,
                                  service: filters.serviceCategory == 'All'
                                      ? null
                                      : filters.serviceCategory,
                                ),
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
