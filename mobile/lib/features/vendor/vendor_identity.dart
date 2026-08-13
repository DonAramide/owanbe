/// Canonical Vendor Identity Resolution (Owanbe 2.0).
///
/// Identity chain (ONLY path):
///   User (auth.users / users.id)
///     → Vendor Profile (vendor_profiles.user_id)
///       → Vendor business (vendors.id via vendor_profiles.vendor_id
///          OR vendors.owner_user_id)
///
/// Marketplace listings, CRM requests, inbox, and notifications MUST use
/// [vendors.id] as the Vendor ID. Demo listings must be seeded rows in
/// `vendors` owned by a real auth user — never orphan string IDs (v1, v2, …).
class VendorIdentity {
  VendorIdentity._();

  /// Seed fixture Vendor ID for `vendor@owanbe.dev` only (infra/db + auth seed).
  /// Not a fallback for arbitrary authenticated users.
  static const seedDemoVendorId = '55555555-5555-4555-8555-555555555555';

  /// @Deprecated('Use seedDemoVendorId — kept for test/binary compatibility')
  static const canonicalDevVendorId = seedDemoVendorId;

  /// Legacy marketplace aliases that historically pointed at the seed vendor.
  /// New marketplace cards must emit [vendors.id] UUIDs directly.
  static const Map<String, String> _legacyIdToCanonical = {
    'v12': seedDemoVendorId,
    'vendor_jollof': seedDemoVendorId,
  };

  static final RegExp _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// True when [rawId] is a UUID (canonical Vendor ID form).
  static bool isVendorUuid(String rawId) => _uuid.hasMatch(rawId.trim());

  /// Resolves a marketplace / wire Vendor ID to the canonical [vendors.id].
  ///
  /// - Legacy aliases → seed demo vendor
  /// - UUIDs pass through unchanged
  /// - Non-UUID fake ids (v1, v2, …) are rejected — they are not Vendor Profiles
  static String resolveMarketplaceVendorId(String rawId) {
    final trimmed = rawId.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(rawId, 'rawId', 'Vendor ID is required');
    }
    final legacy = _legacyIdToCanonical[trimmed];
    if (legacy != null) return legacy;
    if (isVendorUuid(trimmed)) return trimmed;
    throw ArgumentError.value(
      rawId,
      'rawId',
      'Marketplace Vendor ID must be a vendors.id UUID (canonical identity)',
    );
  }

  /// Whether [rawId] is a known legacy alias (audit / migration only).
  static bool isLegacyAlias(String rawId) => _legacyIdToCanonical.containsKey(rawId.trim());
}
