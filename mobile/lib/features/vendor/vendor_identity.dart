/// Canonical vendor identity — unifies marketplace, workspace, and CRM vendor IDs.
class VendorIdentity {
  VendorIdentity._();

  /// Regression-test vendor UUID only — not used in production identity paths.
  static const canonicalDevVendorId = '55555555-5555-4555-8555-555555555555';

  static const Map<String, String> _legacyIdToCanonical = {
    'v12': canonicalDevVendorId,
    'vendor_jollof': canonicalDevVendorId,
  };

  /// Resolves mock/legacy marketplace IDs to a canonical vendor record ID.
  static String resolveMarketplaceVendorId(String rawId) {
    final trimmed = rawId.trim();
    if (trimmed.isEmpty) return trimmed;
    return _legacyIdToCanonical[trimmed] ?? trimmed;
  }

  /// Dev/regression alias map only.
  static bool isLegacyAlias(String rawId) => _legacyIdToCanonical.containsKey(rawId.trim());
}
