import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_session.dart';
import 'user_role.dart';

/// Holds the signed-in user. `null` = logged out.
class AuthNotifier extends Notifier<AuthSession?> {
  static const _activeRoleKey = 'owanbe_active_role';

  StreamSubscription<AuthState>? _authSub;
  UserRole? _preferredRole;

  @override
  AuthSession? build() {
    _authSub?.cancel();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      final session = event.session;
      if (session == null) {
        state = null;
        return;
      }
      state = _sessionFromSupabase(session);
    });
    ref.onDispose(() => _authSub?.cancel());

    _loadPreferredRole();

    final existing = Supabase.instance.client.auth.currentSession;
    return existing != null ? _sessionFromSupabase(existing) : null;
  }

  Future<void> _loadPreferredRole() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_activeRoleKey);
    if (stored == null) return;
    try {
      _preferredRole = UserRole.values.byName(stored);
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        state = _sessionFromSupabase(session);
      }
    } catch (_) {
      await prefs.remove(_activeRoleKey);
    }
  }

  Future<void> _persistPreferredRole(UserRole? role) async {
    final prefs = await SharedPreferences.getInstance();
    if (role == null) {
      await prefs.remove(_activeRoleKey);
    } else {
      await prefs.setString(_activeRoleKey, role.name);
    }
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
    UserRole? expectedRole,
  }) async {
    final res = await Supabase.instance.client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    final session = res.session;
    if (session == null) {
      throw StateError('Sign-in succeeded but no session was returned');
    }
    final jwtRoles = _jwtRoles(session);
    if (expectedRole != null && !_rolesInclude(expectedRole, jwtRoles)) {
      await Supabase.instance.client.auth.signOut();
      throw StateError(
        'This account is missing the ${expectedRole.label} role in Supabase '
        '(app_metadata.roles). Current roles: ${jwtRoles.isEmpty ? "none" : jwtRoles.join(", ")}. '
        'Re-run scripts/supabase/seed-dev-auth-users.sql or add "client" for attendee sign-in.',
      );
    }
    _preferredRole = expectedRole ?? _mapRole(jwtRoles);
    await _persistPreferredRole(_preferredRole);
    state = _sessionFromSupabase(session);
  }

  Future<void> refreshSession() async {
    final res = await Supabase.instance.client.auth.refreshSession();
    final session = res.session;
    state = session != null ? _sessionFromSupabase(session) : null;
  }

  Future<void> signOut() async {
    _preferredRole = null;
    await _persistPreferredRole(null);
    await Supabase.instance.client.auth.signOut();
    state = null;
  }

  Future<void> signInAttendee({
    required String displayName,
    String? email,
    required String password,
  }) async {
    if (email == null || email.trim().isEmpty) {
      throw ArgumentError('Email required for Supabase sign-in');
    }
    // Public sign-in must not reuse a staff role picked on /staff/login.
    _preferredRole = UserRole.client;
    await signInWithEmail(
      email: email,
      password: password,
      expectedRole: UserRole.client,
    );
    state = AuthSession(
      userId: state!.userId,
      displayName: displayName,
      role: UserRole.client,
      email: email,
    );
  }

  Future<void> signUpAttendee({
    required String displayName,
    required String email,
    required String password,
  }) async {
    _preferredRole = UserRole.client;
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
    );
    state = AuthSession(
      userId: state!.userId,
      displayName: displayName,
      role: UserRole.client,
      email: email,
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

  bool _rolesInclude(UserRole role, List<String> jwtRoles) => switch (role) {
        UserRole.client => jwtRoles.contains('client'),
        UserRole.organizer => jwtRoles.contains('organizer'),
        UserRole.vendor =>
          jwtRoles.contains('vendor') || jwtRoles.contains('vendor_pending'),
        UserRole.admin => jwtRoles.any((r) => r.startsWith('admin_')),
        UserRole.superAdmin => jwtRoles.contains('super_admin'),
      };

  AuthSession _sessionFromSupabase(Session session) {
    final jwtRoles = _jwtRoles(session);
    final role = _preferredRole != null && _rolesInclude(_preferredRole!, jwtRoles)
        ? _preferredRole!
        : _mapRole(jwtRoles);
    return AuthSession(
      userId: session.user.id,
      displayName: session.user.userMetadata?['display_name']?.toString() ??
          session.user.email ??
          session.user.id,
      role: role,
      email: session.user.email,
    );
  }

  UserRole _mapRole(List<String> roles) {
    if (roles.contains('super_admin')) return UserRole.superAdmin;
    if (roles.any((r) => r.startsWith('admin_'))) return UserRole.admin;
    if (roles.contains('vendor') || roles.contains('vendor_pending')) {
      return UserRole.vendor;
    }
    if (roles.contains('organizer')) return UserRole.organizer;
    return UserRole.client;
  }
}

final authSessionProvider =
    NotifierProvider<AuthNotifier, AuthSession?>(AuthNotifier.new);
