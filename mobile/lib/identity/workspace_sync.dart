import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'identity_provider.dart';

/// Applies server identity to local workspace context — runs AFTER identity loads.
/// Decoupled from [UserIdentityNotifier._loadIdentity] to prevent startup coupling.
final workspaceIdentitySyncProvider = Provider<void>((ref) {
  ref.listen(userIdentityProvider, (previous, next) {
    next.whenData((identity) {
      if (identity != null) {
        ref.read(activeWorkspaceProvider.notifier).applyIdentity(identity);
      }
    });
  });
});
