import 'package:flutter/material.dart';

import '../../../eos/layout/workspace/entity_engine.dart';
import '../../../eos/layout/workspace/workspace_definition.dart';

class OrganizerScorecard {
  const OrganizerScorecard({
    required this.revenueScore,
    required this.attendanceScore,
    required this.vendorScore,
    required this.operationsScore,
    required this.financeScore,
    required this.growthScore,
    required this.overallScore,
  });

  final int revenueScore;
  final int attendanceScore;
  final int vendorScore;
  final int operationsScore;
  final int financeScore;
  final int growthScore;
  final int overallScore;
}

class OrganizerIntelligenceEngine {
  static OrganizerScorecard get scorecard => const OrganizerScorecard(
        revenueScore: 92,
        attendanceScore: 88,
        vendorScore: 95,
        operationsScore: 94,
        financeScore: 90,
        growthScore: 89,
        overallScore: 91,
      );

  static EntityDefinition resolveOrganizerEntity(String id) {
    return EntityDefinition(
      id: id,
      type: WorkspaceEntityType.organizer,
      name: 'Alpha Event Group',
      logoText: 'A',
      status: 'active',
      healthScore: 91,
      environment: 'Production',
      region: 'NG-LAGOS',
      primaryContact: 'info@alphaevents.dev',
      createdDate: '2026-06-01',
      lastActivity: 'Workspace updated now',
      relations: const [
        EntityRelation(targetId: 'tenant_1', type: WorkspaceEntityType.tenant, label: 'Tenant Owner', icon: Icons.corporate_fare),
        EntityRelation(targetId: 'evt_gala', type: WorkspaceEntityType.event, label: 'Active Portfolio Event', icon: Icons.event),
      ],
      factors: const [
        'Event ratings average: 4.8 / 5.0',
        'Zero open incident reports',
        'SLA payout parameters optimal',
      ],
      insights: const [
        'Weekend revenue opportunity projected to increase 12%.',
        'Attendance forecast shows high VIP guest registrations.',
      ],
    );
  }
}
