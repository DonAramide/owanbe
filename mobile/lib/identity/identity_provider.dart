import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_notifier.dart';
import '../core/api/identity_api.dart';
import '../core/api/persistence_providers.dart';
import '../core/bootstrap/shared_preferences_provider.dart';
import 'identity_sync.dart';
import 'user_identity.dart';
import 'workspace_models.dart';

const _activeWorkspaceKey = 'owanbe_active_workspace';

/// Full Owanbe 2.0 identity from GET /auth/me.
final userIdentityProvider =
    AsyncNotifierProvider<UserIdentityNotifier, OwanbeUserIdentity?>(UserIdentityNotifier.new);

/// UI context — which workspace experience is currently open.
final activeWorkspaceProvider =
    NotifierProvider<ActiveWorkspaceNotifier, ExperienceWorkspace?>(ActiveWorkspaceNotifier.new);

class UserIdentityNotifier extends AsyncNotifier<OwanbeUserIdentity?> {
  @override
  Future<OwanbeUserIdentity?> build() async {
    // Re-sync only when sign-in/out changes — not when auth session fields are enriched.
    ref.watch(authSessionProvider.select((s) => s?.userId));
    final session = ref.read(authSessionProvider);
    if (session == null) return null;
    // Prefer the live Supabase JWT; skip if session was cleared mid-build.
    if (Supabase.instance.client.auth.currentSession == null) return null;
    return _loadIdentity();
  }

  Future<OwanbeUserIdentity?> refresh() async {
    state = const AsyncLoading();
    final session = ref.read(authSessionProvider);
    if (session == null || Supabase.instance.client.auth.currentSession == null) {
      state = const AsyncData(null);
      return null;
    }
    try {
      final identity = await _loadIdentity(force: true);
      state = AsyncData(identity);
      return identity;
    } catch (e, st) {
      state = AsyncError(e, st);
      // Keep AsyncError for UI; callers that need the value still get the throw.
      rethrow;
    }
  }

  Future<OwanbeUserIdentity> _loadIdentity({bool force = false}) async {
    final supa = Supabase.instance.client.auth.currentUser;
    final displayNameHint = supa?.userMetadata?['display_name']?.toString();
    final coordinator = ref.read(identitySyncCoordinatorProvider);

    Future<OwanbeUserIdentity> once({required bool forceSync}) async {
      final me = await coordinator.synchronize(
        displayNameHint: displayNameHint,
        force: forceSync,
      );
      ref.read(authSessionProvider.notifier).applyIdentityFromApi(me);
      return OwanbeUserIdentity.fromAuthMe(
        me,
        displayName: me.displayName?.trim().isNotEmpty == true
            ? me.displayName
            : displayNameHint,
        avatarUrl: me.avatarUrl ?? supa?.userMetadata?['avatar_url']?.toString(),
      );
    }

    try {
      return await once(forceSync: force);
    } on IdentityApiException catch (e) {
      final stale = e.code == 'INVALID_TOKEN' ||
          e.message.toLowerCase().contains('invalid or expired token');
      if (!stale || Supabase.instance.client.auth.currentSession == null) {
        rethrow;
      }
      // One retry with a fresh sync after JWT rotation / race.
      coordinator.invalidate();
      return once(forceSync: true);
    }
  }
}

class ActiveWorkspaceNotifier extends Notifier<ExperienceWorkspace?> {
  @override
  ExperienceWorkspace? build() {
    ref.listen(authSessionProvider, (prev, next) {
      if (next == null) state = null;
    });
    final prefs = ref.read(sharedPreferencesProvider);
    final saved = prefs.getString(_activeWorkspaceKey);
    return ExperienceWorkspace.fromApiCode(saved);
  }

  Future<void> switchTo(ExperienceWorkspace workspace) async {
    state = workspace;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_activeWorkspaceKey, workspace.apiCode);
    try {
      await ref.read(identityApiProvider).setActiveWorkspace(workspace.apiCode);
    } catch (_) {
      // Local switch still works offline.
    }
  }

  Future<void> clear() async {
    state = null;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove(_activeWorkspaceKey);
  }

  /// Called by [workspaceIdentitySyncProvider] after identity loads — not during identity fetch.
  void applyIdentity(OwanbeUserIdentity identity) {
    final fromServer = ExperienceWorkspace.fromApiCode(identity.lastActiveWorkspace);
    if (fromServer != null && identity.canAccess(fromServer)) {
      if (state == null || !identity.canAccess(state!)) {
        state = fromServer;
        ref.read(sharedPreferencesProvider).setString(_activeWorkspaceKey, fromServer.apiCode);
      }
      return;
    }
    if (state != null && identity.canAccess(state!)) return;
    final suggested = identity.suggestedWorkspace;
    if (suggested != null) {
      state = suggested;
      ref.read(sharedPreferencesProvider).setString(_activeWorkspaceKey, suggested.apiCode);
    }
  }
}
