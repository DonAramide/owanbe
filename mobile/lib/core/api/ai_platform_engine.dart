import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// --- DATA MODELS ---

class AiRecommendation {
  final String id;
  final String category; // 'operations', 'commerce', 'security', 'marketing'
  final String label;
  final String reasoning;
  final double confidenceScore;
  final String businessImpact;
  final double financialImpact;
  final String requiredPermission;
  final String suggestedAction;
  final String deepLink;
  String status; // 'active', 'dismissed', 'executed'

  AiRecommendation({
    required this.id,
    required this.category,
    required this.label,
    required this.reasoning,
    required this.confidenceScore,
    required this.businessImpact,
    required this.financialImpact,
    required this.requiredPermission,
    required this.suggestedAction,
    required this.deepLink,
    required this.status,
  });
}

class AiAnomaly {
  final String id;
  final String anomalyType;
  final String description;
  final String severity; // 'low', 'medium', 'high'
  final String sourceEngine;
  final DateTime createdAt;

  AiAnomaly({
    required this.id,
    required this.anomalyType,
    required this.description,
    required this.severity,
    required this.sourceEngine,
    required this.createdAt,
  });
}

class AiPrediction {
  final String metricKey;
  final double forecastValue;
  final DateTime targetDate;

  AiPrediction({
    required this.metricKey,
    required this.forecastValue,
    required this.targetDate,
  });
}

// --- SUB-SERVICES ---

class ContextEngine {
  Map<String, dynamic> getCurrentContext() {
    return {
      'operatorRole': 'Platform Super Admin',
      'permissions': ['vendor.approve', 'campaign.create', 'security.write', 'workflow.approve'],
      'activeTenant': '11111111-1111-4111-8111-111111111111',
      'systemSecurityScore': 96,
      'activeIncidents': 1,
    };
  }
}

class ExecutiveBriefingEngine {
  Map<String, dynamic> generateBriefing() {
    return {
      'healthScore': 96,
      'revenueGrowth': '+18% vs last week',
      'refundRate': '+7%',
      'activeVendorsWaiting': 3,
      'degradedIntegrations': 1,
      'weekendAttendanceForecast': '+22% growth',
      'riskLevel': 'Low',
      'commerceSummary': '₦24.8M revenue generated. Ticket sales running at optimal volume.',
      'securitySummary': 'MFA configuration drift detection resolved on usr_1.',
      'operationsSummary': 'Workflow queue average resolution latency: 34.2 mins.',
    };
  }
}

class InsightEngine {
  List<String> getGlobalInsights() {
    return [
      'Refund spikes match duplicate checkout retry events in ticket commerce rail.',
      'Photographer category searches dominate vendor marketplace onboarding queries.',
    ];
  }
}

class PredictionEngine {
  List<AiPrediction> getPredictions() {
    return [
      AiPrediction(metricKey: 'attendance', forecastValue: 1240.0, targetDate: DateTime.now().add(const Duration(days: 5))),
      AiPrediction(metricKey: 'ticket_sales', forecastValue: 4500000.0, targetDate: DateTime.now().add(const Duration(days: 5))),
      AiPrediction(metricKey: 'api_traffic', forecastValue: 88200.0, targetDate: DateTime.now().add(const Duration(days: 5))),
    ];
  }
}

class RecommendationEngine {
  final List<AiRecommendation> _recommendations = [];
  List<AiRecommendation> get recommendations => List.unmodifiable(_recommendations);

  RecommendationEngine() {
    _seedDefaultRecommendations();
  }

  void _seedDefaultRecommendations() {
    _recommendations.addAll([
      AiRecommendation(
        id: 'rec_1',
        category: 'operations',
        label: 'Approve Pending Vendors',
        reasoning: '3 vendors have been in the onboarding verification queue for > 48 hours.',
        confidenceScore: 0.950,
        businessImpact: 'Speeds up vendor onboarding flow and adds marketplace depth.',
        financialImpact: 1200000.00,
        requiredPermission: 'vendor.approve',
        suggestedAction: 'Go to Verification Center and approve compliance documents.',
        deepLink: '/admin/verifications',
        status: 'active',
      ),
      AiRecommendation(
        id: 'rec_2',
        category: 'commerce',
        label: 'Launch Reminder Campaign',
        reasoning: 'Ticket sales for Owambe Staging Gala are slowing down. predicted attendance is dropping.',
        confidenceScore: 0.890,
        businessImpact: 'Boosts ticket sales and increases weekend event attendance.',
        financialImpact: 8500000.00,
        requiredPermission: 'campaign.create',
        suggestedAction: 'Go to Communication Center and launch the scheduled reminder campaign.',
        deepLink: '/admin/communications',
        status: 'active',
      ),
      AiRecommendation(
        id: 'rec_3',
        category: 'security',
        label: 'Investigate Security Incidents',
        reasoning: 'Drift detected in MFA authentication settings for usr_1.',
        confidenceScore: 0.980,
        businessImpact: 'Protects administrator accounts against credential compromise.',
        financialImpact: 0.00,
        requiredPermission: 'security.write',
        suggestedAction: 'Go to Security Center and verify authentication logs.',
        deepLink: '/admin/security',
        status: 'active',
      ),
    ]);
  }

