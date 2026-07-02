import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/vendor_models.dart';
import 'vendor_providers.dart';

class IntelligenceMetric<T> {
  const IntelligenceMetric({
    required this.label,
    required this.value,
    this.growthPercent = 0.0,
    this.attention = 'none',
  });

  final String label;
  final T value;
  final double growthPercent;
  final String attention; // 'none', 'info', 'warning', 'danger'
}

class IntelligenceInsight {
  const IntelligenceInsight({
    required this.message,
    required this.type, // 'info', 'warning', 'success'
    required this.timestamp,
  });

  final String message;
  final String type;
  final DateTime timestamp;
}

class NegotiationItem {
  NegotiationItem({
    required this.id,
    required this.clientName,
    required this.eventName,
    required this.serviceType,
    required this.originalQuoteMinor,
    required this.counterQuoteMinor,
    required this.status, // 'pending_client', 'pending_vendor', 'accepted', 'rejected'
    required this.lastUpdated,
  });

  final String id;
  final String clientName;
  final String eventName;
  final String serviceType;
  final int originalQuoteMinor;
  int counterQuoteMinor;
  String status;
  DateTime lastUpdated;
}

class ContractItem {
  ContractItem({
    required this.id,
    required this.clientName,
    required this.eventName,
    required this.totalValueMinor,
    required this.escrowStatus, // 'pending_fund', 'funded', 'partially_released', 'completed'
    required this.milestoneProgress, // 0.0 to 1.0
    required this.status, // 'active', 'suspended', 'completed'
    required this.deliverablesCount,
    required this.obligations,
  });

  final String id;
  final String clientName;
  final String eventName;
  final int totalValueMinor;
  String escrowStatus;
  double milestoneProgress;
  String status;
  final int deliverablesCount;
  final String obligations;
}

class CrmClient {
  const CrmClient({
    required this.id,
    required this.name,
    required this.segment, // 'VIP', 'Returning', 'High Value', 'At Risk'
    required this.lifetimeSpendMinor,
    required this.eventsBooked,
    required this.latestReview,
  });

  final String id;
  final String name;
  final String segment;
  final int lifetimeSpendMinor;
  final int eventsBooked;
  final String latestReview;
}

class TeamMember {
  TeamMember({
    required this.id,
    required this.name,
    required this.assignment,
    required this.checkInTime,
    required this.performance, // 0.0 to 5.0
    this.certified = true,
  });

  final String id;
  final String name;
  String assignment;
  String checkInTime;
  final double performance;
  final bool certified;
}

class IntelligenceState {
  IntelligenceState({
    required this.healthScore,
    required this.performanceScore,
    required this.satisfactionRate,
    required this.riskScore,
    required this.slaCompliance,
    required this.availableBalanceMinor,
    required this.escrowBalanceMinor,
    required this.releasedFundsMinor,
    required this.monthlyRevenueMinor,
    required this.revenueGrowthPercent,
    required this.negotiations,
    required this.contracts,
    required this.crmClients,
    required this.team,
    required this.insights,
    required this.notifications,
  });

  final int healthScore;
  final double performanceScore;
  final double satisfactionRate;
  final int riskScore;
  final double slaCompliance;
  final int availableBalanceMinor;
  final int escrowBalanceMinor;
  final int releasedFundsMinor;
  final int monthlyRevenueMinor;
  final double revenueGrowthPercent;
  final List<NegotiationItem> negotiations;
  final List<ContractItem> contracts;
  final List<CrmClient> crmClients;
  final List<TeamMember> team;
  final List<IntelligenceInsight> insights;
  final List<String> notifications;

  IntelligenceState copyWith({
    int? healthScore,
    double? performanceScore,
    double? satisfactionRate,
    int? riskScore,
    double? slaCompliance,
    int? availableBalanceMinor,
    int? escrowBalanceMinor,
    int? releasedFundsMinor,
    int? monthlyRevenueMinor,
    double? revenueGrowthPercent,
    List<NegotiationItem>? negotiations,
    List<ContractItem>? contracts,
    List<CrmClient>? crmClients,
    List<TeamMember>? team,
    List<IntelligenceInsight>? insights,
    List<String>? notifications,
  }) {
    return IntelligenceState(
      healthScore: healthScore ?? this.healthScore,
      performanceScore: performanceScore ?? this.performanceScore,
      satisfactionRate: satisfactionRate ?? this.satisfactionRate,
      riskScore: riskScore ?? this.riskScore,
      slaCompliance: slaCompliance ?? this.slaCompliance,
      availableBalanceMinor: availableBalanceMinor ?? this.availableBalanceMinor,
      escrowBalanceMinor: escrowBalanceMinor ?? this.escrowBalanceMinor,
      releasedFundsMinor: releasedFundsMinor ?? this.releasedFundsMinor,
      monthlyRevenueMinor: monthlyRevenueMinor ?? this.monthlyRevenueMinor,
      revenueGrowthPercent: revenueGrowthPercent ?? this.revenueGrowthPercent,
      negotiations: negotiations ?? this.negotiations,
      contracts: contracts ?? this.contracts,
      crmClients: crmClients ?? this.crmClients,
      team: team ?? this.team,
      insights: insights ?? this.insights,
      notifications: notifications ?? this.notifications,
    );
  }
}

