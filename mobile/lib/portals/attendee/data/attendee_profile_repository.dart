import '../../../core/api/identity_api.dart';
import '../../../profile/repository/profile_repository.dart';
import '../models/attendee_profile.dart';

/// Dedicated Attendee workspace profile repository.
///
/// Persists only via `/me/attendee-profile` → `attendee_profiles`.
/// Never writes Global User Profile (`users`) fields.
class AttendeeProfileRepositoryImpl extends AttendeeProfileRepository {
  AttendeeProfileRepositoryImpl(this._api);

  final IdentityApi _api;

  Future<AttendeeProfile> fetch() async {
    final json = await _api.fetchAttendeeProfileRaw();
    return AttendeeProfile.fromJson(json);
  }

  Future<AttendeeProfile> save(AttendeeProfileUpdate update) async {
    final json = await _api.updateAttendeeProfileRaw(update.toJson());
    return AttendeeProfile.fromJson(json);
  }
}
