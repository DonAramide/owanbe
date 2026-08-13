import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/identity_security_api.dart';
import 'identity_mfa_models.dart';

/// Phase 29 — MFA orchestration over Nest + Supabase Auth.
/// Compatibility shims remain for Security 360 / User 360 shells; SoT is Nest/Supabase.
class IdentityMfaState {
  const IdentityMfaState({
    required this.configs,
    required this.logs,
    this.rawStatus,
    this.error,
    this.pendingFactorId,
    this.pendingQrUri,
    this.pendingSecret,
  });

  final Map<String, UserMfaConfig> configs;
  final List<AuditLogEntry> logs;
  final Map<String, dynamic>? rawStatus;
  final String? error;
  final String? pendingFactorId;
  final String? pendingQrUri;
  final String? pendingSecret;

  IdentityMfaState copyWith({
    Map<String, UserMfaConfig>? configs,
    List<AuditLogEntry>? logs,
    Map<String, dynamic>? rawStatus,
    String? error,
    String? pendingFactorId,
    String? pendingQrUri,
    String? pendingSecret,
    bool clearPending = false,
  }) {
    return IdentityMfaState(
      configs: configs ?? this.configs,
      logs: logs ?? this.logs,
      rawStatus: rawStatus ?? this.rawStatus,
      error: error,
      pendingFactorId: clearPending ? null : (pendingFactorId ?? this.pendingFactorId),
      pendingQrUri: clearPending ? null : (pendingQrUri ?? this.pendingQrUri),
      pendingSecret: clearPending ? null : (pendingSecret ?? this.pendingSecret),
    );
  }
}

class IdentityMfaNotifier extends StateNotifier<IdentityMfaState> {
  IdentityMfaNotifier(this._api)
      : super(const IdentityMfaState(configs: {}, logs: [])) {
    refresh();
  }

  final IdentitySecurityApi _api;

  Future<void> refresh() async {
    try {
      final status = await _api.myMfaStatus();
      final enrolled = status['enrolled'] == true;
      final me = UserMfaConfig(
        userId: 'me',
        email: 'current-user',
        isMfaEnabled: enrolled,
        mfaFactor: enrolled ? 'totp' : 'none',
        recoveryCodes: const [],
        trustedDevicesCount: 0,
        activeSessionsCount: (status['verifiedFactorCount'] as num?)?.toInt() ?? 0,
        failedLoginAttempts: 0,
        isLocked: false,
      );
      state = state.copyWith(
        configs: {'me': me},
        rawStatus: status,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Begin Supabase TOTP enrollment — returns factor metadata (no hardcoded secrets).
  Future<Map<String, dynamic>> beginEnrollment() async {
    final enroll = await _api.enrollTotpViaSupabase();
    state = state.copyWith(
      pendingFactorId: enroll['factorId']?.toString(),
      pendingQrUri: enroll['uri']?.toString() ?? enroll['qrCode']?.toString(),
      pendingSecret: enroll['secret']?.toString(),
    );
    return enroll;
  }

  Future<void> completeEnrollment(String code) async {
    final factorId = state.pendingFactorId;
    if (factorId == null) {
      throw StateError('No pending MFA enrollment — call beginEnrollment first');
    }
    await _api.verifyTotpEnrollment(factorId: factorId, code: code);
    state = state.copyWith(clearPending: true);
    await refresh();
  }

  /// Compatibility: maps old enrollMfa(userId, factor) to Supabase enroll + verify requires code.
  Future<void> enrollMfa(String userId, String factor) async {
    if (factor != 'totp') return;
    await beginEnrollment();
  }

  Future<void> disableMfa(String userId) async {
    await _api.recordMfaEvent('disabled');
    if (userId != 'me') {
      await _api.resetMfa(userId, reason: 'Admin disable via workspace');
    }
    await refresh();
  }

  Future<void> terminateSession(String userId) async {
    final id = userId == 'me' ? null : userId;
    if (id == null) return;
    await _api.revokeSessions(id);
  }

  Future<void> setAccountLock(String userId, bool locked) async {
    if (userId == 'me') return;
    if (locked) {
      await _api.suspendUser(userId, reason: 'Security lock from workspace');
    } else {
      await _api.reactivateUser(userId);
    }
  }

  Future<void> regenerateRecoveryCodes(String userId) async {
    await _api.recordMfaEvent('recovery', metadata: {'userId': userId, 'note': 'recovery_requested'});
  }

  Future<void> registerTrustedDevice(String userId) async {
    // Device trust not implemented (Phase 28 Unavailable) — no fake devices.
  }
}

final identityMfaProvider =
    StateNotifierProvider<IdentityMfaNotifier, IdentityMfaState>((ref) {
  return IdentityMfaNotifier(ref.read(identitySecurityApiProvider));
});
