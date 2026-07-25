import '../models/ai_planner_models.dart';
import '../models/customer_event_models.dart';

/// Portfolio-level KPI rollup — derived from [CustomerEvent] list only.
class PortfolioKpiSnapshot {
  const PortfolioKpiSnapshot({
    required this.totalEvents,
    required this.activeEvents,
    required this.completedEvents,
    required this.cancelledEvents,
    required this.revenueMinor,
    required this.profitMinor,
    required this.guestsInvited,
    required this.ticketsSold,
    required this.vendorRequests,
    required this.vendorSpendMinor,
    required this.outstandingMinor,
    required this.averageSuccessScore,
  });

  final int totalEvents;
  final int activeEvents;
  final int completedEvents;
  final int cancelledEvents;
  final int revenueMinor;
  final int profitMinor;
  final int guestsInvited;
  final int ticketsSold;
  final int vendorRequests;
  final int vendorSpendMinor;
  final int outstandingMinor;
  final int averageSuccessScore;
}

class PortfolioEventRow {
  const PortfolioEventRow({
    required this.eventId,
    required this.title,
    required this.category,
    required this.status,
    required this.startsAt,
    required this.revenueMinor,
    required this.ticketsSold,
    required this.successScore,
    required this.guestCount,
  });

  final String eventId;
  final String title;
  final String category;
  final CustomerEventStatus status;
  final DateTime startsAt;
  final int revenueMinor;
  final int ticketsSold;
  final int successScore;
  final int guestCount;
}

class PortfolioTimelineEntry {
  const PortfolioTimelineEntry({
    required this.eventId,
    required this.title,
    required this.startsAt,
    required this.status,
    required this.daysUntil,
  });

  final String eventId;
  final String title;
  final DateTime startsAt;
  final CustomerEventStatus status;
  final int daysUntil;
}

class PortfolioTrendPoint {
  const PortfolioTrendPoint({
    required this.label,
    required this.value,
  });

  final String label;
  final double value;
}

class PortfolioAnalyticsSnapshot {
  const PortfolioAnalyticsSnapshot({
    required this.revenueTrend,
    required this.guestGrowth,
    required this.attendanceTrend,
    required this.vendorCostTrend,
    required this.ticketPerformance,
    required this.profitTrend,
    required this.completionQuality,
    required this.budgetEfficiency,
    required this.eventComparisons,
  });

  final List<PortfolioTrendPoint> revenueTrend;
  final List<PortfolioTrendPoint> guestGrowth;
  final List<PortfolioTrendPoint> attendanceTrend;
  final List<PortfolioTrendPoint> vendorCostTrend;
  final List<PortfolioTrendPoint> ticketPerformance;
  final List<PortfolioTrendPoint> profitTrend;
  final List<PortfolioTrendPoint> completionQuality;
  final List<PortfolioTrendPoint> budgetEfficiency;
  final List<PortfolioEventRow> eventComparisons;
}

class CopilotInsight {
  const CopilotInsight({
    required this.message,
    required this.category,
    this.eventId,
    this.priority = 0,
  });

  final String message;
  final String category;
  final String? eventId;
  final int priority;
}

class PortfolioVendorRank {
  const PortfolioVendorRank({
    required this.vendorKey,
    required this.businessName,
    required this.service,
    required this.reliabilityScore,
    required this.completionRate,
    required this.acceptanceRate,
    required this.repeatHireCount,
    required this.averageCostMinor,
    required this.eventsServed,
    required this.bestCategory,
  });

  final String vendorKey;
  final String businessName;
  final String service;
  final int reliabilityScore;
  final int completionRate;
  final int acceptanceRate;
  final int repeatHireCount;
  final int averageCostMinor;
  final int eventsServed;
  final String bestCategory;
}

class PortfolioGuestInsight {
  const PortfolioGuestInsight({
    required this.repeatAttendees,
    required this.vipGuests,
    required this.mostInvitedGuests,
    required this.averageNoShowRate,
    required this.rsvpAcceptRate,
    required this.averageEngagementScore,
  });

  final int repeatAttendees;
  final int vipGuests;
  final List<String> mostInvitedGuests;
  final int averageNoShowRate;
  final int rsvpAcceptRate;
  final int averageEngagementScore;
}

