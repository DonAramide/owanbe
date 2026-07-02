class UserMfaConfig {
  const UserMfaConfig({
    required this.userId,
    required this.email,
    required this.isMfaEnabled,
    required this.mfaFactor,
    required this.recoveryCodes,
    required this.trustedDevicesCount,
    required this.activeSessionsCount,
    required this.failedLoginAttempts,
    required this.isLocked,
  });

  final String userId;
  final String email;
  final bool isMfaEnabled;
  final String mfaFactor; // 'totp' | 'email' | 'none'
  final List<String> recoveryCodes;
  final int trustedDevicesCount;
  final int activeSessionsCount;
  final int failedLoginAttempts;
  final bool isLocked;

  UserMfaConfig copyWith({
    bool? isMfaEnabled,
    String? mfaFactor,
    List<String>? recoveryCodes,
    int? trustedDevicesCount,
    int? activeSessionsCount,
    int? failedLoginAttempts,
    bool? isLocked,
  }) {
    return UserMfaConfig(
      userId: userId,
      email: email,
      isMfaEnabled: isMfaEnabled ?? this.isMfaEnabled,
      mfaFactor: mfaFactor ?? this.mfaFactor,
      recoveryCodes: recoveryCodes ?? this.recoveryCodes,
      trustedDevicesCount: trustedDevicesCount ?? this.trustedDevicesCount,
      activeSessionsCount: activeSessionsCount ?? this.activeSessionsCount,
      failedLoginAttempts: failedLoginAttempts ?? this.failedLoginAttempts,
      isLocked: isLocked ?? this.isLocked,
    );
  }
}

class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    required this.timestamp,
    required this.userId,
    required this.eventType, // 'LOGIN_SUCCESS' | 'LOGIN_FAILURE' | 'MFA_ENABLED' | 'MFA_DISABLED' | 'LOCKOUT' | 'TRUSTED_DEVICE_ADDED'
    required this.ipAddress,
    required this.details,
  });

  final String id;
  final String timestamp;
  final String userId;
  final String eventType;
  final String ipAddress;
  final String details;
}
