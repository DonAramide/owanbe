import 'governance_models.dart';

class GovernanceAuditService {
  final List<AuditEntry> _auditTrail = [];

  void logAction({
    required String adminUserId,
    required String action,
    required String targetEntityId,
    required String reason,
    required String oldValue,
    required String newValue,
    String ipAddress = '127.0.0.1',
    String device = 'Platform Admin Dashboard',
    String? correlationId,
  }) {
    final entry = AuditEntry(
      id: 'audit_${DateTime.now().millisecondsSinceEpoch}',
      adminUserId: adminUserId,
      action: action,
      targetEntityId: targetEntityId,
      reason: reason,
      oldValue: oldValue,
      newValue: newValue,
      timestamp: DateTime.now(),
      ipAddress: ipAddress,
      device: device,
      correlationId: correlationId ?? 'corr_${DateTime.now().microsecondsSinceEpoch}',
    );
    _auditTrail.add(entry);
  }

  List<AuditEntry> getAuditTrailForEntity(String entityId) {
    return _auditTrail.where((e) => e.targetEntityId == entityId).toList();
  }

  List<AuditEntry> getAllLogs() {
    return List.unmodifiable(_auditTrail);
  }
}
