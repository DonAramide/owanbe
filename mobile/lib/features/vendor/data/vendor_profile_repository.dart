import '../../../core/api/identity_api.dart';
import '../../../profile/repository/profile_repository.dart';
import '../models/vendor_workspace_profile.dart';

/// Dedicated Vendor workspace profile repository.
///
/// Persists only via `/me/vendor-profile` → `vendor_profiles`.
/// Never writes Global (`users`), Attendee, or Organizer profile stores.
class VendorProfileRepositoryImpl extends VendorProfileRepository {
  VendorProfileRepositoryImpl(this._api);

  final IdentityApi _api;

  Future<VendorWorkspaceProfile> fetch() async {
    final json = await _api.fetchVendorWorkspaceProfileRaw();
    return VendorWorkspaceProfile.fromJson(json);
  }

  Future<VendorWorkspaceProfile> save(VendorWorkspaceProfileUpdate update) async {
    final json = await _api.updateVendorWorkspaceProfileRaw(update.toJson());
    return VendorWorkspaceProfile.fromJson(json);
  }
}
