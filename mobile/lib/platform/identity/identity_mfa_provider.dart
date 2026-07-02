import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'identity_mfa_models.dart';

class IdentityMfaState {
  const IdentityMfaState({
    required this.configs,
    required this.logs,
  });

  final Map<String, UserMfaConfig> configs;
  final List<AuditLogEntry> logs;

  IdentityMfaState copyWith({
    Map<String, UserMfaConfig>? configs,
    List<AuditLogEntry>? logs,
  }) {
    return IdentityMfaState(
      configs: configs ?? this.configs,
      logs: logs ?? this.logs,
    );
  }
}

class IdentityMfaNotifier extends StateNotifier<IdentityMfaState> {
  IdentityMfaNotifier() : super(const IdentityMfaState(configs: {}, logs: [])) {
    // Initialize default users configuration
    final initialConfigs = {
      'usr_1': const UserMfaConfig(
        userId: 'usr_1',
        email: 'admin@owanbe.dev',
        isMfaEnabled: false,
        mfaFactor: 'none',
        recoveryCodes: ['REC-A81F-94BD', 'REC-7429-0BFA', 'REC-CE81-42D0', 'REC-998F-21C0'],
        trustedDevicesCount: 2,
        activeSessionsCount: 3,
        failedLoginAttempts: 0,
        isLocked: false,
      ),
      'usr_2': const UserMfaConfig(
        userId: 'usr_2',
        email: 'organizer@owanbe.dev',
        isMfaEnabled: false,
        mfaFactor: 'none',
        recoveryCodes: [],
        trustedDevicesCount: 1,
        activeSessionsCount: 1,
        failedLoginAttempts: 1,
        isLocked: false,
      ),
      'usr_3': const UserMfaConfig(
        userId: 'usr_3',
        email: 'vendor@owanbe.dev',
        isMfaEnabled: true,
        mfaFactor: 'email',
        recoveryCodes: ['REC-1111-2222', 'REC-3333-4444'],
        trustedDevicesCount: 0,
        activeSessionsCount: 1,
        failedLoginAttempts: 0,
        isLocked: false,
      ),
      'usr_4': const UserMfaConfig(
        userId: 'usr_4',
        email: 'attacker@badsite.com',
        isMfaEnabled: false,
        mfaFactor: 'none',
        recoveryCodes: [],
        trustedDevicesCount: 0,
        activeSessionsCount: 0,
        failedLoginAttempts: 6,
        isLocked: true,
      ),
    };

    final initialLogs = [
      const AuditLogEntry(
        id: 'log_1',
        timestamp: '2026-07-01 10:22:15',
        userId: 'usr_1',
        eventType: 'MFA_VERIFIED',
        ipAddress: '197.210.64.2',
        details: 'Admin session authorized with TOTP verification token.',
      ),
      const AuditLogEntry(
        id: 'log_2',
        timestamp: '2026-07-01 11:04:12',
        userId: 'usr_4',
        eventType: 'LOCKOUT_TRIGGERED',
        ipAddress: '88.241.12.89',
        details: 'Account locked due to 5 consecutive failed login attempts.',
      ),
      const AuditLogEntry(
        id: 'log_3',
        timestamp: '2026-07-01 12:40:02',
        userId: 'usr_2',
        eventType: 'LOGIN_SUCCESS',
        ipAddress: '197.210.12.44',
        details: 'Organizer logged in successfully.',
      ),
    ];

    state = IdentityMfaState(configs: initialConfigs, logs: initialLogs);
  }

  void enrollMfa(String userId, String factor) {
    final cfg = state.configs[userId];
    if (cfg == null) return;
    
    final newCfg = cfg.copyWith(
      isMfaEnabled: true,
      mfaFactor: factor,
      recoveryCodes: ['REC-8892-F1A0', 'REC-7429-0BFA', 'REC-CE81-42D0', 'REC-998F-21C0', 'REC-4411-B2C1', 'REC-8822-CC00'],
    );
    
    _updateConfigAndAddLog(
      userId, 
      newCfg,
      'MFA_ENABLED',
      'Multi-factor authentication initialized using $factor.'
    );
  }

