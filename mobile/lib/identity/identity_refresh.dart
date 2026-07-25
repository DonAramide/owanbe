import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_notifier.dart';
import 'identity_provider.dart';

/// Refreshes API identity and auth session through the single sync path.
Future<void> refreshSessionIdentity(
  Ref ref, {
  bool requireApiProfile = false,
}) async {
  final session = Supabase.instance.client.auth.currentSession;
  if (session == null) {
    ref.read(authSessionProvider.notifier).restoreSupabaseSession();
    return;
  }
  try {
    await ref.read(userIdentityProvider.notifier).refresh();
  } catch (e) {
    if (requireApiProfile) rethrow;
    ref.read(authSessionProvider.notifier).restoreSupabaseSession();
  }
}
