import 'governance_models.dart';

class GovernancePolicyDefinition {
  final Map<String, PolicyPermission> permissions;

  GovernancePolicyDefinition({required this.permissions});

  factory GovernancePolicyDefinition.defaults() {
    return GovernancePolicyDefinition(
      permissions: {
        'messaging': PolicyPermission.enabled,
        'voiceCalls': PolicyPermission.enabled,
        'videoCalls': PolicyPermission.enabled,
        'fileSharing': PolicyPermission.enabled,
        'voiceNotes': PolicyPermission.enabled,
        'presence': PolicyPermission.enabled,
        'marketplaceVisibility': PolicyPermission.enabled,
        'walletAccess': PolicyPermission.enabled,
        'escrowDisbursement': PolicyPermission.enabled,
        'quoteCreation': PolicyPermission.enabled,
        'contractCreation': PolicyPermission.enabled,
        'withdrawals': PolicyPermission.enabled,
        'reviewsEnabled': PolicyPermission.enabled,
      },
    );
  }

  PolicyPermission getPermission(String key) {
    return permissions[key] ?? PolicyPermission.disabled;
  }
}
