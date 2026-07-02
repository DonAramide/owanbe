enum EnterpriseEnvironment { production, sandbox }

class EnterpriseBrandConfig {
  const EnterpriseBrandConfig({
    required this.portalName,
    required this.environment,
    required this.region,
    required this.version,
    required this.buildNumber,
    required this.securityStatus,
    required this.lastSecurityScan,
    required this.complianceStatus,
    required this.runtimePlatform,
  });

  final String portalName;
  final EnterpriseEnvironment environment;
  final String region;
  final String version;
  final String buildNumber;
  final String securityStatus;
  final String lastSecurityScan;
  final String complianceStatus;
  final String runtimePlatform;

  static const defaultAdminConfig = EnterpriseBrandConfig(
    portalName: 'Owanbe Control Tower',
    environment: EnterpriseEnvironment.production,
    region: 'ng-yaba-1',
    version: 'v2.4.0-enterprise',
    buildNumber: 'build-9481-active',
    securityStatus: 'SECURE',
    lastSecurityScan: '2026-07-01 04:00 UTC',
    complianceStatus: 'SOC2 / NDPR COMPLIANT',
    runtimePlatform: 'Flutter Web/Android Runtime',
  );
  
  static const defaultOrganizerConfig = EnterpriseBrandConfig(
    portalName: 'Owanbe Organizer Portal',
    environment: EnterpriseEnvironment.production,
    region: 'ng-yaba-1',
    version: 'v2.4.0-organizer',
    buildNumber: 'build-9475-active',
    securityStatus: 'SECURE',
    lastSecurityScan: '2026-07-01 04:00 UTC',
    complianceStatus: 'NDPR COMPLIANT',
    runtimePlatform: 'Flutter Client Runtime',
  );

  static const defaultVendorConfig = EnterpriseBrandConfig(
    portalName: 'Owanbe Vendor Portal',
    environment: EnterpriseEnvironment.production,
    region: 'ng-yaba-1',
    version: 'v2.4.0-vendor',
    buildNumber: 'build-9478-active',
    securityStatus: 'SECURE',
    lastSecurityScan: '2026-07-01 04:00 UTC',
    complianceStatus: 'NDPR COMPLIANT',
    runtimePlatform: 'Flutter Client Runtime',
  );
}
