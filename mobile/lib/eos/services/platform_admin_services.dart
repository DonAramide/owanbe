import '../../core/api/identity_security_api.dart';

/// Phase 29 — Nest-backed admin user lifecycle helpers.
class AdminUserService {
  static final _api = IdentitySecurityApi();

  static Future<void> suspendUser(String userId, {String? reason}) async {
    await _api.suspendUser(userId, reason: reason ?? 'Admin suspension');
  }

  static Future<void> reactivateUser(String userId) async {
    await _api.reactivateUser(userId);
  }

  static Future<void> lockAccount(String userId) async {
    await suspendUser(userId, reason: 'Account lock');
  }

  static Future<void> unlockAccount(String userId) async {
    await reactivateUser(userId);
  }

  static Future<void> resetPassword(String userId) async {
    throw UnsupportedError(
      'Password reset uses Supabase Auth recovery flows — no parallel identity reset engine.',
    );
  }

  static Future<void> resetMfa(String userId) async {
    await _api.resetMfa(userId, reason: 'Admin MFA recovery');
  }

  static Future<void> forceLogout(String userId) async {
    final r = await _api.revokeSessions(userId);
    if (r['available'] != true) {
      throw StateError(r['reason']?.toString() ?? 'Session revoke Unavailable');
    }
  }

  static Future<void> changeRoles(String userId, String role) async {
    throw UnsupportedError('Role changes use existing RBAC APIs — not redesigned in Phase 29.');
  }
}

class AdminVendorService {
  static Future<void> approveVendor(String vendorId) async {}
  static Future<void> rejectVendor(String vendorId) async {}
  static Future<void> suspendVendor(String vendorId) async {}
  static Future<void> reactivateVendor(String vendorId) async {}
}

class AdminOrganizerService {
  static Future<void> approveOrganizer(String organizerId) async {}
  static Future<void> rejectOrganizer(String organizerId) async {}
  static Future<void> suspendOrganizer(String organizerId) async {}
  static Future<void> reactivateOrganizer(String organizerId) async {}
}

class AdminBroadcastService {
  static Future<void> sendBroadcast({
    required String channel,
    required String target,
    required String subject,
    required String body,
  }) async {}
}

class AdminMaintenanceService {
  static Future<void> setMaintenanceMode(bool enforced, {DateTime? expiry}) async {}
  static Future<void> setCheckoutStatus(bool enabled) async {}
  static Future<void> setLoginStatus(bool enabled) async {}
}

class AdminLookupService {
  static Future<void> updateLookup(String category, String value) async {}
}

class AdminMarketplaceService {
  static Future<void> updateListingVisibility(String listingId, String status) async {}
}

class AdminAuditService {
  static Future<void> logAdminAction({
    required String action,
    required String target,
    required String prevVal,
    required String newVal,
    required String reason,
  }) async {}
}
