import 'package:flutter/material.dart';

import 'analytics_models.dart';
import 'entity_engine.dart';
import 'prediction_models.dart';
import 'report_definition.dart';
import 'workspace_definition.dart';

class AnalyticsEngine {
  static List<AnalyticsInsight> get insights => const [
        AnalyticsInsight(
          id: 'ins_rev_growth',
          title: 'Revenue likely to exceed forecast',
          severity: 'INFO',
          confidence: 0.94,
          businessImpact: 'Est. surplus ₦4.2M above standard monthly ledger',
          reason: 'Lagos category booking conversions increased 12% YoY',
          affectedEntities: ['tenant_1', 'org_1'],
          recommendation: 'Optimize ticket tiers settings inside Event 360',
          financialImpactMinor: 420000000,
        ),
        AnalyticsInsight(
          id: 'ins_refund_spike',
          title: 'Refund requests trending upward',
          severity: 'WARNING',
          confidence: 0.88,
          businessImpact: 'Est. payout drag ₦1.8M secondary escrow holdback',
          reason: 'Three core organizers cancelled gala events in Abuja',
          affectedEntities: ['org_2'],
          recommendation: 'Open Commerce 360 refund queue and resolve backlog',
          financialImpactMinor: 180000000,
        ),
      ];

  static List<PredictionModel> get forecasts => const [
        PredictionModel(
          target: 'Weekend Attendance',
          prediction: '18,400 guests expected',
          confidence: 0.92,
          trend: 'UPWARD',
          businessImpact: 'Ticket sales velocity peak',
          recommendedAction: 'Allocate secondary vendor reserves inside operations',
        ),
        PredictionModel(
          target: 'Storage Growth',
          prediction: 'Exhaustion limit in 11 days',
          confidence: 0.85,
          trend: 'CRITICAL',
          businessImpact: 'Media uploads capacity reached',
          recommendedAction: 'Trigger purge on backup database archives',
        ),
      ];

  static List<ReportDefinition> get reports => const [
        ReportDefinition(
          id: 'rep_board',
          title: 'Platform Board Report',
          description: 'C-suite summary including finance, compliance, and growth indices.',
          supportedFormats: [ReportFormat.pdf, ReportFormat.excel],
        ),
        ReportDefinition(
          id: 'rep_investor',
          title: 'Investor Growth Report',
          description: 'LTV calculations, customer retention, and GMV expansion analytics.',
          supportedFormats: [ReportFormat.pdf, ReportFormat.csv],
        ),
      ];

  static EntityDefinition resolveAnalyticsEntity() {
    return const EntityDefinition(
      id: 'analytics_global',
      type: WorkspaceEntityType.analytics,
      name: 'Owambe Analytics Center',
      logoText: '📊',
      status: 'active',
      healthScore: 95,
      environment: 'Production',
      region: 'NG-LAGOS',
      primaryContact: 'bi@owanbe.dev',
      createdDate: '2026-06-01',
      lastActivity: 'Aggregations running now',
      relations: [
        EntityRelation(targetId: 'tenant_1', type: WorkspaceEntityType.tenant, label: 'Top Tenant Client', icon: Icons.corporate_fare),
        EntityRelation(targetId: 'org_1', type: WorkspaceEntityType.organizer, label: 'Fastest Growth Organizer', icon: Icons.portrait),
      ],
      factors: [
        'Conversion rate optimal: 4.8%',
        'Retention index: 42%',
        'Double entry posting validated',
      ],
      insights: [
        'Ticket demand likely to peak next Friday.',
        'Escrow payout pipelines running normal SLA.',
      ],
    );
  }
}
