import 'governance_models.dart';
import 'governance_audit_service.dart';

class VendorGovernanceEngine {
  final GovernanceAuditService auditService;
  final Map<String, VendorLifecycleState> _vendorStates = {};
  final Map<String, List<ComplianceDocument>> _vendorDocuments = {};

  VendorGovernanceEngine({required this.auditService});

  void evaluateRiskScores({
    required String vendorId,
    required int trustScore,
    required int fraudScore,
    required String adminUserId,
  }) {
    if (trustScore < 40 && fraudScore > 75) {
      transitionVendorState(
        vendorId: vendorId,
        adminUserId: adminUserId,
        targetState: VendorLifecycleState.suspended,
        reason: 'Automated Risk engine: Trust Score < 40 and Fraud Score > 75 crossed limits.',
      );
    }
  }

  void transitionVendorState({
    required String vendorId,
    required String adminUserId,
    required VendorLifecycleState targetState,
    required String reason,
  }) {
    final oldState = _vendorStates[vendorId] ?? VendorLifecycleState.pendingRegistration;
    _vendorStates[vendorId] = targetState;

    auditService.logAction(
      adminUserId: adminUserId,
      action: 'VENDOR_LIFECYCLE_TRANSITION',
      targetEntityId: vendorId,
      reason: reason,
      oldValue: oldState.toString(),
      newValue: targetState.toString(),
    );
  }

  VendorLifecycleState getVendorState(String vendorId) {
    return _vendorStates[vendorId] ?? VendorLifecycleState.pendingRegistration;
  }

  void addComplianceDocument({
    required String vendorId,
    required String adminUserId,
    required String documentType,
    required String assetUri,
    required DateTime expiryDate,
  }) {
    final doc = ComplianceDocument(
      id: 'doc_${DateTime.now().millisecondsSinceEpoch}',
      documentType: documentType,
      assetUri: assetUri,
      status: 'pending',
      expiryDate: expiryDate,
      notes: 'Uploaded to compliance folder via DAM integration',
    );

    _vendorDocuments.putIfAbsent(vendorId, () => []).add(doc);

    auditService.logAction(
      adminUserId: adminUserId,
      action: 'COMPLIANCE_DOCUMENT_UPLOADED',
      targetEntityId: vendorId,
      reason: 'Standard compliance onboarding',
      oldValue: 'none',
      newValue: '$documentType ($assetUri)',
    );
  }

  List<ComplianceDocument> getVendorDocuments(String vendorId) {
    return _vendorDocuments[vendorId] ?? [];
  }
}