  void updateStatus(String id, String status) {
    final idx = _recommendations.indexWhere((r) => r.id == id);
    if (idx != -1) {
      _recommendations[idx].status = status;
    }
  }
}

class DecisionEngine {
  bool checkPermissions(AiRecommendation rec, List<String> userPermissions) {
    return userPermissions.contains(rec.requiredPermission);
  }
}

class AutomationAdvisor {
  List<String> getAutomationOpportunities() {
    return [
      'Automate vendor_verified rule check with identity verification API.',
      'SLA timers optimization: Reducing standard review SLA from 4 hours to 2 hours.',
    ];
  }
}

class AnomalyDetectionEngine {
  List<AiAnomaly> getAnomalies() {
    return [
      AiAnomaly(
        id: 'anom_1',
        anomalyType: 'refund_spike',
        description: 'Refund rate increased by 18% over the last 24 hours.',
        severity: 'high',
        sourceEngine: 'CommerceEngine',
        createdAt: DateTime.now().subtract(const Duration(hours: 4)),
      ),
      AiAnomaly(
        id: 'anom_2',
        anomalyType: 'security_drift',
        description: 'MFA config drift detected on usr_1.',
        severity: 'medium',
        sourceEngine: 'SecurityEngine',
        createdAt: DateTime.now().subtract(const Duration(hours: 12)),
      ),
    ];
  }
}

class KnowledgeEngine {
  final Map<String, List<String>> knowledgeGraph = {
    'Tenants': ['Organizers', 'Finance Tables'],
    'Organizers': ['Events', 'Settlement Profiles'],
    'Events': ['Vendors', 'Attendees', 'Tickets'],
    'Vendors': ['Marketplace Listings', 'Services'],
    'Attendees': ['Payments', 'Check-ins'],
  };
}

class SemanticSearchEngine {
  List<Map<String, String>> search(String query) {
    final q = query.toLowerCase();
    final mockEntities = [
      {'label': 'usr_3: Femi Balogun', 'type': 'Vendor Profile', 'link': '/admin/verifications', 'snippet': 'Awaiting Compliance Approval'},
      {'label': 'evt_1: Owambe Staging Gala', 'type': 'Event', 'link': '/admin/workflows', 'snippet': 'Status: Under Review'},
      {'label': 'Refund claim #9201', 'type': 'Commerce Transaction', 'link': '/admin/commerce', 'snippet': 'Spike: 18% yesterday'},
    ];
    return mockEntities.where((e) {
      return e['label']!.toLowerCase().contains(q) ||
             e['type']!.toLowerCase().contains(q) ||
             e['snippet']!.toLowerCase().contains(q);
    }).toList();
  }
}

// --- CENTRAL INTEL PLATFORM ---

class AiPlatformEngine extends ChangeNotifier {
  // Sub-Services
  final ContextEngine context = ContextEngine();
  final ExecutiveBriefingEngine briefing = ExecutiveBriefingEngine();
  final InsightEngine insight = InsightEngine();
  final PredictionEngine prediction = PredictionEngine();
  final RecommendationEngine recommendation = RecommendationEngine();
  final DecisionEngine decision = DecisionEngine();
  final AutomationAdvisor advisor = AutomationAdvisor();
  final AnomalyDetectionEngine anomaly = AnomalyDetectionEngine();
  final KnowledgeEngine knowledge = KnowledgeEngine();
  final SemanticSearchEngine searchEngine = SemanticSearchEngine();

  List<AiRecommendation> get recommendations => recommendation.recommendations;
  List<AiAnomaly> get anomalies => anomaly.getAnomalies();
  List<AiPrediction> get predictions => prediction.getPredictions();

  AiPlatformEngine();

  List<AiRecommendation> getFilteredRecommendations() {
    final ctx = context.getCurrentContext();
    final perms = List<String>.from(ctx['permissions'] as List);
    return recommendations.where((rec) => decision.checkPermissions(rec, perms)).toList();
  }

  void executeDecision(String recId) {
    recommendation.updateStatus(recId, 'executed');
    notifyListeners();
  }

  void dismissDecision(String recId) {
    recommendation.updateStatus(recId, 'dismissed');
    notifyListeners();
  }
}

final aiPlatformEngineProvider = ChangeNotifierProvider<AiPlatformEngine>((ref) {
  return AiPlatformEngine();
});
