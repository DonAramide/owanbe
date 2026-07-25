/// Owanbe 2.0 — Universal Identity is the only production path.
abstract final class OwanbeIdentityConfig {
  /// Universal auth → Owanbe Home → workspace activation (production).
  static const identityV2 = true;

  /// Production users activate workspaces from Hub; dev seed emails are regression-only.
  static const productionUsesDevSeedAccounts = false;
}
