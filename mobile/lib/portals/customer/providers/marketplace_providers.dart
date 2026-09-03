import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/persistence_providers.dart';
import '../../../core/api/vendors_api.dart';
import '../../../core/providers/silent_refresh.dart';
import '../models/marketplace_filters.dart';
import '../models/marketplace_models.dart';
import '../models/vendor_crm_models.dart';
import 'customer_event_providers.dart';
import 'customer_home_providers.dart';
import 'vendor_crm_providers.dart';

final marketplaceVendorsProvider = FutureProvider.autoDispose<List<MarketplaceVendor>>((ref) async {
  ref.watch(customerHomeRefreshProvider);
  final filters = ref.watch(marketplaceFiltersProvider);

  final query = filters.query.trim();
  List<MarketplaceVendor> vendors;
  try {
    vendors = await ref.read(vendorsApiProvider).listCatalog(
          query: query.isEmpty ? null : query,
          city: filters.city.trim().isEmpty ? null : filters.city.trim(),
          service: filters.serviceCategory == 'All' ? null : filters.serviceCategory,
        );
  } catch (_) {
    // Never substitute the unfiltered catalog for a failed search — that
    // re-introduces identity leaks via client-side slug/seed-name matches.
    if (query.isNotEmpty) rethrow;
    vendors = await ref.read(customerMarketplaceVendorsProvider.future);
  }

  return enrichCatalog(vendors);
});

/// Booked (vendorId, serviceKey) pairs — excludes only that service from discovery.
final eventBookedVendorServiceKeysProvider =
    Provider.autoDispose.family<Set<String>, String>((ref, eventId) {
  final keys = <String>{};
  final crm = ref.watch(eventVendorCrmProvider(eventId)).valueOrNull;
  if (crm != null) {
    for (final r in crm.items) {
      if (r.stage == 'declined' || r.stage == 'cancelled') continue;
      final sk = (r.serviceKey ?? r.serviceLabel ?? 'general').toLowerCase().trim();
      keys.add('${r.vendorId}|$sk');
    }
  }
  return keys;
});

/// @Deprecated — whole-vendor hide. Prefer [eventBookedVendorServiceKeysProvider].
final eventBookedVendorIdsProvider = Provider.autoDispose.family<Set<String>, String>((ref, eventId) {
  final ids = <String>{};
  final crm = ref.watch(eventVendorCrmProvider(eventId)).valueOrNull;
  if (crm != null) {
    for (final r in crm.items) {
      if (r.stage == 'declined' || r.stage == 'cancelled') continue;
      ids.add(r.vendorId);
    }
  }
  final event = ref.watch(customerEventProvider(eventId)).valueOrNull;
  if (event != null) {
    for (final v in event.vendors) {
      final catalogId = v.catalogVendorId ?? v.id;
      if (catalogId.isNotEmpty) ids.add(catalogId);
    }
  }
  return ids;
});

/// Active CRM bookings for "My Booked Vendors" (not marketplace discovery).
final eventBookedVendorRequestsProvider =
    Provider.autoDispose.family<List<VendorRequest>, String>((ref, eventId) {
  final crm = ref.watch(eventVendorCrmProvider(eventId)).valueOrNull;
  if (crm == null) return const [];
  return crm.items.where((r) => r.stage != 'declined' && r.stage != 'cancelled').toList();
});

final marketplaceFilteredVendorsProvider = Provider.autoDispose<List<MarketplaceVendor>>((ref) {
  final filters = ref.watch(marketplaceFiltersProvider);
  final vendors = ref.watch(marketplaceVendorsProvider);
  final list = vendors.valueOrNull;
  if (list == null) return const [];
  final activeVendors = list.where((v) => v.id != 'vend_3' && v.id != 'suspended_v').toList();
  return applyMarketplaceFilters(activeVendors, filters);
});

