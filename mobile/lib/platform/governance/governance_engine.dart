import 'governance_models.dart';
import 'governance_audit_service.dart';
import 'policy_inheritance_engine.dart';
import 'vendor_governance_engine.dart';

class GovernanceEngine {
  final GovernanceAuditService audit;
  final PolicyInheritanceEngine policyInheritor;
  late final VendorGovernanceEngine vendorGovernance;

  GovernanceEngine()
      : audit = GovernanceAuditService(),
        policyInheritor = PolicyInheritanceEngine() {
    vendorGovernance = VendorGovernanceEngine(auditService: audit);
  }

  // Unified endpoint to resolve any entity policy
  PolicyOriginExplanation resolveRule({
    required String key,
    required Map<String, dynamic> platformRules,
    Map<String, dynamic>? categoryRules,
    Map<String, dynamic>? groupRules,
    Map<String, dynamic>? vendorOverrides,
    Map<String, dynamic>? eventOverrides,
  }) {
    return policyInheritor.resolveEffectiveRule(
      key: key,
      platformRules: platformRules,
      categoryRules: categoryRules,
      groupRules: groupRules,
      vendorOverrides: vendorOverrides,
      eventOverrides: eventOverrides,
    );
  }
}
