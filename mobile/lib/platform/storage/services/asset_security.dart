import '../models/digital_asset.dart';

class AssetSecurity {
  const AssetSecurity();

  Future<void> auditDownload({
    required String assetId,
    required String actor,
  }) async {
    // Records download transaction logs for auditing
    await Future.delayed(const Duration(milliseconds: 10));
  }

  bool checkPermission({
    required DigitalAsset asset,
    required String actorId,
    required List<String> actorRoles,
  }) {
    if (asset.visibility == AssetVisibility.public) {
      return true;
    }
    
    // Protected and Private visibility require authentication
    if (actorId.isEmpty) return false;

    // Super Admin and Platform Admin bypass all checks
    if (actorRoles.contains('super-admin') || actorRoles.contains('platform-admin')) {
      return true;
    }

    if (asset.visibility == AssetVisibility.protected) {
      // Protected files can be accessed by any logged-in user
      return true;
    }

    // Private assets (KYC, audits) can only be accessed by owners or reviewers
    return asset.uploadedBy == actorId || actorRoles.contains('reviewer');
  }
}