class PortfolioFinancialSnapshot {
  const PortfolioFinancialSnapshot({
    required this.monthlyRevenue,
    required this.totalProfitMinor,
    required this.outstandingSettlementsMinor,
    required this.refundTrend,
    required this.vendorSpendMinor,
    required this.budgetAccuracyPct,
    required this.averageTicketYieldMinor,
    required this.topRevenueEvents,
  });

  final List<PortfolioTrendPoint> monthlyRevenue;
  final int totalProfitMinor;
  final int outstandingSettlementsMinor;
  final List<PortfolioTrendPoint> refundTrend;
  final int vendorSpendMinor;
  final int budgetAccuracyPct;
  final int averageTicketYieldMinor;
  final List<PortfolioEventRow> topRevenueEvents;
}

class AutomationAlert {
  const AutomationAlert({
    required this.title,
    required this.message,
    required this.severity,
    required this.eventId,
    required this.kind,
  });

  final String title;
  final String message;
  final String severity;
  final String eventId;
  final String kind;
}

class ExecutiveDashboardSnapshot {
  const ExecutiveDashboardSnapshot({
    required this.portfolioHealth,
    required this.monthlyRevenueMinor,
    required this.organizerGrowthPct,
    required this.vendorNetworkSize,
    required this.customerGrowthPct,
    required this.repeatCustomerRate,
    required this.eventSuccessScore,
    required this.operationalRiskLevel,
    required this.aiRecommendations,
  });

  final int portfolioHealth;
  final int monthlyRevenueMinor;
  final int organizerGrowthPct;
  final int vendorNetworkSize;
  final int customerGrowthPct;
  final int repeatCustomerRate;
  final int eventSuccessScore;
  final String operationalRiskLevel;
  final List<String> aiRecommendations;
}

class OrganizerPortfolioWorkspace {
  const OrganizerPortfolioWorkspace({
    required this.kpis,
    required this.upcomingEvents,
    required this.timeline,
    required this.analytics,
    required this.copilotInsights,
    required this.vendorRankings,
    required this.guestInsights,
    required this.financial,
    required this.automationAlerts,
    required this.executive,
    required this.weeklyBriefing,
  });

  final PortfolioKpiSnapshot kpis;
  final List<PortfolioEventRow> upcomingEvents;
  final List<PortfolioTimelineEntry> timeline;
  final PortfolioAnalyticsSnapshot analytics;
  final List<CopilotInsight> copilotInsights;
  final List<PortfolioVendorRank> vendorRankings;
  final PortfolioGuestInsight guestInsights;
  final PortfolioFinancialSnapshot financial;
  final List<AutomationAlert> automationAlerts;
  final ExecutiveDashboardSnapshot executive;
  final List<String> weeklyBriefing;
}

bool _isActive(CustomerEvent event) {
  return event.status == CustomerEventStatus.draft ||
      event.status == CustomerEventStatus.published ||
      event.status == CustomerEventStatus.live;
}

int computeEventSuccessScore(CustomerEvent event) {
  if (event.status == CustomerEventStatus.cancelled) return 0;
  final capacity = event.totalCapacity > 0 ? event.totalCapacity : event.expectedGuests;
  final sellThrough = capacity > 0 ? ((event.ticketsSold / capacity) * 100).round() : 50;
  final vendorScore = event.vendors.isEmpty
      ? 50
      : ((event.vendors.where((v) => v.status == CustomerVendorSlotStatus.approved).length /
                  event.vendors.length) *
              100)
          .round();
  final statusBonus = switch (event.status) {
    CustomerEventStatus.completed => 15,
    CustomerEventStatus.live => 10,
    CustomerEventStatus.published => 5,
    _ => 0,
  };
  return ((sellThrough * 0.5) + (vendorScore * 0.35) + statusBonus).round().clamp(0, 100);
}

