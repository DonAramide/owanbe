import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/money.dart';
import '../../../../eos/eos.dart';
import '../../models/marketplace_filters.dart';

class MarketplaceFilterBar extends ConsumerWidget {
  const MarketplaceFilterBar({
    super.key,
    required this.categories,
    required this.cities,
  });

  final List<String> categories;
  final List<String> cities;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(marketplaceFiltersProvider);
    final activeCount = [
      if (filters.minRating > 0) 1,
      if (filters.maxPriceMinor > 0) 1,
      if (filters.city.isNotEmpty) 1,
      if (filters.sort != MarketplaceSort.recommended) 1,
    ].length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          decoration: const InputDecoration(
            hintText: 'Search name, service, city, or keyword',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (v) => ref.read(marketplaceFiltersProvider.notifier).state =
              filters.copyWith(query: v),
        ),
        SizedBox(height: context.eos.spacing.sm),
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
                selected: filters.serviceCategory == cat,
                onSelected: (_) => ref.read(marketplaceFiltersProvider.notifier).state =
                    filters.copyWith(serviceCategory: cat),
              );
            },
          ),
        ),
        SizedBox(height: context.eos.spacing.sm),
        Wrap(
          spacing: context.eos.spacing.xs,
          runSpacing: context.eos.spacing.xs,
          children: [
            ActionChip(
              avatar: const Icon(Icons.tune, size: 18),
              label: Text(activeCount > 0 ? 'Filters ($activeCount)' : 'More filters'),
              onPressed: () => _openSheet(context, ref, cities, filters),
            ),
            if (filters.minRating > 0)
              InputChip(
                label: Text('${filters.minRating}+ stars'),
                onDeleted: () => ref.read(marketplaceFiltersProvider.notifier).state =
                    filters.copyWith(minRating: 0),
              ),
            if (filters.maxPriceMinor > 0)
              InputChip(
                label: Text('Under ${formatRevenue(filters.maxPriceMinor)}'),
                onDeleted: () => ref.read(marketplaceFiltersProvider.notifier).state =
                    filters.copyWith(maxPriceMinor: 0),
              ),
            if (filters.city.isNotEmpty)
              InputChip(
                label: Text(filters.city),
                onDeleted: () => ref.read(marketplaceFiltersProvider.notifier).state =
                    filters.copyWith(city: ''),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _openSheet(
    BuildContext context,
    WidgetRef ref,
    List<String> cities,
    MarketplaceFilters filters,
  ) async {
    var local = filters;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                context.eos.spacing.lg,
                context.eos.spacing.lg,
                context.eos.spacing.lg,
                context.eos.spacing.lg + MediaQuery.viewInsetsOf(ctx).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Filter vendors', style: context.eosText.titleMedium),
                  SizedBox(height: context.eos.spacing.md),
                  Text('Minimum rating', style: context.eosText.labelLarge),
                  Slider(
                    value: local.minRating,
                    min: 0,
                    max: 5,
                    divisions: 10,
                    label: local.minRating == 0 ? 'Any' : local.minRating.toStringAsFixed(1),
                    onChanged: (v) => setLocal(() => local = local.copyWith(minRating: v)),
                  ),
                  Text('Max starting price', style: context.eosText.labelLarge),
                  Wrap(
                    spacing: context.eos.spacing.xs,
                    children: [
                      for (final cap in [0, 50000000, 100000000, 250000000, 500000000])
                        ChoiceChip(
                          label: Text(cap == 0 ? 'Any' : 'Under ${formatRevenue(cap)}'),
                          selected: local.maxPriceMinor == cap,
                          onSelected: (_) => setLocal(() => local = local.copyWith(maxPriceMinor: cap)),
                        ),
                    ],
                  ),
                  SizedBox(height: context.eos.spacing.sm),
                  DropdownButtonFormField<String>(
                    value: local.city.isEmpty ? '' : local.city,
                    decoration: const InputDecoration(labelText: 'City'),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('Any city')),
                      ...cities.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                    ],
                    onChanged: (v) => setLocal(() => local = local.copyWith(city: v ?? '')),
                  ),
                  SizedBox(height: context.eos.spacing.sm),
                  DropdownButtonFormField<MarketplaceSort>(
                    value: local.sort,
                    decoration: const InputDecoration(labelText: 'Sort by'),
                    items: const [
                      DropdownMenuItem(value: MarketplaceSort.recommended, child: Text('Recommended')),
                      DropdownMenuItem(value: MarketplaceSort.rating, child: Text('Highest rated')),
                      DropdownMenuItem(value: MarketplaceSort.priceLow, child: Text('Price: low to high')),
                      DropdownMenuItem(value: MarketplaceSort.priceHigh, child: Text('Price: high to low')),
                      DropdownMenuItem(value: MarketplaceSort.name, child: Text('Name A–Z')),
                    ],
                    onChanged: (v) {
                      if (v != null) setLocal(() => local = local.copyWith(sort: v));
                    },
                  ),
                  SizedBox(height: context.eos.spacing.lg),
                  FilledButton(
                    onPressed: () {
                      ref.read(marketplaceFiltersProvider.notifier).state = local;
                      Navigator.pop(ctx);
                    },
                    child: const Text('Apply filters'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
