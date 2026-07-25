import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/persistence_providers.dart';
import '../data/attendee_profile_repository.dart';
import '../models/attendee_profile.dart';

final attendeeProfileRepositoryProvider = Provider<AttendeeProfileRepositoryImpl>((ref) {
  return AttendeeProfileRepositoryImpl(ref.watch(identityApiProvider));
});

final attendeeProfileProvider = FutureProvider.autoDispose<AttendeeProfile>((ref) async {
  return ref.watch(attendeeProfileRepositoryProvider).fetch();
});
