import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/vendors_api.dart';
import '../../../../eos/eos.dart';
import '../../../../portals/customer/models/marketplace_models.dart';
import '../../../../portals/customer/providers/marketplace_providers.dart';
import '../../../../portals/customer/widgets/marketplace/verified_vendor_badge.dart';

/// Vendor pick list with checkboxes for the creation wizard.
class WizardVendorPicker extends ConsumerWidget {
  const WizardVendorPicker({
    super.key,
    required this.serviceCategories,
    required this.selectedIds,
    required this.onToggle,
    this.cityHint,
  });

  final List<String> serviceCategories;
  final Set<String> selectedIds;
  final void Function(MarketplaceVendor vendor, bool selected) onToggle;
  final String? cityHint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendorsAsync = ref.watch(marketplaceVendorsProvider);
  var filterCategory = ref.watch(_wizardServiceFilterProvider);

    return vendorsAsync.when(
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
      error: (_, _) => Text('Could not load vendors', style: context.eosText.bodyMedium),
      data: (all) {
        var vendors = all;
        if (filterCategory != 'All') {
          vendors = vendors.where((v) => v.matchesService(filterCategory)).toList();
        }
        if (cityHint != null && cityHint!.trim().isNotEmpty) {
          final city = cityHint!.trim().toLowerCase();
          vendors = vendors
              .where((v) => (v.city ?? '').toLowerCase().contains(city) || city.isEmpty)
              .toList();
        }
        vendors.sort((a, b) => (b.ratingAverage ?? 0).compareTo(a.ratingAverage ?? 0));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: serviceCategories.length + 1,
                separatorBuilder: (_, _) => SizedBox(width: context.eos.spacing.xs),
                itemBuilder: (context, index) {
                  final cat = index == 0 ? 'All' : serviceCategories[index - 1];
                  return FilterChip(
                    label: Text(cat),
                    selected: filterCategory == cat,
                    onSelected: (_) => ref.read(_wizardServiceFilterProvider.notifier).state = cat,
                  );
                },
              ),
            ),
            SizedBox(height: context.eos.spacing.md),
            if (vendors.isEmpty)
              EosSurfaceCard(
                child: Text(
                  'No vendors for $filterCategory yet. Try All or add vendors in Admin → Vendor categories.',
                  style: context.eosText.bodyMedium,
                ),
              )
            else
              for (final vendor in vendors)
                Padding(
                  padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                  child: _SelectableVendorTile(
                    vendor: vendor,
                    selected: selectedIds.contains(vendor.id),
                    onChanged: (on) => onToggle(vendor, on),
                  ),
                ),
            if (selectedIds.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: context.eos.spacing.sm),
                child: Text(
                  '${selectedIds.length} vendor${selectedIds.length == 1 ? '' : 's'} selected',
                  style: context.eosText.labelLarge?.copyWith(color: EosColors.plum),
                ),
              ),
          ],
        );
      },
    );
  }
}

final _wizardServiceFilterProvider = StateProvider.autoDispose<String>((ref) => 'All');

class _SelectableVendorTile extends StatelessWidget {
  const _SelectableVendorTile({
    required this.vendor,
    required this.selected,
    required this.onChanged,
  });

  final MarketplaceVendor vendor;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final profile = buildVendorProfile(vendor);
    final price = profile.priceLabel;
    final imageUrl = vendor.imageUrl ?? vendorCoverImageUrl(vendor);

    return EosSurfaceCard(
      elevated: selected,
      onTap: () => onChanged(!selected),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(value: selected, onChanged: (v) => onChanged(v ?? false)),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              imageUrl,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 56,
                height: 56,
                color: Color(profile.coverColorStart),
                child: Icon(Icons.storefront, color: Colors.white.withValues(alpha: 0.9)),
              ),
            ),
          ),
          SizedBox(width: context.eos.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(vendor.businessName, style: context.eosText.titleSmall),
                    ),
                    if (vendor.isVerified) const VerifiedVendorBadge(compact: true),
                  ],
                ),
                Text(vendor.categoryLabel, style: context.eosText.bodySmall),
                SizedBox(height: context.eos.spacing.xxs),
                Row(
                  children: [
                    if (vendor.ratingAverage != null) ...[
                      Icon(Icons.star_rounded, size: 16, color: EosColors.champagne),
                      Text(' ${vendor.ratingAverage!.toStringAsFixed(1)}', style: context.eosText.bodySmall),
                    ],
                    if (vendor.city != null) ...[
                      const SizedBox(width: 8),
                      Text('· ${vendor.city}', style: context.eosText.bodySmall),
                    ],
                    if (price != null) ...[
                      const Spacer(),
                      Text(price, style: context.eosText.labelMedium),
                    ],
                  ],
                ),
                if (profile.pricePerGuestLabel(150).isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: context.eos.spacing.xxs),
                    child: Text(profile.pricePerGuestLabel(150), style: context.eosText.bodySmall),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