/// Discovery list for an optional event: category filters applied; only the
/// matching service booking is excluded (same vendor can still offer other services).
final marketplaceDiscoverVendorsProvider =
    Provider.autoDispose.family<List<MarketplaceVendor>, String?>((ref, eventId) {
  final filtered = ref.watch(marketplaceFilteredVendorsProvider);
  if (eventId == null || eventId.isEmpty) return filtered;
  final bookedKeys = ref.watch(eventBookedVendorServiceKeysProvider(eventId));
  final filters = ref.watch(marketplaceFiltersProvider);
  final serviceNeedle = filters.serviceCategory.toLowerCase().trim();
  if (bookedKeys.isEmpty) return filtered;
  if (serviceNeedle.isEmpty || serviceNeedle == 'all') {
    // When browsing "All", hide vendor only if every offered service is booked —
    // otherwise keep them visible for remaining services.
    return filtered.where((v) {
      final offered = v.servicesOffered.isNotEmpty
          ? v.servicesOffered
          : [v.categoryLabel];
      final allBooked = offered.every((s) {
        final sk = s.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
        return bookedKeys.contains('${v.id}|$sk') ||
            bookedKeys.contains('${v.id}|${s.toLowerCase().trim()}');
      });
      return !allBooked;
    }).toList();
  }
  final sk = serviceNeedle.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  return filtered.where((v) {
    return !bookedKeys.contains('${v.id}|$sk') &&
        !bookedKeys.contains('${v.id}|$serviceNeedle');
  }).toList();
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
      'DJ',
      'MC',
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
  // Soft-poll capabilities / services while profile stays open (no shell rebuild).
  refreshOnAsyncTick(ref, vendorCrmLiveTickProvider);
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

  var resolved = vendor;

  // Prefer dedicated services endpoint so organizer always sees ids + prices.
  try {
    final services = await ref.read(vendorsApiProvider).listVendorServices(vendorId);
    if (services.isNotEmpty) {
      resolved = resolved.copyWith(
        services: services,
        servicesOffered: services.map((s) => s.serviceName).toList(),
      );
    }
  } catch (_) {
    // Catalog may already include services[]; keep vendor as-is.
  }

  return buildVendorProfile(resolved);
});

/// Active vendor_services for a marketplace vendor (ids for service-specific requests).
final marketplaceVendorServicesProvider =
    FutureProvider.autoDispose.family<List<MarketplaceVendorService>, String>((ref, vendorId) async {
  final profile = await ref.watch(marketplaceVendorProfileProvider(vendorId).future);
  if (profile.vendor.services.isNotEmpty) return profile.vendor.services;
  try {
    return await ref.read(vendorsApiProvider).listVendorServices(vendorId);
  } catch (_) {
    return const [];
  }
});

/// Organizer-visible services with availability for the locked event window.
final marketplaceVendorServicesForEventProvider = FutureProvider.autoDispose
    .family<List<MarketplaceVendorService>, ({String vendorId, String eventId})>((ref, key) async {
  refreshOnAsyncTick(ref, vendorCrmLiveTickProvider);
  DateTime? from;
  DateTime? to;
  if (key.eventId.isNotEmpty) {
    try {
      final event = await ref.watch(customerEventProvider(key.eventId).future);
      from = event?.startsAt;
      to = event?.endsAt;
    } catch (_) {
      // Event lookup is best-effort; services still list without a date window.
    }
  }
  return ref.read(vendorsApiProvider).listVendorServices(key.vendorId, from: from, to: to);
});

/// Occupancy browser for one vendor over a display range (one request, not per day).
final marketplaceVendorServicesForRangeProvider = FutureProvider.autoDispose
    .family<List<MarketplaceVendorService>, ({String vendorId, String from, String to})>((ref, key) async {
  refreshOnAsyncTick(ref, vendorCrmLiveTickProvider);
  return ref.read(vendorsApiProvider).listVendorServices(
        key.vendorId,
        from: DateTime.parse(key.from),
        to: DateTime.parse(key.to),
      );
});
