enum PolicyPermission {
  enabled,
  disabled,
  conditional,
}

enum VendorLifecycleState {
  pendingRegistration,
  pendingKyc,
  pendingReview,
  approved,
  active,
  restricted,
  suspended,
  blocked,
  archived,
  deleted,
}

enum RiskLevel {
  low,
  medium,
  high,
}

class GovernancePolicy {
  final String id;
  final String name;
  final String level; // platform, category, group, vendor, eventOverride
  final String targetId; // target identifier at this level
  final Map<String, dynamic> rules;
  final DateTime createdAt;

  GovernancePolicy({
    required this.id,
    required this.name,
    required this.level,
    required this.targetId,
    required this.rules,
    required this.createdAt,
  });
}

class ComplianceDocument {
  final String id;
  final String documentType; // CAC, TIN, NIN, BVN, Insurance, License
  final String assetUri; // DAM integration reference
  final String status; // pending, verified, rejected
  final DateTime expiryDate;
  final String notes;

  ComplianceDocument({
    required this.id,
    required this.documentType,
    required this.assetUri,
    required this.status,
    required this.expiryDate,
    required this.notes,
  });
}

class AuditEntry {
  final String id;
  final String adminUserId;
  final String action;
  final String targetEntityId;
  final String reason;
  final String oldValue;
  final String newValue;
  final DateTime timestamp;
  final String ipAddress;
  final String device;
  final String correlationId;

  AuditEntry({
    required this.id,
    required this.adminUserId,
    required this.action,
    required this.targetEntityId,
    required this.reason,
    required this.oldValue,
    required this.newValue,
    required this.timestamp,
    required this.ipAddress,
    required this.device,
    required this.correlationId,
  });
}
