import 'governance_models.dart';

class PolicyOriginExplanation {
  final String key;
  final PolicyPermission effectiveValue;
  final String originLevel; // platform, category, group, vendor, eventOverride
  final String originPolicyName;
  final List<String> resolutionPath;

  PolicyOriginExplanation({
    required this.key,
    required this.effectiveValue,
    required this.originLevel,
    required this.originPolicyName,
    required this.resolutionPath,
  });
}

class PolicyInheritanceEngine {
  // Resolves the effective policy based on cascading hierarchy:
  // Platform Policy -> Category Policy -> Group Policy -> Vendor Overrides -> Event Overrides
  PolicyOriginExplanation resolveEffectiveRule({
    required String key,
    required Map<String, dynamic> platformRules,
    Map<String, dynamic>? categoryRules,
    Map<String, dynamic>? groupRules,
    Map<String, dynamic>? vendorOverrides,
    Map<String, dynamic>? eventOverrides,
  }) {
    PolicyPermission currentValue = PolicyPermission.disabled;
    String originLevel = 'platform';
    String originPolicyName = 'Default Platform Policy';
    final List<String> path = [];

    // 1. Platform Policy
    if (platformRules.containsKey(key)) {
      currentValue = _parsePermission(platformRules[key]);
      path.add('Set by Platform Default: $currentValue');
    }

    // 2. Category Policy
    if (categoryRules != null && categoryRules.containsKey(key)) {
      currentValue = _parsePermission(categoryRules[key]);
      originLevel = 'category';
      originPolicyName = 'Category Inherited Policy';
      path.add('Overridden by Category: $currentValue');
    }

    // 3. Group Policy
    if (groupRules != null && groupRules.containsKey(key)) {
      currentValue = _parsePermission(groupRules[key]);
      originLevel = 'group';
      originPolicyName = 'Group Group Policy';
      path.add('Overridden by Vendor Group: $currentValue');
    }

    // 4. Vendor Overrides
    if (vendorOverrides != null && vendorOverrides.containsKey(key)) {
      currentValue = _parsePermission(vendorOverrides[key]);
      originLevel = 'vendor';
      originPolicyName = 'Vendor Specific Override';
      path.add('Overridden by Individual Vendor Settings: $currentValue');
    }

    // 5. Event Overrides
    if (eventOverrides != null && eventOverrides.containsKey(key)) {
      currentValue = _parsePermission(eventOverrides[key]);
      originLevel = 'eventOverride';
      originPolicyName = 'Temporary Event Override';
      path.add('Overridden by Event Override: $currentValue');
    }

    return PolicyOriginExplanation(
      key: key,
      effectiveValue: currentValue,
      originLevel: originLevel,
      originPolicyName: originPolicyName,
      resolutionPath: path,
    );
  }

  PolicyPermission _parsePermission(dynamic val) {
    if (val is PolicyPermission) return val;
    if (val == 'enabled' || val == true) return PolicyPermission.enabled;
    if (val == 'conditional') return PolicyPermission.conditional;
    return PolicyPermission.disabled;
  }
}
