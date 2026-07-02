import 'governance_models.dart';

class GovernanceRegistry {
  final Map<String, GovernancePolicy> _policies = {};

  void registerPolicy(GovernancePolicy policy) {
    _policies[policy.id] = policy;
  }

  GovernancePolicy? getPolicy(String policyId) {
    return _policies[policyId];
  }

  List<GovernancePolicy> getPoliciesForLevel(String level) {
    return _policies.values.where((p) => p.level == level).toList();
  }

  List<GovernancePolicy> getPoliciesForTarget(String targetId) {
    return _policies.values.where((p) => p.targetId == targetId).toList();
  }
}