PortfolioKpiSnapshot buildPortfolioKpiSnapshot(List<CustomerEvent> events) {
  var revenue = 0;
  var tickets = 0;
  var guests = 0;
  var vendorRequests = 0;
  var vendorSpend = 0;
  var outstanding = 0;
  var profit = 0;
  var successTotal = 0;
  var successCount = 0;

  for (final event in events) {
    revenue += event.revenueMinor;
    tickets += event.ticketsSold;
    guests += event.expectedGuests > 0 ? event.expectedGuests : event.attendees.length;
    vendorRequests += event.vendors.length;
    vendorSpend += event.vendors.fold<int>(0, (s, v) => s + v.revenueMinor);
    outstanding += (event.budgetMinor - event.revenueMinor).clamp(0, event.budgetMinor);
    profit += event.revenueMinor - (event.budgetMinor > 0 ? (event.budgetMinor * 0.7).round() : 0);
    if (event.status == CustomerEventStatus.completed) {
      successTotal += computeEventSuccessScore(event);
      successCount++;
    }
  }

  return PortfolioKpiSnapshot(
    totalEvents: events.length,
    activeEvents: events.where(_isActive).length,
    completedEvents: events.where((e) => e.status == CustomerEventStatus.completed).length,
    cancelledEvents: events.where((e) => e.status == CustomerEventStatus.cancelled).length,
    revenueMinor: revenue,
    profitMinor: profit,
    guestsInvited: guests,
    ticketsSold: tickets,
    vendorRequests: vendorRequests,
    vendorSpendMinor: vendorSpend,
    outstandingMinor: outstanding,
    averageSuccessScore: successCount > 0 ? (successTotal / successCount).round() : 0,
  );
}

List<PortfolioEventRow> buildPortfolioEventRows(List<CustomerEvent> events) {
  return [
    for (final event in events)
      PortfolioEventRow(
        eventId: event.id,
        title: event.title,
        category: event.category,
        status: event.status,
        startsAt: event.startsAt,
        revenueMinor: event.revenueMinor,
        ticketsSold: event.ticketsSold,
        successScore: computeEventSuccessScore(event),
        guestCount: event.expectedGuests > 0 ? event.expectedGuests : event.attendees.length,
      ),
  ];
}

List<PortfolioTimelineEntry> buildPortfolioTimeline(List<CustomerEvent> events) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final sorted = [...events]..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  return [
    for (final event in sorted.take(12))
      PortfolioTimelineEntry(
        eventId: event.id,
        title: event.title,
        startsAt: event.startsAt,
        status: event.status,
        daysUntil: DateTime(event.startsAt.year, event.startsAt.month, event.startsAt.day)
            .difference(today)
            .inDays,
      ),
  ];
}

List<PortfolioTrendPoint> _monthlyRollup(
  List<CustomerEvent> events,
  double Function(CustomerEvent event) valueFor,
) {
  final buckets = <String, double>{};
  for (final event in events) {
    final key = '${event.startsAt.year}-${event.startsAt.month.toString().padLeft(2, '0')}';
    buckets[key] = (buckets[key] ?? 0) + valueFor(event);
  }
  final keys = buckets.keys.toList()..sort();
  return [
    for (final key in keys.take(6))
      PortfolioTrendPoint(label: key, value: buckets[key]!),
  ];
}

PortfolioAnalyticsSnapshot buildPortfolioAnalytics(List<CustomerEvent> events) {
  final rows = buildPortfolioEventRows(events);
  final sortedByRevenue = [...rows]..sort((a, b) => b.revenueMinor.compareTo(a.revenueMinor));

  return PortfolioAnalyticsSnapshot(
    revenueTrend: _monthlyRollup(events, (e) => e.revenueMinor.toDouble()),
    guestGrowth: _monthlyRollup(
      events,
      (e) => (e.expectedGuests > 0 ? e.expectedGuests : e.attendees.length).toDouble(),
    ),
    attendanceTrend: _monthlyRollup(
      events,
      (e) {
        final cap = e.totalCapacity > 0 ? e.totalCapacity : e.expectedGuests;
        return cap > 0 ? (e.ticketsSold / cap) * 100 : 0.0;
      },
    ),
    vendorCostTrend: _monthlyRollup(
      events,
      (e) => e.vendors.fold<double>(0, (s, v) => s + v.revenueMinor),
    ),
    ticketPerformance: _monthlyRollup(events, (e) => e.ticketsSold.toDouble()),
    profitTrend: _monthlyRollup(
      events,
      (e) => (e.revenueMinor - (e.budgetMinor > 0 ? e.budgetMinor * 0.7 : 0)).toDouble(),
    ),
    completionQuality: _monthlyRollup(
      events.where((e) => e.status == CustomerEventStatus.completed).toList(),
      (e) => computeEventSuccessScore(e).toDouble(),
    ),
    budgetEfficiency: _monthlyRollup(
      events.where((e) => e.budgetMinor > 0).toList(),
      (e) => e.revenueMinor > 0 ? (e.revenueMinor / e.budgetMinor) * 100 : 0.0,
    ),
    eventComparisons: sortedByRevenue.take(8).toList(),
  );
}

