import 'package:flutter/material.dart';

enum PlatformStatus { healthy, warning, critical }

enum SubsystemTrend { up, down, stable }

class SubsystemHealth {
  const SubsystemHealth({
    required this.id,
    required this.label,
    required this.status,
    required this.responseMs,
    required this.lastCheck,
    required this.trend,
    required this.detail,
  });

  final String id;
  final String label;
  final String status;
  final int responseMs;
  final DateTime lastCheck;
  final SubsystemTrend trend;
  final String detail;
}

class ExecutiveKpi {
  const ExecutiveKpi({
    required this.id,
    required this.title,
    required this.current,
    required this.previous,
    required this.growthPercent,
    required this.sparkline,
    required this.icon,
    required this.formatAsMoney,
    this.invertTrend = false,
    this.tabIndex,
  });

  final String id;
  final String title;
  final num current;
  final num previous;
  final double growthPercent;
  final List<double> sparkline;
  final IconData icon;
  final bool formatAsMoney;
  final bool invertTrend;
  final int? tabIndex;
}

class ExecutiveTenantRow {
  const ExecutiveTenantRow({
    required this.id,
    required this.name,
    required this.status,
    required this.revenueMinor,
    required this.eventCount,
    required this.growthPercent,
    required this.health,
  });

  final String id;
  final String name;
  final String status;
  final int revenueMinor;
  final int eventCount;
  final double growthPercent;
  final String health;
}

class ExecutiveEventRow {
  const ExecutiveEventRow({
    required this.id,
    required this.title,
    required this.tenantName,
    required this.revenueMinor,
    required this.attendees,
    required this.status,
    required this.startsAt,
  });

  final String id;
  final String title;
  final String tenantName;
  final int revenueMinor;
  final int attendees;
  final String status;
  final DateTime? startsAt;
}

class ExecutiveOrganizerRow {
  const ExecutiveOrganizerRow({
    required this.id,
    required this.name,
    required this.tenantName,
    required this.revenueMinor,
    required this.eventCount,
    required this.status,
    required this.growthPercent,
  });

  final String id;
  final String name;
  final String tenantName;
  final int revenueMinor;
  final int eventCount;
  final String status;
  final double growthPercent;
}

class ExecutiveActivityItem {
  const ExecutiveActivityItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    required this.severity,
    required this.tabIndex,
  });

  final String id;
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final String severity;
  final int tabIndex;
}

class ExecutiveAlert {
  const ExecutiveAlert({
    required this.id,
    required this.title,
    required this.message,
    required this.severity,
    required this.tabIndex,
  });

  final String id;
  final String title;
  final String message;
  final String severity;
  final int tabIndex;
}

class ExecutiveSearchResult {
  const ExecutiveSearchResult({
    required this.category,
    required this.title,
    required this.subtitle,
    required this.tabIndex,
    this.tenantId,
  });

  final String category;
  final String title;
  final String subtitle;
  final int tabIndex;
  final String? tenantId;
}

class ExecutiveDashboardData {
  const ExecutiveDashboardData({
    required this.platformStatus,
    required this.healthScore,
    required this.healthSummary,
    required this.subsystems,
    required this.kpis,
    required this.revenueChartPoints,
    required this.activities,
    required this.topTenants,
    required this.topEvents,
    required this.topOrganizers,
    required this.alerts,
    required this.searchIndex,
    required this.healthFetchMs,
  });

  final PlatformStatus platformStatus;
  final int healthScore;
  final String healthSummary;
  final List<SubsystemHealth> subsystems;
  final List<ExecutiveKpi> kpis;
  final List<Map<String, dynamic>> revenueChartPoints;
  final List<ExecutiveActivityItem> activities;
  final List<ExecutiveTenantRow> topTenants;
  final List<ExecutiveEventRow> topEvents;
  final List<ExecutiveOrganizerRow> topOrganizers;
  final List<ExecutiveAlert> alerts;
  final List<ExecutiveSearchResult> searchIndex;
  final int healthFetchMs;
}