  void disableMfa(String userId) {
    final cfg = state.configs[userId];
    if (cfg == null) return;

    final newCfg = cfg.copyWith(
      isMfaEnabled: false,
      mfaFactor: 'none',
      recoveryCodes: [],
    );

    _updateConfigAndAddLog(
      userId,
      newCfg,
      'MFA_DISABLED',
      'Multi-factor authentication deactivated.'
    );
  }

  void regenerateRecoveryCodes(String userId) {
    final cfg = state.configs[userId];
    if (cfg == null) return;

    final codes = List.generate(6, (index) => 'REC-${DateTime.now().millisecond + index}-${1000 + index}');
    final newCfg = cfg.copyWith(recoveryCodes: codes);

    _updateConfigAndAddLog(
      userId,
      newCfg,
      'RECOVERY_CODES_REGENERATED',
      'Backup authentication recovery codes regenerated.'
    );
  }

  void setAccountLock(String userId, bool isLocked) {
    final cfg = state.configs[userId];
    if (cfg == null) return;

    final newCfg = cfg.copyWith(
      isLocked: isLocked,
      failedLoginAttempts: isLocked ? cfg.failedLoginAttempts : 0,
    );

    _updateConfigAndAddLog(
      userId,
      newCfg,
      isLocked ? 'LOCKOUT_TRIGGERED' : 'ACCOUNT_UNLOCKED',
      isLocked ? 'Administrative account manually locked.' : 'Administrative account unlocked.'
    );
  }

  void registerTrustedDevice(String userId) {
    final cfg = state.configs[userId];
    if (cfg == null) return;

    final newCfg = cfg.copyWith(trustedDevicesCount: cfg.trustedDevicesCount + 1);

    _updateConfigAndAddLog(
      userId,
      newCfg,
      'TRUSTED_DEVICE_ADDED',
      'Current client workstation registered as trusted workstation.'
    );
  }

  void terminateSession(String userId) {
    final cfg = state.configs[userId];
    if (cfg == null) return;

    final newCfg = cfg.copyWith(
      activeSessionsCount: cfg.activeSessionsCount > 0 ? cfg.activeSessionsCount - 1 : 0
    );

    _updateConfigAndAddLog(
      userId,
      newCfg,
      'SESSION_TERMINATED',
      'Terminated active user session remote reference.'
    );
  }

  void logFailedLogin(String userId, String ipAddress) {
    final cfg = state.configs[userId];
    if (cfg == null) return;

    final newAttempts = cfg.failedLoginAttempts + 1;
    final lockTriggered = newAttempts >= 5;

    final newCfg = cfg.copyWith(
      failedLoginAttempts: newAttempts,
      isLocked: lockTriggered || cfg.isLocked,
    );

    final updatedConfigs = Map<String, UserMfaConfig>.from(state.configs)..['userId'] = newCfg;
    final newLog = AuditLogEntry(
      id: 'log_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now().toString().substring(0, 19),
      userId: userId,
      eventType: lockTriggered ? 'LOCKOUT_TRIGGERED' : 'LOGIN_FAILURE',
      ipAddress: ipAddress,
      details: lockTriggered 
          ? 'Account locked out after exceeding failure limit.'
          : 'Failed authentication attempts count: $newAttempts.',
    );

    state = state.copyWith(configs: updatedConfigs, logs: [newLog, ...state.logs]);
  }

  void _updateConfigAndAddLog(String userId, UserMfaConfig newCfg, String eventType, String details) {
    final updatedConfigs = Map<String, UserMfaConfig>.from(state.configs)..[userId] = newCfg;
    final newLog = AuditLogEntry(
      id: 'log_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now().toString().substring(0, 19),
      userId: userId,
      eventType: eventType,
      ipAddress: '197.210.64.2',
      details: details,
    );

    state = state.copyWith(configs: updatedConfigs, logs: [newLog, ...state.logs]);
  }
}

final identityMfaProvider = StateNotifierProvider<IdentityMfaNotifier, IdentityMfaState>((ref) {
  return IdentityMfaNotifier();
});