class VendorIntelligenceEngine extends StateNotifier<IntelligenceState> {
  VendorIntelligenceEngine()
      : super(
          IntelligenceState(
            healthScore: 92,
            performanceScore: 4.8,
            satisfactionRate: 97.5,
            riskScore: 8,
            slaCompliance: 99.2,
            availableBalanceMinor: 48500000, // ₦485,000.00
            escrowBalanceMinor: 125000000,  // ₦1,250,000.00
            releasedFundsMinor: 89000000,   // ₦890,000.00
            monthlyRevenueMinor: 175000000,  // ₦1,750,000.00
            revenueGrowthPercent: 24.3,
            negotiations: [
              NegotiationItem(
                id: 'neg_1',
                clientName: 'Wale Adebayo',
                eventName: 'Wale & Shade Wedding Celebration',
                serviceType: 'Catering Setup',
                originalQuoteMinor: 85000000,
                counterQuoteMinor: 80000000,
                status: 'pending_vendor',
                lastUpdated: DateTime.now().subtract(const Duration(hours: 4)),
              ),
              NegotiationItem(
                id: 'neg_2',
                clientName: 'Nneka Eze',
                eventName: 'Silver Jubilee Corporate Gala',
                serviceType: 'Decorations',
                originalQuoteMinor: 150000000,
                counterQuoteMinor: 135000000,
                status: 'pending_client',
                lastUpdated: DateTime.now().subtract(const Duration(days: 1)),
              ),
              NegotiationItem(
                id: 'neg_3',
                clientName: 'Amina Bello',
                eventName: 'Amins Golden Jubilee birthday',
                serviceType: 'DJ & Sound System',
                originalQuoteMinor: 45000000,
                counterQuoteMinor: 45000000,
                status: 'pending_vendor',
                lastUpdated: DateTime.now().subtract(const Duration(hours: 2)),
              ),
            ],
            contracts: [
              ContractItem(
                id: 'con_1',
                clientName: 'Chioma Obi',
                eventName: 'Chiomas Graduation Feast',
                totalValueMinor: 65000000,
                escrowStatus: 'funded',
                milestoneProgress: 0.6,
                status: 'active',
                deliverablesCount: 3,
                obligations: 'Deliver fully set-up buffet tables and catering crew at venue by 10 AM.',
              ),
              ContractItem(
                id: 'con_2',
                clientName: 'Segun Johnson',
                eventName: 'Jollof & Friends Reunion',
                totalValueMinor: 120000000,
                escrowStatus: 'partially_released',
                milestoneProgress: 0.9,
                status: 'active',
                deliverablesCount: 4,
                obligations: 'Setup sound rig, soundcheck completed before 12 PM.',
              ),
            ],
            crmClients: [
              const CrmClient(
                id: 'crm_1',
                name: 'Kemi Ojo',
                segment: 'VIP',
                lifetimeSpendMinor: 450000000,
                eventsBooked: 6,
                latestReview: 'Incredible catering and timing, highly recommend Wale.',
              ),
              const CrmClient(
                id: 'crm_2',
                name: 'Femi Alao',
                segment: 'Returning',
                lifetimeSpendMinor: 185000000,
                eventsBooked: 3,
                latestReview: 'Solid sound set-up and playlist was wonderful.',
              ),
              const CrmClient(
                id: 'crm_3',
                name: 'Bose Adams',
                segment: 'At Risk',
                lifetimeSpendMinor: 50000000,
                eventsBooked: 1,
                latestReview: 'Catering was good but arrival was slightly delayed by traffic.',
              ),
            ],
            team: [
              TeamMember(
                id: 'tm_1',
                name: 'Chinedu Egwu',
                assignment: 'Chiomas Graduation Feast',
                checkInTime: '08:45 AM',
                performance: 4.9,
              ),
              TeamMember(
                id: 'tm_2',
                name: 'Yinka Balogun',
                assignment: 'Jollof & Friends Reunion',
                checkInTime: '10:15 AM',
                performance: 4.7,
              ),
            ],
            insights: [
              IntelligenceInsight(
                message: 'Your response time increased by 18% this week.',
                type: 'warning',
                timestamp: DateTime.now(),
              ),
              IntelligenceInsight(
                message: 'Weekend bookings are up 24% for July.',
                type: 'success',
                timestamp: DateTime.now(),
              ),
              IntelligenceInsight(
                message: 'Three negotiations require your immediate attention.',
                type: 'info',
                timestamp: DateTime.now(),
              ),
            ],
            notifications: [
              'New Quote Counter received for Chiomas Graduation Feast',
              'Escrow Funded successfully for Wale & Shade Wedding',
              'Platform admin approved Listing upgrade request',
            ],
          ),
        );

  void acceptNegotiation(String id) {
    state = state.copyWith(
      negotiations: state.negotiations.map((n) {
        if (n.id == id) {
          n.status = 'accepted';
        }
        return n;
      }).toList(),
      insights: [
        IntelligenceInsight(
          message: 'Quote converted to Active Contract successfully!',
          type: 'success',
          timestamp: DateTime.now(),
        ),
        ...state.insights,
      ],
    );
  }

  void rejectNegotiation(String id) {
    state = state.copyWith(
      negotiations: state.negotiations.map((n) {
        if (n.id == id) {
          n.status = 'rejected';
        }
        return n;
      }).toList(),
    );
  }

  void counterNegotiation(String id, int amountMinor) {
    state = state.copyWith(
      negotiations: state.negotiations.map((n) {
        if (n.id == id) {
          n.counterQuoteMinor = amountMinor;
          n.status = 'pending_client';
        }
        return n;
      }).toList(),
    );
  }

  void updateMilestone(String contractId, double progress) {
    state = state.copyWith(
      contracts: state.contracts.map((c) {
        if (c.id == contractId) {
          c.milestoneProgress = progress;
        }
        return c;
      }).toList(),
    );
  }
}

final vendorIntelligenceProvider =
    StateNotifierProvider<VendorIntelligenceEngine, IntelligenceState>((ref) {
  return VendorIntelligenceEngine();
});
