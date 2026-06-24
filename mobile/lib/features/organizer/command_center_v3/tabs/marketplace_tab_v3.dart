import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/vendors_api.dart';
import '../../../../eos/eos.dart';
import '../../../../portals/customer/models/marketplace_models.dart';
import '../../../../portals/customer/providers/marketplace_providers.dart';
import '../../../../portals/customer/widgets/marketplace/premium_vendor_card.dart';
import '../../models/organizer_models.dart';
import '../../providers/organizer_providers.dart';
import '../providers/event_command_center_v3_providers.dart';
import '../widgets/cc_v3_health_cards.dart';

class MarketplaceTabV3 extends ConsumerWidget {
  const MarketplaceTabV3({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapAsync = ref.watch(eventCommandCenterV3Provider(eventId));
    final vendorsAsync = ref.watch(marketplaceVendorsProvider);
    final categories = ref.watch(marketplaceCategoriesProvider);
    var category = ref.watch(_marketplaceCategoryProvider);

    return snapAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (snap) {
        final event = snap.event;
        return vendorsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (all) {
            final suggested = _smartSuggestions(all, event);
            var filtered = category == 'All' ? all : all.where((v) => v.matchesService(category)).toList();
            filtered.sort((a, b) => (b.ratingAverage ?? 0).compareTo(a.ratingAverage ?? 0));

            return SingleChildScrollView(
              padding: EdgeInsets.all(context.eos.spacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const CcV3SectionHeader(
                    title: 'Smart vendor suggestions',
                    subtitle: 'Matched to your event type, location, budget, and guest count',
                  ),
                  if (suggested.isEmpty)
                    EosSurfaceCard(child: Text('No suggestions yet.', style: context.eosText.bodyMedium))
                  else
                    SizedBox(
                      height: 280,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: suggested.length,
                        separatorBuilder: (_, _) => SizedBox(width: context.eos.spacing.md),
                        itemBuilder: (context, index) => SizedBox(
                          width: 300,
                          child: PremiumVendorCard(
                            vendor: suggested[index],
                            guestCount: event.expectedGuests > 0 ? event.expectedGuests : 150,
                            onTap: () => context.push('/vendors/${suggested[index].id}'),
                          ),
                        ),
                      ),
                    ),
                  SizedBox(height: context.eos.spacing.xl),
                  const CcV3SectionHeader(title: 'Browse by category'),
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
                          selected: category == cat,
                          onSelected: (_) => ref.read(_marketplaceCategoryProvider.notifier).state = cat,
                        );
                      },
                    ),
                  ),
                  SizedBox(height: context.eos.spacing.lg),
                  for (final vendor in filtered.take(12))
                    Padding(
                      padding: EdgeInsets.only(bottom: context.eos.spacing.md),
                      child: _MarketplaceVendorRow(
                        vendor: vendor,
                        eventId: eventId,
                        guestCount: event.expectedGuests > 0 ? event.expectedGuests : 150,
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<MarketplaceVendor> _smartSuggestions(List<MarketplaceVendor> all, OrganizerEvent event) {
    final city = event.city.toLowerCase();
    final slug = event.categorySlug.isNotEmpty ? event.categorySlug : event.category.toLowerCase();
    return all
        .where((v) {
          final cityMatch = city.isEmpty || (v.city ?? '').toLowerCase().contains(city);
          final typeMatch = slug.isEmpty || v.matchesService(slug) || v.matchesService(event.category);
          return cityMatch && typeMatch;
        })
        .take(6)
        .toList();
  }
}

final _marketplaceCategoryProvider = StateProvider.autoDispose<String>((ref) => 'All');

class _MarketplaceVendorRow extends StatelessWidget {
  const _MarketplaceVendorRow({
    required this.vendor,
    required this.eventId,
    required this.guestCount,
  });

  final MarketplaceVendor vendor;
  final String eventId;
  final int guestCount;

  @override
  Widget build(BuildContext context) {
    final profile = buildVendorProfile(vendor);
    return EosSurfaceCard(
      elevated: true,
      onTap: () => context.push('/vendors/${vendor.id}'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              vendor.imageUrl ?? vendorCoverImageUrl(vendor),
              width: 88,
              height: 88,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 88,
                height: 88,
                color: Color(profile.coverColorStart),
                child: const Icon(Icons.storefront, color: Colors.white),
              ),
            ),
          ),
          SizedBox(width: context.eos.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(vendor.businessName, style: context.eosText.titleSmall),
                Text(vendor.categoryLabel, style: context.eosText.bodySmall),
                if (vendor.ratingAverage != null)
                  Text('★ ${vendor.ratingAverage!.toStringAsFixed(1)} · Responds in ~2h', style: context.eosText.labelSmall),
                if (profile.pricePerGuestLabel(guestCount).isNotEmpty)
                  Text(profile.pricePerGuestLabel(guestCount), style: context.eosText.bodySmall),
              ],
            ),
          ),
          Column(
            children: [
              TextButton(onPressed: () => context.push('/vendors/${vendor.id}'), child: const Text('Profile')),
              OutlinedButton(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Request sent to ${vendor.businessName}')),
                ),
                child: const Text('Request'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
