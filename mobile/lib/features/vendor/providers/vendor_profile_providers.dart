import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/persistence_providers.dart';
import '../../../profile/profile.dart';
import '../data/vendor_profile_repository.dart';
import '../models/vendor_workspace_profile.dart';

final vendorProfileRepositoryProvider = Provider<VendorProfileRepositoryImpl>((ref) {
  return VendorProfileRepositoryImpl(ref.watch(identityApiProvider));
});

final vendorProfileMediaUploaderProvider = Provider<ProfileMediaUploader>((ref) {
  return ProfileMediaUploader(ref.watch(mediaApiProvider));
});

final vendorWorkspaceProfileProvider =
    FutureProvider.autoDispose<VendorWorkspaceProfile>((ref) async {
  return ref.watch(vendorProfileRepositoryProvider).fetch();
});
