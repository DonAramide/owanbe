import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_session.dart';
import 'app_entrypoint.dart';
import 'portal_role.dart';
import 'user_role.dart';
import '../core/api/identity_api.dart';
import '../core/api/owanbe_api_auth.dart';
import '../core/bootstrap/shared_preferences_provider.dart';
import '../platform/bootstrap/bootstrap.dart';
import 'auth_portal_error.dart';
import '../platform/identity/identity_models.dart' as platform;
import '../platform/identity/identity_platform.dart' as platform;
import '../identity/identity_refresh.dart';
import '../identity/identity_sync.dart';
import '../identity/workspace_models.dart';
import '../identity/workspace_providers.dart';
import '../router/portal_routes.dart';
import '../supabase/supabase_config.dart';
import '../supabase/supabase_diagnostic.dart';

/// Holds the signed-in user. `null` = logged out.
class AuthNotifier extends Notifier<AuthSession?> {
  static const _pendingPortalRoleKey = 'owanbe_pending_portal_role';
  static const _pendingIsSignUpKey = 'owanbe_pending_is_sign_up';
  static const _pendingGoogleOAuthKey = 'owanbe_pending_google_oauth';
  static const _universalGoogleOAuthKey = 'owanbe_universal_google_oauth';

  StreamSubscription<AuthState>? _authSub;
  bool _portalHandoffInProgress = false;
  bool _signOutInProgress = false;

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override  AuthSession? build() {
    _authSub?.cancel();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((event) async {
      if (_signOutInProgress) return;

      final session = event.session;
      if (session == null) {
        state = null;
        return;
      }

      if (_portalHandoffInProgress) {
        return;
      }

      final prefs = _prefs;
      final googlePending = prefs.getBool(_pendingGoogleOAuthKey) ?? false;
      final universalGoogle = prefs.getBool(_universalGoogleOAuthKey) ?? false;
      final pendingRole = prefs.getString(_pendingPortalRoleKey);

      if (universalGoogle && event.event == AuthChangeEvent.signedIn) {
        _portalHandoffInProgress = true;
        try {
          await prefs.remove(_universalGoogleOAuthKey);
          await completeUniversalAuth();
        } catch (e) {
          ref.read(authPortalErrorProvider.notifier).state = _describeAuthFailure(e);
        } finally {
          _portalHandoffInProgress = false;
        }
        return;
      }

      if (googlePending &&
          pendingRole != null &&
          event.event == AuthChangeEvent.signedIn) {
        _portalHandoffInProgress = true;
        try {
          final role = UserRole.values.byName(pendingRole);
          final isSignUp = prefs.getBool(_pendingIsSignUpKey) ?? false;
          await _completePendingGoogleAuth(role: role, isSignUp: isSignUp);
        } catch (e) {
          await clearPendingGoogleSignIn();
          if (e is IdentityApiException && e.isRoleMismatch) {
            await _rejectPortalAuth();
          } else if (Supabase.instance.client.auth.currentSession != null) {
            await refreshSessionFromApi();
          }
          ref.read(authPortalErrorProvider.notifier).state = _describeAuthFailure(e);
        } finally {
          _portalHandoffInProgress = false;
        }
        return;
      }

      if (event.event == AuthChangeEvent.initialSession ||
          event.event == AuthChangeEvent.tokenRefreshed) {
        final incoming = _sessionFromSupabase(session);
        if (!shouldReplaceAuthSessionForSupabaseEvent(
          isTokenRefresh: event.event == AuthChangeEvent.tokenRefreshed,
          isInitialSession: event.event == AuthChangeEvent.initialSession,
          currentUserId: state?.userId,
          incomingUserId: incoming.userId,
        )) {
          if (kDebugMode && event.event == AuthChangeEvent.tokenRefreshed) {
            debugPrint('Auth: tokenRefreshed isolated from UI (userId=${state?.userId})');
          }
          return;
        }
        state = incoming;
        return;
      }
    });
    ref.onDispose(() => _authSub?.cancel());

    final existing = Supabase.instance.client.auth.currentSession;
    return existing != null ? _sessionFromSupabase(existing) : null;
  }

  /// Owanbe 2.0 — universal Google OAuth (no portal context).
  Future<void> prepareUniversalGoogleSignIn() async {
    ref.read(authPortalErrorProvider.notifier).state = null;
    await clearPendingGoogleSignIn();
    final prefs = _prefs;
    await prefs.setBool(_universalGoogleOAuthKey, true);
  }