List<CopilotInsight> buildPortfolioCopilotInsights(List<CustomerEvent> events) {
  final insights = <CopilotInsight>[];
  if (events.isEmpty) {
    return [
      const CopilotInsight(
        message: 'Create your first event to unlock portfolio intelligence.',
        category: 'Getting started',
        priority: 10,
      ),
    ];
  }

  final completed = events.where((e) => e.status == CustomerEventStatus.completed).toList();
  final upcoming = events.where(_isActive).toList()
    ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

  final cateringSpend = completed.fold<int>(0, (s, e) {
    return s +
        e.vendors.where((v) => v.category.toLowerCase().contains('cater')).fold<int>(
              0,
              (vs, v) => vs + v.revenueMinor,
            );
  });
  final totalBudget = completed.fold<int>(0, (s, e) => s + e.budgetMinor);
  if (totalBudget > 0 && cateringSpend > totalBudget * 0.28) {
    insights.add(const CopilotInsight(
      message: 'You consistently allocate a high share of budget to catering across completed events.',
      category: 'Budget pattern',
      priority: 8,
    ));
  }

  final weddingEvents = completed.where((e) => e.category.toLowerCase().contains('wedd')).toList();
  if (weddingEvents.isNotEmpty) {
    var attendanceSum = 0.0;
    for (final e in weddingEvents) {
      final cap = e.totalCapacity > 0 ? e.totalCapacity : e.expectedGuests;
      if (cap > 0) attendanceSum += e.ticketsSold / cap;
    }
    final avgAttendance = ((attendanceSum / weddingEvents.length) * 100).round();
    insights.add(CopilotInsight(
      message: 'Your weddings average $avgAttendance% ticket attendance.',
      category: 'Guest pattern',
      priority: 7,
    ));
  }

  final vendorCounts = <String, int>{};
  for (final event in completed) {
    for (final vendor in event.vendors.where((v) => v.ordersCount > 0)) {
      vendorCounts[vendor.businessName] = (vendorCounts[vendor.businessName] ?? 0) + 1;
    }
  }
  if (vendorCounts.isNotEmpty) {
    final top = vendorCounts.entries.reduce((a, b) => a.value >= b.value ? a : b);
    insights.add(CopilotInsight(
      message: '${top.key} has completed ${top.value} events successfully in your portfolio.',
      category: 'Vendor pattern',
      priority: 6,
    ));
  }

  final ticketPrices = <int>[];
  for (final event in completed) {
    for (final tier in event.ticketTiers) {
      if (tier.capacity > tier.remaining) ticketPrices.add(tier.priceMinor);
    }
  }
  if (ticketPrices.isNotEmpty) {
    ticketPrices.sort();
    final median = ticketPrices[ticketPrices.length ~/ 2];
    insights.add(CopilotInsight(
      message: 'Your best-performing ticket price band centers around ${median ~/ 100} NGN.',
      category: 'Ticket pricing',
      priority: 5,
    ));
  }

  if (upcoming.isNotEmpty) {
    final next = upcoming.first;
    final hasSecurity = next.vendors.any((v) => v.category.toLowerCase().contains('secur'));
    if (!hasSecurity) {
      insights.add(CopilotInsight(
        message: 'Your next event "${next.title}" is missing Security in vendor bookings.',
        category: 'Proactive',
        eventId: next.id,
        priority: 9,
      ));
    }

    final decemberWeddings = completed
        .where((e) => e.category.toLowerCase().contains('wedd') && e.startsAt.month == 12)
        .toList();
    if (decemberWeddings.isNotEmpty) {
      final scores = decemberWeddings.map(computeEventSuccessScore);
      final avg = scores.isEmpty ? 0 : scores.reduce((a, b) => a + b) ~/ scores.length;
      if (avg >= 80) {
        insights.add(const CopilotInsight(
          message: 'Wedding events perform better in December based on your portfolio history.',
          category: 'Seasonal',
          priority: 4,
        ));
      }
    }

    final birthdayOverBudget = completed
        .where((e) => e.category.toLowerCase().contains('birth') && e.budgetMinor > 0)
        .where((e) => e.revenueMinor < e.budgetMinor)
        .length;
    if (birthdayOverBudget > 0 && completed.isNotEmpty) {
      final pct = ((birthdayOverBudget / completed.length) * 100).round();
      if (pct >= 10) {
        insights.add(CopilotInsight(
          message: 'Birthday events usually exceed budget — $pct% of completed events ran over.',
          category: 'Budget risk',
          priority: 7,
        ));
      }
    }
  }

  insights.sort((a, b) => b.priority.compareTo(a.priority));
  return insights;
}

