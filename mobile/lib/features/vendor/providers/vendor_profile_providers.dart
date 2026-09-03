import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/event_config_api.dart';
import '../../../core/api/owambe_http_client.dart';
import '../../../core/api/persistence_providers.dart';
import '../../../core/providers/silent_refresh.dart';
import '../../../portals/customer/providers/vendor_crm_providers.dart';
import '../../../profile/profile.dart';
import '../data/vendor_profile_repository.dart';
import '../models/vendor_workspace_profile.dart';

final vendorProfileRepositoryProvider = Provider<VendorProfileRepositoryImpl>((ref) {
  return VendorProfileRepositoryImpl(ref.watch(identityApiProvider));
});

final vendorProfileMediaUploaderProvider = Provider<ProfileMediaUploader>((ref) {
  return ProfileMediaUploader(ref.watch(mediaApiProvider));
});

/// Admin capability catalogue for Vendor Services & Availability.
/// Soft-polls via existing CRM live tick (invalidateSelf — no shell rebuild).
final vendorCapabilityCatalogueProvider =
    FutureProvider.autoDispose<List<VendorCategoryConfig>>((ref) async {
  refreshOnAsyncTick(ref, vendorCrmLiveTickProvider);
  return EventConfigApi(createOwambeHttpClient()).listVendorCategories();
});

final vendorWorkspaceProfileProvider =
    FutureProvider.autoDispose<VendorWorkspaceProfile>((ref) async {
  refreshOnAsyncTick(ref, vendorCrmLiveTickProvider);
  return ref.watch(vendorProfileRepositoryProvider).fetch();
});
