import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/persistence_providers.dart';
import '../../../profile/profile.dart';
import '../data/organizer_profile_repository.dart';
import '../models/organizer_workspace_profile.dart';

final organizerProfileRepositoryProvider = Provider<OrganizerProfileRepositoryImpl>((ref) {
  return OrganizerProfileRepositoryImpl(ref.watch(identityApiProvider));
});

final organizerProfileMediaUploaderProvider = Provider<ProfileMediaUploader>((ref) {
  return ProfileMediaUploader(ref.watch(mediaApiProvider));
});

final organizerWorkspaceProfileProvider =
    FutureProvider.autoDispose<OrganizerWorkspaceProfile>((ref) async {
  return ref.watch(organizerProfileRepositoryProvider).fetch();
});
