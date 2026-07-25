import 'package:supabase_flutter/supabase_flutter.dart';
import '../bootstrap/bootstrap.dart';
import '../bootstrap/platform_event_bus.dart';
import '../bootstrap/platform_registry.dart';
import 'identity_models.dart';
import 'identity_repository.dart';
import 'identity_session.dart';
import '../../auth/user_role.dart';

class IdentityPlatform extends PlatformModule {
  IdentityPlatform._();
  static final IdentityPlatform instance = IdentityPlatform._();

  @override
  String get name => 'IdentityPlatform';

  final _supabase = Supabase.instance.client;
  final _repository = IdentityRepository();
  final _session = IdentitySession();

  UserContext? _currentUserContext;
  UserContext? get currentUserContext => _currentUserContext;

  @override
  Future<void> initialize() async {
    PlatformRegistry.instance.registerModule(this);

    final current = _supabase.auth.currentSession;
    if (current == null) return;

    final prefs = await _session.loadPreferences();
    final storedRole = prefs['role'] ?? 'client';
    final role = UserRole.values.firstWhere(
      (r) => r.name == storedRole,
      orElse: () => UserRole.client,
    );
    final context = await _repository.fetchUserContext(current, role);
    _currentUserContext = context;
  }

  Future<AuthOutcome> signInWithEmail({
    required String email,
    required String password,
    required UserRole expectedRole,
  }) async {
    final res = await _supabase.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    
    final session = res.session;
    if (session == null) {
      throw StateError('Authentication failed: session was null');
    }

    final context = await _repository.fetchUserContext(session, expectedRole);
    
    final hasAdminRole = context.roles.contains(UserRole.admin) || context.roles.contains(UserRole.superAdmin);
    final hasCustomerRole = context.roles.contains(UserRole.client) ||
        context.roles.contains(UserRole.organizer) ||
        context.roles.contains(UserRole.vendor);

    if (SharedBootstrap.isAdmin) {
      if (!hasAdminRole) {
        await signOut();
        PlatformEventBus.instance.fire('AUTH_DENIED: Non-admin login attempt on Admin app');
        return AuthOutcome.unauthorized;
      }
    } else {
      if (!hasCustomerRole) {
        await signOut();
        PlatformEventBus.instance.fire('AUTH_DENIED: Admin login attempt on Customer app');
        return AuthOutcome.unauthorized;
      }
    }

    UserRole resolvedRole = expectedRole;
    if (!context.roles.contains(resolvedRole)) {
      await signOut();
      PlatformEventBus.instance.fire(
        'AUTH_DENIED: Account not registered for ${expectedRole.name} portal',
      );
      return AuthOutcome.unauthorized;
    }

    _currentUserContext = context.copyWith(activeRole: resolvedRole);
    await _session.persistPreferences(
      email: email,
      preferredRole: resolvedRole,
      tenantId: context.activeTenantId,
    );

    PlatformEventBus.instance.fire('AUTH_SUCCESS: ${userContextJson()}');
    return AuthOutcome.authenticated;
  }

  Future<AuthOutcome> signInWithGoogle({UserRole portalRole = UserRole.client}) async {
    await _session.persistPreferences(
      email: _currentUserContext?.email ?? '',
      preferredRole: portalRole,
      tenantId: _currentUserContext?.activeTenantId,
    );

    final success = await _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'io.supabase.owambe://login-callback',
      authScreenLaunchMode: LaunchMode.externalApplication,
      queryParams: const {
        'prompt': 'select_account',
        'access_type': 'online',
      },
    );

    if (!success) {
      PlatformEventBus.instance.fire('AUTH_FAILED: Google Sign-in Trigger Failed');
      return AuthOutcome.sessionExpired;
    }

    return AuthOutcome.authenticated;
  }

  Future<AuthOutcome> completeOAuthSignIn({
    required UserRole expectedRole,
    bool portalVerifiedByApi = false,
  }) async {
    final session = _supabase.auth.currentSession;
    if (session == null) {
      return AuthOutcome.sessionExpired;
    }

    final context = await _repository.fetchUserContext(session, expectedRole);

    if (!portalVerifiedByApi) {
      final hasAdminRole = context.roles.contains(UserRole.admin) ||
          context.roles.contains(UserRole.superAdmin);
      final hasCustomerRole = context.roles.contains(UserRole.client) ||
          context.roles.contains(UserRole.organizer) ||
          context.roles.contains(UserRole.vendor);

      if (SharedBootstrap.isAdmin) {
        if (!hasAdminRole) {
          await signOut();
          PlatformEventBus.instance.fire('AUTH_DENIED: Non-admin login attempt on Admin app');
          return AuthOutcome.unauthorized;
        }
      } else if (expectedRole == UserRole.admin || expectedRole == UserRole.superAdmin) {
        if (!hasAdminRole) {
          await signOut();
          return AuthOutcome.unauthorized;
        }
      } else if (!hasCustomerRole || !context.roles.contains(expectedRole)) {
        await signOut();
        PlatformEventBus.instance.fire(
          'AUTH_DENIED: Account not registered for ${expectedRole.name} portal',
        );
        return AuthOutcome.unauthorized;
      }
    }

    _currentUserContext = context.copyWith(activeRole: expectedRole);
    await _session.persistPreferences(
      email: context.email,
      preferredRole: expectedRole,
      tenantId: context.activeTenantId,
    );

    PlatformEventBus.instance.fire('AUTH_SUCCESS: ${userContextJson()}');
    return AuthOutcome.authenticated;
  }

  Future<void> signOut() async {
    final email = _currentUserContext?.email;
    _currentUserContext = null;
    await _session.clearSession();
    await _supabase.auth.signOut(scope: SignOutScope.global);
    PlatformEventBus.instance.fire('AUTH_SIGNOUT: Email: $email');
  }

  String userContextJson() {
    if (_currentUserContext == null) return '{}';
    return '{"userId": "${_currentUserContext!.userId}", "role": "${_currentUserContext!.activeRole.name}"}';
  }

  void switchActiveRole(UserRole role) {
    // Strict portal separation (Phase 4): one account, one portal — no role switching.
  }
}
