import 'package:flutter/material.dart';

import 'entity_engine.dart';
import 'workspace_definition.dart';

class CommerceForecast {
  const CommerceForecast({
    required this.targetTimeframe,
    required this.projectedRevenue,
    required this.projectedEscrowRelease,
    required this.projectedPayoutRequirements,
  });

  final String targetTimeframe;
  final double projectedRevenue;
  final double projectedEscrowRelease;
  final double projectedPayoutRequirements;
}

class CommerceEngine {
  static double get revenueToday => 4200000.0;
  static double get revenueThisWeek => 28500000.0;
  static double get revenueThisMonth => 124000000.0;
  static double get pendingEscrow => 19500000.0;
  static double get failedPaymentRate => 0.02;
  static double get successRate => 0.98;

  static List<CommerceForecast> get forecasts => const [
        CommerceForecast(targetTimeframe: '24 Hours', projectedRevenue: 4800000, projectedEscrowRelease: 1200000, projectedPayoutRequirements: 950000),
        CommerceForecast(targetTimeframe: '7 Days', projectedRevenue: 32000000, projectedEscrowRelease: 18000000, projectedPayoutRequirements: 14000000),
        CommerceForecast(targetTimeframe: '30 Days', projectedRevenue: 135000000, projectedEscrowRelease: 94000000, projectedPayoutRequirements: 82000000),
      ];

  static EntityDefinition resolveCommerceEntity() {
    return const EntityDefinition(
      id: 'commerce_global',
      type: WorkspaceEntityType.commerce,
      name: 'Owambe Commerce Twin',
      logoText: '₦',
      status: 'active',
      healthScore: 98,
      environment: 'Production',
      region: 'NG-LAGOS',
      primaryContact: 'finance@owanbe.dev',
      createdDate: '2026-06-01',
      lastActivity: 'Ledger balance updated now',
      relations: [
        EntityRelation(targetId: 'ord_1', type: WorkspaceEntityType.order, label: 'Ticket Order', icon: Icons.shopping_bag),
        EntityRelation(targetId: 'pay_1', type: WorkspaceEntityType.payment, label: 'Payment Ledger', icon: Icons.payment),
        EntityRelation(targetId: 'esc_1', type: WorkspaceEntityType.payout, label: 'Escrow Settlement', icon: Icons.account_balance_wallet),
      ],
      factors: [
        'Payment rail success rate at 98%',
        'Refund queue SLA nominal (<2h processing)',
        'Zero ledger discrepancies detected',
      ],
      insights: [
        'Revenue likely to exceed forecast this week.',
        'Escrow release schedules nominal for upcoming weekend.',
      ],
    );
  }
}