List<PortfolioVendorRank> buildPortfolioVendorRankings(List<CustomerEvent> events) {
  final records = <String, _VendorAggregate>{};

  for (final event in events) {
    for (final vendor in event.vendors) {
      final key = vendor.catalogVendorId ?? vendor.businessName;
      final agg = records.putIfAbsent(key, () => _VendorAggregate(vendor.businessName, vendor.category));
      agg.eventsServed++;
      agg.totalCost += vendor.revenueMinor;
      if (vendor.status == CustomerVendorSlotStatus.approved) agg.accepted++;
      if (vendor.ordersCount > 0) {
        agg.completed++;
        agg.repeatHire++;
      }
      agg.categories[event.category] = (agg.categories[event.category] ?? 0) + 1;
    }
  }

  final ranks = records.entries.map((entry) {
    final agg = entry.value;
    final acceptance = agg.eventsServed > 0 ? ((agg.accepted / agg.eventsServed) * 100).round() : 0;
    final completion = agg.eventsServed > 0 ? ((agg.completed / agg.eventsServed) * 100).round() : 0;
    final reliability = ((acceptance * 0.4) + (completion * 0.6)).round();
    final bestCategory = agg.categories.entries.isEmpty
        ? agg.service
        : agg.categories.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

    return PortfolioVendorRank(
      vendorKey: entry.key,
      businessName: agg.name,
      service: agg.service,
      reliabilityScore: reliability,
      completionRate: completion,
      acceptanceRate: acceptance,
      repeatHireCount: agg.repeatHire,
      averageCostMinor: agg.eventsServed > 0 ? agg.totalCost ~/ agg.eventsServed : 0,
      eventsServed: agg.eventsServed,
      bestCategory: bestCategory,
    );
  }).toList();

  ranks.sort((a, b) => b.reliabilityScore.compareTo(a.reliabilityScore));
  return ranks.take(10).toList();
}

class _VendorAggregate {
  _VendorAggregate(this.name, this.service);

  final String name;
  final String service;
  int eventsServed = 0;
  int accepted = 0;
  int completed = 0;
  int repeatHire = 0;
  int totalCost = 0;
  final Map<String, int> categories = {};
}

PortfolioGuestInsight buildPortfolioGuestInsight(List<CustomerEvent> events) {
  final emailCounts = <String, int>{};
  var vipCount = 0;
  var totalGuests = 0;
  var checkedIn = 0;

  for (final event in events) {
    for (final attendee in event.attendees) {
      totalGuests++;
      if (attendee.checkedIn) checkedIn++;
      final key = attendee.email.trim().toLowerCase();
      if (key.isNotEmpty) emailCounts[key] = (emailCounts[key] ?? 0) + 1;
      if (attendee.tierName.toLowerCase().contains('vip')) vipCount++;
    }
  }

  final repeat = emailCounts.values.where((c) => c > 1).length;
  final topGuests = emailCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return PortfolioGuestInsight(
    repeatAttendees: repeat,
    vipGuests: vipCount,
    mostInvitedGuests: topGuests.take(5).map((e) => e.key).toList(),
    averageNoShowRate: totalGuests > 0 ? (((totalGuests - checkedIn) / totalGuests) * 100).round() : 0,
    rsvpAcceptRate: totalGuests > 0 ? ((checkedIn / totalGuests) * 100).round() : 0,
    averageEngagementScore: totalGuests > 0 ? ((checkedIn / totalGuests) * 100).round() : 0,
  );
}

