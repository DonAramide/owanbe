import '../../../core/api/identity_api.dart';
import '../../../profile/repository/profile_repository.dart';
import '../models/organizer_workspace_profile.dart';

/// Dedicated Organizer workspace profile repository.
///
/// Persists only via `/me/organizer-profile` → `organizer_profiles`.
/// Never writes Global (`users`), Attendee, or Vendor profile stores.
class OrganizerProfileRepositoryImpl extends OrganizerProfileRepository {
  OrganizerProfileRepositoryImpl(this._api);

  final IdentityApi _api;

  Future<OrganizerWorkspaceProfile> fetch() async {
    final json = await _api.fetchOrganizerWorkspaceProfileRaw();
    return OrganizerWorkspaceProfile.fromJson(json);
  }

  Future<OrganizerWorkspaceProfile> save(OrganizerWorkspaceProfileUpdate update) async {
    final json = await _api.updateOrganizerWorkspaceProfileRaw(update.toJson());
    return OrganizerWorkspaceProfile.fromJson(json);
  }
}
