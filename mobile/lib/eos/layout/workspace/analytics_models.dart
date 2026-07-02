import 'package:flutter/material.dart';

enum TimeRange {
  today,
  yesterday,
  last7Days,
  last30Days,
  last90Days,
  thisMonth,
  lastMonth,
  quarter,
  year,
  custom,
}

class AnalyticsDimension {
  const AnalyticsDimension({
    this.tenantId,
    this.organizerId,
    this.eventId,
    this.vendorId,
    this.city,
    this.category,
    this.status,
  });

  final String? tenantId;
  final String? organizerId;
  final String? eventId;
  final String? vendorId;
  final String? city;
  final String? category;
  final String? status;
}

class AnalyticsInsight {
  const AnalyticsInsight({
    required this.id,
    required this.title,
    required this.severity,
    required this.confidence,
    required this.businessImpact,
    required this.reason,
    required this.affectedEntities,
    required this.recommendation,
    required this.financialImpactMinor,
  });

  final String id;
  final String title;
  final String severity;
  final double confidence;
  final String businessImpact;
  final String reason;
  final List<String> affectedEntities;
  final String recommendation;
  final int financialImpactMinor;
}
