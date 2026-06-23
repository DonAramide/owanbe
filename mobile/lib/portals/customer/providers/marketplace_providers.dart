import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/persistence_providers.dart';
import '../../../core/api/vendors_api.dart';
import '../models/marketplace_models.dart';
import 'customer_home_providers.dart';

final marketplaceSearchProvider = StateProvider.autoDispose<String>((ref) => '');

final marketplaceCategoryProvider = StateProvider.autoDispose<String>((ref) => 'All');

final marketplaceVendorsProvider = FutureProvider.autoDispose<List<MarketplaceVendor>>((ref) async {
  ref.watch(customerHomeRefreshProvider);
  final query = ref.watch(marketplaceSearchProvider);
  final category = ref.watch(marketplaceCategoryProvider);

  List<MarketplaceVendor> vendors;
  try {
    vendors = await ref.read(vendorsApiProvider).listCatalog(
          query: query.isEmpty ? null : query,
        );
    if (vendors.isEmpty) {
      vendors = await ref.read(customerMarketplaceVendorsProvider.future);
    }
  } catch (_) {
    vendors = await ref.read(customerMarketplaceVendorsProvider.future);
  }

  vendors = enrichCatalog(vendors);

  if (category != 'All') {
    vendors = vendors.where((v) => v.categoryLabel == category).toList();
  }

  if (query.isNotEmpty) {
    final q = query.toLowerCase();
    vendors = vendors
        .where(
          (v) =>
              v.businessName.toLowerCase().contains(q) ||
              v.categoryLabel.toLowerCase().contains(q) ||
              (v.city ?? '').toLowerCase().contains(q),
        )
        .toList();
  }

  return vendors;
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

final marketplaceCategoriesProvider = Provider.autoDispose<List<String>>((ref) {
  final vendors = ref.watch(marketplaceVendorsProvider);
  return vendors.when(
    data: (list) {
      final cats = list.map((v) => v.categoryLabel).toSet().toList()..sort();
      return ['All', ...cats];
    },
    loading: () => const ['All', 'Catering', 'DJ & Music', 'Photography', 'Décor'],
    error: (_, _) => const ['All'],
  );
});
