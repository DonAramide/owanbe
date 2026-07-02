import 'package:flutter/material.dart';

import '../layout/workspace/entity_engine.dart';
import '../layout/workspace/workspace_definition.dart';
import 'security_models.dart';

class SecurityEngine {
  static SecurityScore get platformSecurityScore => const SecurityScore(
        score: 96,
        status: 'OPTIMAL',
      );

  static List<ThreatModel> get threats => const [
        ThreatModel(
          id: 'thr_1',
          name: 'Credential stuffing attempt',
          severity: 'HIGH',
          confidence: 0.94,
          sourceIp: '192.168.12.44',
          affectedTenant: 'tenant_1',
          affectedUser: 'user_admin',
          detectedAt: '2026-06-29 00:15:00',
          recommendedAction: 'Enforce temporary login backoff on auth engine',
          status: 'BLOCKED',
        ),
        ThreatModel(
          id: 'thr_2',
          name: 'Suspicious session replay detection',
          severity: 'MEDIUM',
          confidence: 0.82,
          sourceIp: '102.89.23.4',
          affectedTenant: 'platform',
          affectedUser: 'user_vendor_92',
          detectedAt: '2026-06-29 01:04:00',
          recommendedAction: 'Trigger force logout on session id',
          status: 'MONITORING',
        ),
      ];

  static List<SecurityIncidentModel> get incidents => const [
        SecurityIncidentModel(
          id: 'inc_sec_109',
          title: 'MFA configuration drift detected',
          status: 'INVESTIGATING',
          severity: 'HIGH',
          slaHours: 4,
          mttrMinutes: 45,
        ),
      ];

  static List<FraudModel> get fraudRisks => const [
        FraudModel(
          id: 'frd_payout_1',
          type: 'Escrow release anomaly detection',
          riskScore: 84,
          amountMinor: 280000000,
          status: 'FLAGGED',
        ),
      ];

  static List<ComplianceModel> get complianceMetrics => const [
        ComplianceModel(standard: 'GDPR', score: 98, status: 'PASSED'),
        ComplianceModel(standard: 'NDPR', score: 100, status: 'PASSED'),
        ComplianceModel(standard: 'PCI-DSS', score: 94, status: 'PASSED'),
      ];

  static List<RiskModel> get riskAssessments => const [
        RiskModel(category: 'API Authorization', score: 12, status: 'LOW'),
        RiskModel(category: 'Secrets Storage', score: 4, status: 'LOW'),
      ];

  static List<IdentityModel> get users => const [
        IdentityModel(userId: 'usr_1', displayName: 'Super CFO', mfaEnabled: true, status: 'ACTIVE'),
      ];

  static List<SessionModel> get sessions => const [
        SessionModel(sessionId: 'sess_99', userId: 'usr_1', ipAddress: '197.210.64.2', device: 'macOS Chrome', status: 'ACTIVE'),
      ];

  static List<SecurityInsight> get insights => const [
        SecurityInsight(
          id: 'ins_sec_api',
          severity: 'CRITICAL',
          confidence: 0.98,
          reason: 'Rate limiting threshold reached on booking-api endpoints.',
          businessImpact: 'API availability performance latency threshold exceeded.',
          financialRiskMinor: 0,
          recommendation: 'Enable global CDN cache bypass protections.',
        ),
      ];

  static EntityDefinition resolveSecurityEntity() {
    return const EntityDefinition(
      id: 'security_global',
      type: WorkspaceEntityType.security,
      name: 'Owambe Security Operations Center',
      logoText: '🛡️',
      status: 'active',
      healthScore: 96,
      environment: 'Production',
      region: 'NG-LAGOS',
      primaryContact: 'secops@owanbe.dev',
      createdDate: '2026-06-01',
      lastActivity: 'Threat feed updating realtime',
      relations: [
        EntityRelation(targetId: 'tenant_1', type: WorkspaceEntityType.tenant, label: 'Highest Risk Tenant Client', icon: Icons.corporate_fare),
      ],
      factors: [
        'MFA enforcement active for all operators',
        'Database connections securely encrypted',
        'CORS whitelist policies verified',
      ],
      insights: [
        'Credential stuffing checks active and blocking anomalies.',
      ],
    );
  }

  // --- Sprint 8.1 Future Integration Hooks & Extension Points ---
  static final List<String> activeSiemIntegrations = [
    'Cloudflare Web Application Firewall (Monitoring)',
    'AWS GuardDuty (Active - Alerts routed to Incident360)',
    'Microsoft Defender for Cloud (Pending Validation)',
    'Google Chronicle SIEM (Connector configured)',
    'Splunk Cloud (Available - API token pending)',
    'Elastic Security (Monitoring ingestion pipelines)',
    'Datadog Cloud SIEM (Ready)',
    'Azure Sentinel (Not Configured)',
  ];

  static void routeThreatToSiem(String threatId, String providerName) {
    // Hook to forward threat models directly to external SIEM tools
  }

  static void updateFirewallPolicy(String ruleName, Map<String, dynamic> rules) {
    // Hook for WAF / Cloudflare rule updates from Settings tab
  }
}