PortfolioFinancialSnapshot buildPortfolioFinancialSnapshot(List<CustomerEvent> events) {
  final rows = buildPortfolioEventRows(events);
  final top = [...rows]..sort((a, b) => b.revenueMinor.compareTo(a.revenueMinor));
  final totalProfit = events.fold<int>(
    0,
    (s, e) => s + e.revenueMinor - (e.budgetMinor > 0 ? (e.budgetMinor * 0.7).round() : 0),
  );
  final vendorSpend = events.fold<int>(0, (s, e) => s + e.vendors.fold(0, (vs, v) => vs + v.revenueMinor));
  final outstanding = events.fold<int>(0, (s, e) => s + e.refundRequests * 10000);
  final budgetEvents = events.where((e) => e.budgetMinor > 0).toList();
  final accuracy = budgetEvents.isEmpty
      ? 100
      : budgetEvents
              .where((e) => e.revenueMinor >= e.budgetMinor * 0.85)
              .length /
          budgetEvents.length *
          100;

  final soldTickets = events.fold<int>(0, (s, e) => s + e.ticketsSold);
  final revenue = events.fold<int>(0, (s, e) => s + e.revenueMinor);

  return PortfolioFinancialSnapshot(
    monthlyRevenue: _monthlyRollup(events, (e) => e.revenueMinor.toDouble()),
    totalProfitMinor: totalProfit,
    outstandingSettlementsMinor: outstanding,
    refundTrend: _monthlyRollup(events, (e) => e.refundRequests.toDouble()),
    vendorSpendMinor: vendorSpend,
    budgetAccuracyPct: accuracy.round(),
    averageTicketYieldMinor: soldTickets > 0 ? revenue ~/ soldTickets : 0,
    topRevenueEvents: top.take(5).toList(),
  );
}

List<AutomationAlert> buildPortfolioAutomationAlerts(List<CustomerEvent> events) {
  final alerts = <AutomationAlert>[];
  final now = DateTime.now();

  for (final event in events.where(_isActive)) {
    final daysUntil = event.startsAt.difference(now).inDays;

    if (event.vendors.isEmpty && daysUntil <= 60) {
      alerts.add(AutomationAlert(
        title: 'Vendor gap',
        message: '${event.title} has no vendors booked yet.',
        severity: daysUntil <= 14 ? 'high' : 'medium',
        eventId: event.id,
        kind: 'overdue_vendors',
      ));
    }

    if (event.status == CustomerEventStatus.draft && daysUntil <= 30) {
      alerts.add(AutomationAlert(
        title: 'Unpublished draft',
        message: '${event.title} is still a draft with $daysUntil days until start.',
        severity: 'high',
        eventId: event.id,
        kind: 'planning_risk',
      ));
    }

    if (event.isPublicTicketed && event.ticketTiers.isNotEmpty && event.ticketsSold == 0 && daysUntil <= 21) {
      alerts.add(AutomationAlert(
        title: 'Low ticket sales',
        message: '${event.title} has zero ticket sales with $daysUntil days remaining.',
        severity: 'medium',
        eventId: event.id,
        kind: 'ticket_pricing',
      ));
    }

    if (event.budgetMinor > 0 && event.revenueMinor < event.budgetMinor * 0.3 && daysUntil <= 14) {
      alerts.add(AutomationAlert(
        title: 'Budget overrun risk',
        message: '${event.title} revenue is trailing budget with the event approaching.',
        severity: 'medium',
        eventId: event.id,
        kind: 'budget_overrun',
      ));
    }

    if (event.expectedGuests > 0 && event.attendees.isEmpty && daysUntil <= 21) {
      alerts.add(AutomationAlert(
        title: 'Missing guests',
        message: '${event.title} has no guests added yet.',
        severity: 'medium',
        eventId: event.id,
        kind: 'missing_guests',
      ));
    }
  }

  alerts.sort((a, b) => a.severity == 'high' ? -1 : 1);
  return alerts;
}

