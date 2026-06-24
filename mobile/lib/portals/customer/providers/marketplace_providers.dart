import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/persistence_providers.dart';
import '../../../core/api/vendors_api.dart';
import '../models/marketplace_filters.dart';
import '../models/marketplace_models.dart';
import 'customer_home_providers.dart';

final marketplaceVendorsProvider = FutureProvider.autoDispose<List<MarketplaceVendor>>((ref) async {
  ref.watch(customerHomeRefreshProvider);

  List<MarketplaceVendor> vendors;
  try {
    vendors = await ref.read(vendorsApiProvider).listCatalog();
    if (vendors.isEmpty) {
      vendors = await ref.read(customerMarketplaceVendorsProvider.future);
    }
  } catch (_) {
    vendors = await ref.read(customerMarketplaceVendorsProvider.future);
  }

  return enrichCatalog(vendors);
});

final marketplaceFilteredVendorsProvider = Provider.autoDispose<List<MarketplaceVendor>>((ref) {
  final filters = ref.watch(marketplaceFiltersProvider);
  final vendors = ref.watch(marketplaceVendorsProvider);
  return vendors.when(
    data: (list) => applyMarketplaceFilters(list, filters),
    loading: () => const [],
    error: (_, _) => const [],
  );
});

final marketplaceCategoriesProvider = Provider.autoDispose<List<String>>((ref) {
  final vendors = ref.watch(marketplaceVendorsProvider);
  return vendors.when(
    data: marketplaceServiceCategories,
    loading: () => const [
      'All',
      'Rentals & Event Equipment',
      'Chairs',
      'Tents',
      'Aso-Ebi',
      'Traditional Wear',
      'Wedding Gowns',
      'Venue',
      'Catering',
      'Decorator',
      'Photographer',
    ],
    error: (_, _) => const ['All'],
  );
});

final marketplaceCitiesProvider = Provider.autoDispose<List<String>>((ref) {
  final vendors = ref.watch(marketplaceVendorsProvider);
  return vendors.when(
    data: marketplaceCities,
    loading: () => const ['Lagos', 'Abuja'],
    error: (_, _) => const [],
  );
});

final marketplaceVendorProfileProvider =
    FutureProvider.autoDispose.family<VendorProfile, String>((ref, vendorId) async {
  MarketplaceVendor? vendor;
  try {
    vendor = await ref.read(vendorsApiProvider).getVendor(vendorId);
  } catch (_) {
    vendor = null;
  }

  if (vendor == null) {
    final catalog = await ref.read(marketplaceVendorsProvider.future);
    for (final item in catalog) {
      if (item.id == vendorId) {
        vendor = item;
        break;
      }
    }
  }

  if (vendor == null) {
    throw StateError('Vendor not found');
  }

  return buildVendorProfile(vendor);
});
