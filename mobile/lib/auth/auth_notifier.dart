import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_session.dart';
import 'user_role.dart';

/// Holds the signed-in user. `null` = logged out.
class AuthNotifier extends Notifier<AuthSession?> {
  StreamSubscription<AuthState>? _authSub;

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

    final existing = Supabase.instance.client.auth.currentSession;
    return existing != null ? _sessionFromSupabase(existing) : null;
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
    final mapped = _sessionFromSupabase(session);
    if (expectedRole != null && mapped.role != expectedRole) {
      await Supabase.instance.client.auth.signOut();
      throw StateError('Account role mismatch — expected ${expectedRole.label}');
    }
    state = mapped;
  }

  Future<void> refreshSession() async {
    final res = await Supabase.instance.client.auth.refreshSession();
    final session = res.session;
    state = session != null ? _sessionFromSupabase(session) : null;
  }

  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
    state = null;
  }

  /// Public attendee sign-in (email optional for display only until Supabase account exists).
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
    state = AuthSession(
      userId: state!.userId,
      displayName: displayName,
      role: UserRole.client,
      email: email,
    );
  }

  AuthSession _sessionFromSupabase(Session session) {
    final meta = session.user.appMetadata;
    final rolesRaw = meta['roles'];
    final roles = rolesRaw is List
        ? rolesRaw.map((e) => e.toString()).toList()
        : <String>[];
    final role = _mapRole(roles);
    return AuthSession(
      userId: session.user.id,
      displayName: session.user.userMetadata['display_name']?.toString() ??
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