ExecutiveDashboardSnapshot buildExecutiveDashboard({
  required PortfolioKpiSnapshot kpis,
  required PortfolioAnalyticsSnapshot analytics,
  required List<CopilotInsight> copilot,
  required List<AutomationAlert> alerts,
  required PortfolioGuestInsight guests,
  required List<CustomerEvent> events,
}) {
  final risk = alerts.where((a) => a.severity == 'high').length;
  final riskLevel = risk >= 3 ? 'Elevated' : risk >= 1 ? 'Moderate' : 'Low';
  final growth = events.length >= 2 ? ((events.length / 2) * 100).round().clamp(0, 200) : 0;
  final uniqueVendors = events.expand((e) => e.vendors.map((v) => v.catalogVendorId ?? v.businessName)).toSet().length;

  return ExecutiveDashboardSnapshot(
    portfolioHealth: kpis.averageSuccessScore > 0 ? kpis.averageSuccessScore : 70,
    monthlyRevenueMinor: analytics.revenueTrend.isNotEmpty
        ? analytics.revenueTrend.last.value.round()
        : kpis.revenueMinor,
    organizerGrowthPct: growth,
    vendorNetworkSize: uniqueVendors,
    customerGrowthPct: guests.repeatAttendees > 0 ? (guests.repeatAttendees * 10).clamp(0, 100) : 0,
    repeatCustomerRate: guests.repeatAttendees,
    eventSuccessScore: kpis.averageSuccessScore,
    operationalRiskLevel: riskLevel,
    aiRecommendations: [
      for (final insight in copilot.take(4)) insight.message,
    ],
  );
}

List<String> buildWeeklyOrganizerBriefing({
  required PortfolioKpiSnapshot kpis,
  required List<AutomationAlert> alerts,
  required List<CopilotInsight> copilot,
  required List<PortfolioTimelineEntry> timeline,
}) {
  final lines = <String>[
    'Weekly organizer briefing',
    'Portfolio: ${kpis.totalEvents} events · ${kpis.activeEvents} active · ${kpis.completedEvents} completed',
    'Revenue: ${kpis.revenueMinor ~/ 100} NGN · Success score: ${kpis.averageSuccessScore}/100',
  ];

  if (timeline.isNotEmpty) {
    final next = timeline.firstWhere((t) => t.daysUntil >= 0, orElse: () => timeline.first);
    lines.add('Next up: ${next.title} in ${next.daysUntil} days');
  }

  if (alerts.isNotEmpty) {
    lines.add('${alerts.length} automation alert(s) need attention');
    lines.add('- ${alerts.first.title}: ${alerts.first.message}');
  }

  if (copilot.isNotEmpty) {
    lines.add('Copilot: ${copilot.first.message}');
  }

  return lines;
}

OrganizerPortfolioWorkspace buildOrganizerPortfolioWorkspace(List<CustomerEvent> events) {
  final kpis = buildPortfolioKpiSnapshot(events);
  final rows = buildPortfolioEventRows(events);
  final activeIds = events.where(_isActive).map((e) => e.id).toSet();
  final upcoming = rows.where((r) => activeIds.contains(r.eventId)).toList()
    ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  final timeline = buildPortfolioTimeline(events);
  final analytics = buildPortfolioAnalytics(events);
  final copilot = buildPortfolioCopilotInsights(events);
  final vendors = buildPortfolioVendorRankings(events);
  final guests = buildPortfolioGuestInsight(events);
  final financial = buildPortfolioFinancialSnapshot(events);
  final alerts = buildPortfolioAutomationAlerts(events);
  final executive = buildExecutiveDashboard(
    kpis: kpis,
    analytics: analytics,
    copilot: copilot,
    alerts: alerts,
    guests: guests,
    events: events,
  );
  final briefing = buildWeeklyOrganizerBriefing(
    kpis: kpis,
    alerts: alerts,
    copilot: copilot,
    timeline: timeline,
  );

  return OrganizerPortfolioWorkspace(
    kpis: kpis,
    upcomingEvents: upcoming.take(6).toList(),
    timeline: timeline,
    analytics: analytics,
    copilotInsights: copilot,
    vendorRankings: vendors,
    guestInsights: guests,
    financial: financial,
    automationAlerts: alerts,
    executive: executive,
    weeklyBriefing: briefing,
  );
}

/// Maps portfolio category labels to AI planner event types for template baselines.
AiPlannerEventType categoryToPlannerType(String category) =>
    AiPlannerEventTypeX.fromCategory(category);