  /// Owanbe 2.0 — publish Supabase session after auth; API sync runs in [userIdentityProvider].
  Future<void> completeUniversalAuth({String? displayNameHint}) async {
    final manageHandoff = !_portalHandoffInProgress;
    if (manageHandoff) _portalHandoffInProgress = true;
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) return;
      state = _sessionFromSupabase(session);
    } finally {
      if (manageHandoff) _portalHandoffInProgress = false;
    }
  }

  /// Customer Flutter email sign-in — rejects Administration Portal accounts.
  Future<void> signInUniversalWithEmail({
    required String email,
    required String password,
  }) async {
    ref.read(authPortalErrorProvider.notifier).state = null;
    await clearPendingGoogleSignIn();
    _portalHandoffInProgress = true;
    final normalizedEmail = _normalizeEmail(email);
    final normalizedPassword = _normalizePassword(password);
    if (kDebugMode) {
      final url = SupabaseConfig.current?.url ?? 'missing';
      debugPrint(
        'Customer sign-in: url=$url email="$normalizedEmail" (${normalizedEmail.length} chars) '
        'passwordLen=${normalizedPassword.length}',
      );
    }
    try {
      // Do not local-signOut before password sign-in — that races profile sync
      // (ensure-user) with a dead JWT. signInWithPassword replaces the session.
      ref.read(identitySyncCoordinatorProvider).invalidate();
      try {
        await Supabase.instance.client.auth.signInWithPassword(
          email: normalizedEmail,
          password: normalizedPassword,
        );
      } catch (e) {
        // GoTrue browser fetch can fail on Flutter Web even when REST works
        // (or when the first attempt races). Retry via direct Auth REST.
        if (kDebugMode &&
            ((e is AuthException && _isInvalidCredentials(e)) ||
                _isRetryableAuthTransport(e))) {
          if (kDebugMode) {
            debugPrint('GoTrue sign-in failed ($e); retrying via direct REST.');
          }
          await _signInWithPasswordViaRest(
            email: normalizedEmail,
            password: normalizedPassword,
          );
        } else {
          rethrow;
        }
      }
      await completeUniversalAuth();
      await _assertCustomerEntrypointAllowed();
    } finally {
      _portalHandoffInProgress = false;
    }
  }

  /// Admin Flutter email sign-in — rejects customer-only accounts.
  Future<void> signInAdminWithEmail({
    required String email,
    required String password,
  }) async {
    ref.read(authPortalErrorProvider.notifier).state = null;
    await clearPendingGoogleSignIn();
    _portalHandoffInProgress = true;
    final normalizedEmail = _normalizeEmail(email);
    final normalizedPassword = _normalizePassword(password);
    try {
      ref.read(identitySyncCoordinatorProvider).invalidate();
      await Supabase.instance.client.auth.signInWithPassword(
        email: normalizedEmail,
        password: normalizedPassword,
      );
      await completeUniversalAuth();
      await _assertAdminEntrypointAllowed();
    } on AuthException catch (e) {
      if (kDebugMode && _isInvalidCredentials(e)) {
        await _signInWithPasswordViaRest(
          email: normalizedEmail,
          password: normalizedPassword,
        );
        await completeUniversalAuth();
        await _assertAdminEntrypointAllowed();
        return;
      }
      rethrow;
    } finally {
      _portalHandoffInProgress = false;
    }
  }

  Future<void> _assertCustomerEntrypointAllowed() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;
    final roles = _jwtRoles(session);
    if (AppEntrypoint.hasAdministrationRole(roles)) {
      await signOut();
      throw StateError(AppEntrypoint.customerAccountIsAdminMessage);
    }
  }

  Future<void> _assertAdminEntrypointAllowed() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      throw StateError(AppEntrypoint.adminAccountNotAuthorizedMessage);
    }
    final roles = _jwtRoles(session);
    if (!AppEntrypoint.hasAdministrationRole(roles)) {
      await signOut();
      throw StateError(AppEntrypoint.adminAccountNotAuthorizedMessage);
    }
  }

  static String _normalizeEmail(String email) =>
      email.trim().toLowerCase().replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '');

  static String _normalizePassword(String password) =>
      password.trim().replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '');

  static   bool _isInvalidCredentials(AuthException e) {
    final msg = e.message.toLowerCase();
    final code = (e.code ?? '').toLowerCase();
    return code == 'invalid_credentials' ||
        msg.contains('invalid login credentials') ||
        msg.contains('invalid_credentials');
  }

  /// Browser / transport failures that may succeed via direct Auth REST.
  bool _isRetryableAuthTransport(Object error) {
    final raw = error.toString().toLowerCase();
    return raw.contains('failed to fetch') ||
        raw.contains('clientexception') ||
        raw.contains('authretryablefetchexception') ||
        raw.contains('socketexception') ||
        raw.contains('timeout') ||
        raw.contains('timed out') ||
        raw.contains('network');
  }

  Future<void> _signInWithPasswordViaRest({
    required String email,
    required String password,
  }) async {
    final config = SupabaseConfig.current;
    if (config == null) {
      throw const SupabaseConfigException(
        SupabaseDiagnostic(
          kind: SupabaseFailureKind.configMissing,
          title: 'Supabase configuration is invalid.',
          message: 'SUPABASE_URL / SUPABASE_ANON_KEY missing for REST sign-in.',
        ),
      );
    }
    final url = config.url;
    final anon = config.anonKey;
    final uri = Uri.parse('$url/auth/v1/token').replace(
      queryParameters: const {'grant_type': 'password'},
    );
    final response = await http.post(
      uri,
      headers: {
        'apikey': anon,
        'Authorization': 'Bearer $anon',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (kDebugMode) {
        debugPrint('REST sign-in failed: HTTP ${response.statusCode} ${response.body}');
      }
      throw AuthException(
        response.body,
        statusCode: response.statusCode.toString(),
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final accessToken = data['access_token']?.toString();
    final refreshToken = data['refresh_token']?.toString();
    if (accessToken == null ||
        refreshToken == null ||
        accessToken.isEmpty ||
        refreshToken.isEmpty) {
      throw const AuthException('REST sign-in returned an empty session');
    }
    await Supabase.instance.client.auth.setSession(
      refreshToken,
      accessToken: accessToken,
    );
  }

  /// Universal email sign-up — blocks auth listener races during handoff.
  Future<void> signUpUniversalWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    ref.read(authPortalErrorProvider.notifier).state = null;
    await clearPendingGoogleSignIn();
    _portalHandoffInProgress = true;
    try {
      final res = await Supabase.instance.client.auth.signUp(
        email: email.trim(),
        password: password.trim(),
        data: {'display_name': displayName.trim()},
      );
      if (res.session == null) {
        throw StateError('Account created — check your email to verify, then sign in.');
      }
      await completeUniversalAuth(displayNameHint: displayName.trim());
      await _assertCustomerEntrypointAllowed();
    } finally {
      _portalHandoffInProgress = false;
    }
  }

  Future<void> prepareGoogleSignIn(UserRole portalRole, {required bool isSignUp}) async {
    ref.read(authPortalErrorProvider.notifier).state = null;
    final prefs = _prefs;
    await prefs.setString(_pendingPortalRoleKey, portalRole.name);
    await prefs.setBool(_pendingIsSignUpKey, isSignUp);
    await prefs.setBool(_pendingGoogleOAuthKey, true);
  }

  /// Clears abandoned or completed Google OAuth handoff state.
  Future<void> clearPendingGoogleSignIn() async {
    final prefs = _prefs;
    await prefs.remove(_pendingPortalRoleKey);
    await prefs.remove(_pendingIsSignUpKey);
    await prefs.remove(_pendingGoogleOAuthKey);
    await prefs.remove(_universalGoogleOAuthKey);
  }

  Future<void> _completePendingGoogleAuth({
    required UserRole role,
    required bool isSignUp,
  }) async {
    try {
      await _finalizePortalAuthWithFallback(portal: role, isSignUp: isSignUp);

      final outcome = await platform.IdentityPlatform.instance.completeOAuthSignIn(
        expectedRole: role,
        portalVerifiedByApi: true,
      );
      if (outcome == platform.AuthOutcome.unauthorized) {
        await _rejectPortalAuth();
        throw StateError('Unauthorized role context');
      }

      final prefs = _prefs;
      await prefs.remove(_pendingPortalRoleKey);
      await prefs.remove(_pendingIsSignUpKey);
      await prefs.remove(_pendingGoogleOAuthKey);
    } on IdentityApiException catch (e) {
      if (e.isRoleMismatch) {
        await _rejectPortalAuth();
      }
      rethrow;
    }
  }

  /// Hard reset after wrong-portal auth — clears Supabase + app session so the user is truly signed out.
  Future<void> _rejectPortalAuth() async {
    await clearPendingGoogleSignIn();
    state = null;
    ref.read(authPortalErrorProvider.notifier).state = null;
    await signOut();
  }

  /// Server-side workspace ensure for an existing Supabase session.
  Future<void> assertPortalAccess(UserRole portal, {required bool isSignUp}) async {
    await completeUniversalAuth();
  }

  /// RC Phase 5: portal lock retired — universal identity only.
  Future<void> _finalizePortalAuthWithFallback({
    required UserRole portal,
    required bool isSignUp,
  }) async {
    await completeUniversalAuth();
    if (portal == UserRole.client) {
      final email = Supabase.instance.client.auth.currentUser?.email;
      if (email != null && email.isNotEmpty) {
        try {
          await IdentityApi().linkEntitlements(email: email);
        } catch (_) {}
      }
    }
  }

  Future<void> completeGoogleSignIn(UserRole expectedRole, {required bool isSignUp}) async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      throw StateError('Google sign-in did not establish a session.');
    }

    await finalizePortalAuth(portal: expectedRole, isSignUp: isSignUp);

    final outcome = await platform.IdentityPlatform.instance.completeOAuthSignIn(
      expectedRole: expectedRole,
      portalVerifiedByApi: true,
    );

    if (outcome == platform.AuthOutcome.unauthorized) {
      await signOut();
      throw StateError('Unauthorized role context');
    }

    final prefs = _prefs;
    await prefs.remove(_pendingPortalRoleKey);
    await prefs.remove(_pendingIsSignUpKey);
    await prefs.remove(_pendingGoogleOAuthKey);
  }

  /// Server-side portal lock: complete-signup (new) or validate-portal (returning).
  Future<void> finalizePortalAuth({
    required UserRole portal,
    required bool isSignUp,
  }) async {
    await _finalizePortalAuthWithFallback(portal: portal, isSignUp: isSignUp);
  }

  /// Enrich [authSessionProvider] from a completed identity sync (GET /auth/me).
  void applyIdentityFromApi(AuthMeResult me) {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;
    final activeWs = ExperienceWorkspace.fromApiCode(me.lastActiveWorkspace);
    final role = resolveUniversalSessionRole(
      apiRoles: me.roles,
      signupPortal: me.signupPortal,
      activeWorkspace: activeWs,
    );
    final sessionUser = session.user;
    final metaName = sessionUser.userMetadata?['display_name']?.toString();
    state = AuthSession(
      userId: me.userId,
      displayName: me.displayName?.trim().isNotEmpty == true
          ? me.displayName!
          : (metaName?.trim().isNotEmpty == true
              ? metaName!
              : me.email.split('@').first),
      role: role,
      email: me.email.isNotEmpty ? me.email : sessionUser.email,
      onboardingComplete: me.onboardingComplete,
      signupPortal: me.signupPortal,
      roles: me.roles,
    );
  }

  Future<void> refreshSessionFromApi({bool requireApiProfile = false}) async {
    await refreshSessionIdentity(ref, requireApiProfile: requireApiProfile);
  }

  /// JWT-only session when the Owambe API is unreachable.
  void restoreSupabaseSession() {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      state = null;
      return;
    }
    state = _sessionFromSupabase(session);
  }

  /// Dev fallback when the Owambe API is unreachable (USB/Wi‑Fi not configured).
  Future<void> markOnboardingCompleteLocally({required String displayName}) async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;
    final current = state;
    state = AuthSession(
      userId: current?.userId ?? session.user.id,
      displayName: displayName,
      role: current != null ? PortalRoutes.canonicalRole(current) : UserRole.client,
      email: current?.email ?? session.user.email,
      onboardingComplete: true,
      signupPortal: current?.signupPortal,
    );
  }


  Future<void> signInWithEmail({
    required String email,
    required String password,
    UserRole? expectedRole,
    bool isSignUp = false,
  }) async {
    await clearPendingGoogleSignIn();
    _portalHandoffInProgress = true;
    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      if (res.session == null) {
        throw StateError('Session not established');
      }

      await completeUniversalAuth();
      if (SharedBootstrap.isAdmin) {
        await _assertAdminEntrypointAllowed();
      } else if (expectedRole == null ||
          expectedRole == UserRole.client ||
          expectedRole == UserRole.organizer ||
          expectedRole == UserRole.vendor) {
        await _assertCustomerEntrypointAllowed();
      }
    } finally {
      _portalHandoffInProgress = false;
    }
  }

  Future<void> refreshSession() async {
    await platform.IdentityPlatform.instance.initialize();
    await refreshSessionFromApi();
  }

  Future<void> signOut() async {
    if (_signOutInProgress) return;
    _signOutInProgress = true;
    _portalHandoffInProgress = false;
    try {
      await clearPendingGoogleSignIn();
      final prefs = _prefs;
      await prefs.remove('owanbe_active_role');
      await prefs.remove('owanbe_active_workspace');
      ref.read(authPortalErrorProvider.notifier).state = null;
      ref.read(identitySyncCoordinatorProvider).invalidate();
      // Clear session first — never invalidate userIdentity or touch
      // activeWorkspace here (CircularDependencyError: both depend on authSession).
      state = null;
      await platform.IdentityPlatform.instance.signOut();
      if (Supabase.instance.client.auth.currentSession != null) {
        await Supabase.instance.client.auth.signOut(scope: SignOutScope.global);
      }
      state = null;
      ref.read(identitySyncCoordinatorProvider).invalidate();
    } finally {
      _signOutInProgress = false;
    }
  }

  Future<void> resetPassword(String email) async {
    final redirectTo = Uri.base.origin;
    await Supabase.instance.client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: redirectTo.isEmpty ? null : redirectTo,
    );
  }

  Future<void> signUpStaff({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
    String? phone,
  }) async {
    final res = await Supabase.instance.client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'display_name': displayName.trim(),
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      },
      emailRedirectTo: Uri.base.origin.isEmpty ? null : Uri.base.origin,
    );
    if (res.session == null) {
      throw StateError(
        'Account created — check your email to verify, then sign in.',
      );
    }
    await signInWithEmail(email: email, password: password, expectedRole: role, isSignUp: true);
  }

  Future<void> signInAttendee({
    required String displayName,
    String? email,
    required String password,
  }) async {
    if (email == null || email.trim().isEmpty) {
      throw ArgumentError('Email required for Supabase sign-in');
    }
    await signInWithEmail(
      email: email,
      password: password,
      expectedRole: UserRole.client,
    );
  }

  Future<void> signUpAttendee({
    required String displayName,
    required String email,
    required String password,
  }) async {
    final res = await Supabase.instance.client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'display_name': displayName.trim()},
    );
    final session = res.session;
    if (session == null) {
      throw StateError(
        'Account created — check your email to confirm, then sign in.',
      );
    }
    await signInWithEmail(
      email: email,
      password: password,
      expectedRole: UserRole.client,
      isSignUp: true,
    );
  }

  List<String> _jwtRoles(Session session) {
    for (final source in [
      session.user.appMetadata['roles'],
      session.user.userMetadata?['roles'],
    ]) {
      if (source is List) {
        return source.map((e) => e.toString()).toList();
      }
    }
    return const [];
  }

  AuthSession _sessionFromSupabase(Session session) {
    final jwtRoles = _jwtRoles(session);
    final signupPortal = session.user.appMetadata['signup_portal']?.toString();
    final role = resolvePortalRole(signupPortal: signupPortal, apiRoles: jwtRoles);
    return AuthSession(
      userId: session.user.id,
      displayName: session.user.userMetadata?['display_name']?.toString() ??
          session.user.email ??
          session.user.id,
      role: role,
      email: session.user.email,
      onboardingComplete: false,
      signupPortal: signupPortal,
    );
  }

  String _describeAuthFailure(Object error) {
    final apiBase = OwambeApiAuth.resolveApiBase();
    if (error is IdentityApiException) {
      if (error.isRoleMismatch) return error.message;
      return '${error.message} (API: $apiBase)';
    }
    final raw = error.toString().toLowerCase();
    if (raw.contains('socket') ||
        raw.contains('connection') ||
        raw.contains('failed host lookup') ||
        raw.contains('clientexception')) {
      return 'Cannot reach Owambe API at $apiBase. '
          'Use your PC Wi‑Fi IP in mobile/assets/env/owanbe_config, then hot restart.';
    }
    return error.toString();
  }
}

final authSessionProvider =
    NotifierProvider<AuthNotifier, AuthSession?>(AuthNotifier.new);
