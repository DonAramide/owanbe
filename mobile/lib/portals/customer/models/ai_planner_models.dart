import '../../../core/api/vendors_api.dart';
import '../../../features/organizer/models/organizer_models.dart';
import 'budget_dashboard_models.dart';
import 'marketplace_models.dart';

enum AiPlannerEventType {
  wedding,
  birthday,
  corporate,
  festival,
  babyShower,
  anniversary,
}

extension AiPlannerEventTypeX on AiPlannerEventType {
  String get label => switch (this) {
        AiPlannerEventType.wedding => 'Wedding',
        AiPlannerEventType.birthday => 'Birthday / Owanbe',
        AiPlannerEventType.corporate => 'Corporate',
        AiPlannerEventType.festival => 'Festival',
        AiPlannerEventType.babyShower => 'Baby shower',
        AiPlannerEventType.anniversary => 'Anniversary',
      };

  static AiPlannerEventType fromCategory(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('wedd')) return AiPlannerEventType.wedding;
    if (lower.contains('birth') || lower.contains('owanbe')) return AiPlannerEventType.birthday;
    if (lower.contains('corp') || lower.contains('gala')) return AiPlannerEventType.corporate;
    if (lower.contains('fest')) return AiPlannerEventType.festival;
    if (lower.contains('baby')) return AiPlannerEventType.babyShower;
    if (lower.contains('anniv')) return AiPlannerEventType.anniversary;
    return AiPlannerEventType.birthday;
  }
}

class AiPlannerInputs {
  const AiPlannerInputs({
    required this.eventType,
    required this.budgetMinor,
    required this.guestCount,
    required this.location,
  });

  final AiPlannerEventType eventType;
  final int budgetMinor;
  final int guestCount;
  final String location;

  AiPlannerInputs copyWith({
    AiPlannerEventType? eventType,
    int? budgetMinor,
    int? guestCount,
    String? location,
  }) {
    return AiPlannerInputs(
      eventType: eventType ?? this.eventType,
      budgetMinor: budgetMinor ?? this.budgetMinor,
      guestCount: guestCount ?? this.guestCount,
      location: location ?? this.location,
    );
  }
}

AiPlannerInputs defaultInputsFromEvent(OrganizerEvent event, {int? budgetMinor}) {
  final guests = event.totalCapacity > 0 ? event.totalCapacity : event.attendees.length;
  return AiPlannerInputs(
    eventType: AiPlannerEventTypeX.fromCategory(event.category),
    budgetMinor: budgetMinor ?? _defaultBudgetMinor(guests, event.category),
    guestCount: guests > 0 ? guests : 150,
    location: event.city.trim().isNotEmpty ? event.city : event.venue,
  );
}

int _defaultBudgetMinor(int guests, String category) {
  final perGuest = switch (AiPlannerEventTypeX.fromCategory(category)) {
    AiPlannerEventType.wedding => 120000,
    AiPlannerEventType.corporate => 85000,
    AiPlannerEventType.festival => 45000,
    _ => 75000,
  };
  return (guests * perGuest).clamp(50000000, 5000000000);
}

Map<BudgetCategory, double> _weightsForEventType(AiPlannerEventType type) {
  return switch (type) {
    AiPlannerEventType.wedding => const {
        BudgetCategory.hall: 0.28,
        BudgetCategory.catering: 0.26,
        BudgetCategory.photography: 0.18,
        BudgetCategory.decoration: 0.16,
        BudgetCategory.dj: 0.12,
      },
    AiPlannerEventType.corporate => const {
        BudgetCategory.hall: 0.22,
        BudgetCategory.catering: 0.32,
        BudgetCategory.dj: 0.18,
        BudgetCategory.photography: 0.14,
        BudgetCategory.decoration: 0.14,
      },
    AiPlannerEventType.festival => const {
        BudgetCategory.hall: 0.20,
        BudgetCategory.dj: 0.25,
        BudgetCategory.catering: 0.22,
        BudgetCategory.decoration: 0.18,
        BudgetCategory.photography: 0.15,
      },
    AiPlannerEventType.babyShower => const {
        BudgetCategory.catering: 0.30,
        BudgetCategory.decoration: 0.28,
        BudgetCategory.photography: 0.18,
        BudgetCategory.hall: 0.14,
        BudgetCategory.dj: 0.10,
      },
    AiPlannerEventType.anniversary => const {
        BudgetCategory.hall: 0.24,
        BudgetCategory.catering: 0.28,
        BudgetCategory.photography: 0.18,
        BudgetCategory.decoration: 0.18,
        BudgetCategory.dj: 0.12,
      },
    AiPlannerEventType.birthday => budgetCategoryWeights,
  };
}

class PlannerRecommendedVendor {
  const PlannerRecommendedVendor({
    required this.vendor,
    required this.matchScore,
    required this.reason,
    required this.coverColorStart,
    required this.coverColorEnd,
  });

  final MarketplaceVendor vendor;
  final int matchScore;
  final String reason;
  final int coverColorStart;
  final int coverColorEnd;
}

class PlannerBudgetSlice {
  const PlannerBudgetSlice({
    required this.category,
    required this.amountMinor,
    required this.percent,
    required this.colorArgb,
  });

  final BudgetCategory category;
  final int amountMinor;
  final double percent;
  final int colorArgb;
}

class PlannerChecklistItem {
  const PlannerChecklistItem({
    required this.label,
    required this.done,
    required this.priority,
  });

  final String label;
  final bool done;
  final int priority;
}

enum PlannerTimelineStatus { upcoming, dueSoon, overdue, complete }

class PlannerTimelineItem {
  const PlannerTimelineItem({
    required this.label,
    required this.dueAt,
    required this.status,
    required this.weeksBefore,
  });

  final String label;
  final DateTime dueAt;
  final PlannerTimelineStatus status;
  final int weeksBefore;
}

enum PlannerRequirementSeverity { critical, important, suggestion }

class PlannerMissingRequirement {
  const PlannerMissingRequirement({
    required this.title,
    required this.description,
    required this.severity,
    this.actionRoute,
  });

  final String title;
  final String description;
  final PlannerRequirementSeverity severity;
  final String? actionRoute;
}

class PlannerRentalRecommendation {
  const PlannerRentalRecommendation({
    required this.categorySlug,
    required this.categoryLabel,
    required this.suggestedQuantity,
    required this.rationale,
  });

  final String categorySlug;
  final String categoryLabel;
  final int suggestedQuantity;
  final String rationale;
}

class AiPlannerPlan {
  const AiPlannerPlan({
    required this.summary,
    required this.recommendedVendors,
    required this.rentalRecommendations,
    required this.budgetSlices,
    required this.checklist,
    required this.timeline,
    required this.missingRequirements,
    required this.readinessScore,
  });

  final String summary;
  final List<PlannerRecommendedVendor> recommendedVendors;
  final List<PlannerRentalRecommendation> rentalRecommendations;
  final List<PlannerBudgetSlice> budgetSlices;
  final List<PlannerChecklistItem> checklist;
  final List<PlannerTimelineItem> timeline;
  final List<PlannerMissingRequirement> missingRequirements;
  final int readinessScore;
}

const _sliceColors = <BudgetCategory, int>{
  BudgetCategory.hall: 0xFF7B4FA3,
  BudgetCategory.catering: 0xFFD4A853,
  BudgetCategory.dj: 0xFF0D9488,
  BudgetCategory.decoration: 0xFFF472B6,
  BudgetCategory.photography: 0xFF60A5FA,
};

AiPlannerPlan buildAiPlannerPlan({
  required AiPlannerInputs inputs,
  required OrganizerEvent event,
  required List<MarketplaceVendor> vendors,
}) {
  final enriched = enrichCatalog(vendors);
  final weights = _weightsForEventType(inputs.eventType);
  final budget = inputs.budgetMinor > 0 ? inputs.budgetMinor : _defaultBudgetMinor(inputs.guestCount, inputs.eventType.label);

  final slices = <PlannerBudgetSlice>[];
  for (final entry in weights.entries) {
    final amount = (budget * entry.value).round();
    slices.add(
      PlannerBudgetSlice(
        category: entry.key,
        amountMinor: amount,
        percent: entry.value,
        colorArgb: _sliceColors[entry.key] ?? 0xFF9CA3AF,
      ),
    );
  }

  final recommended = _pickRecommendedVendors(
    vendors: enriched,
    eventType: inputs.eventType,
    location: inputs.location,
    budgetMinor: budget,
  );

  final checklist = _buildChecklist(inputs, event);
  final timeline = _buildTimeline(event.startsAt);
  final missing = _detectMissingRequirements(inputs, event, budget);
  final rentals = _recommendRentals(inputs, event);
  final doneCount = checklist.where((c) => c.done).length;
  final readiness = checklist.isEmpty ? 0 : ((doneCount / checklist.length) * 100).round();

  final summary = _buildSummary(inputs, event, missing.length, recommended.length);

  return AiPlannerPlan(
    summary: summary,
    recommendedVendors: recommended,
    rentalRecommendations: rentals,
    budgetSlices: slices,
    checklist: checklist,
    timeline: timeline,
    missingRequirements: missing,
    readinessScore: readiness,
  );
}

String _buildSummary(AiPlannerInputs inputs, OrganizerEvent event, int gaps, int vendorCount) {
  final type = inputs.eventType.label.toLowerCase();
  final location = inputs.location.isNotEmpty ? inputs.location : event.city;
  if (gaps == 0) {
    return 'Your $type in $location is on track. We matched $vendorCount celebration partners '
        'and mapped your budget across key categories.';
  }
  return 'Here is a tailored plan for your $type in $location — $vendorCount vendor matches, '
      'a budget split for ${inputs.guestCount} guests, and $gaps items to address next.';
}

List<PlannerRecommendedVendor> _pickRecommendedVendors({
  required List<MarketplaceVendor> vendors,
  required AiPlannerEventType eventType,
  required String location,
  required int budgetMinor,
}) {
  if (vendors.isEmpty) return const [];

  final neededCategories = switch (eventType) {
    AiPlannerEventType.wedding => ['Catering', 'Photography', 'Décor', 'DJ & Music'],
    AiPlannerEventType.corporate => ['Catering', 'DJ & Music', 'Photography'],
    AiPlannerEventType.festival => ['DJ & Music', 'Catering', 'Décor'],
    AiPlannerEventType.babyShower => ['Catering', 'Décor', 'Photography'],
    _ => ['Catering', 'DJ & Music', 'Décor', 'Photography'],
  };

  final loc = location.toLowerCase();
  final results = <PlannerRecommendedVendor>[];

  for (final cat in neededCategories) {
    MarketplaceVendor? best;
    var bestScore = -1.0;

    for (final v in vendors) {
      if (v.categoryLabel != cat && !v.categoryLabel.toLowerCase().contains(cat.toLowerCase().split(' ').first)) {
        continue;
      }
      final rating = v.ratingAverage ?? 4.5;
      final cityMatch = (v.city ?? '').toLowerCase().contains(loc) || loc.contains((v.city ?? '').toLowerCase());
      final price = v.priceFromMinor ?? 0;
      final priceFit = price == 0 || price <= budgetMinor * 0.4 ? 1.0 : 0.5;
      final score = rating * 0.45 + (cityMatch ? 0.35 : 0.1) + priceFit * 0.2;
      if (score > bestScore) {
        bestScore = score;
        best = v;
      }
    }

    if (best != null) {
      final profile = buildVendorProfile(best);
      final match = (bestScore * 100).round().clamp(72, 98);
      results.add(
        PlannerRecommendedVendor(
          vendor: profile.vendor,
          matchScore: match,
          reason: _vendorReason(best, eventType, cityMatch: (best.city ?? '').toLowerCase().contains(loc)),
          coverColorStart: profile.coverColorStart,
          coverColorEnd: profile.coverColorEnd,
        ),
      );
    }
  }

  if (results.length < 4) {
    for (final v in vendors) {
      if (results.any((r) => r.vendor.id == v.id)) continue;
      final profile = buildVendorProfile(v);
      results.add(
        PlannerRecommendedVendor(
          vendor: profile.vendor,
          matchScore: 75 + v.id.hashCode.abs() % 15,
          reason: 'Highly rated ${v.categoryLabel.toLowerCase()} for celebrations like yours.',
          coverColorStart: profile.coverColorStart,
          coverColorEnd: profile.coverColorEnd,
        ),
      );
      if (results.length >= 5) break;
    }
  }

  results.sort((a, b) => b.matchScore.compareTo(a.matchScore));
  return results.take(5).toList();
}

String _vendorReason(MarketplaceVendor vendor, AiPlannerEventType type, {required bool cityMatch}) {
  final locality = cityMatch ? 'in your area' : 'with strong reviews';
  return 'Top ${vendor.categoryLabel.toLowerCase()} pick $locality for ${type.label.toLowerCase()} events.';
}

List<PlannerChecklistItem> _buildChecklist(AiPlannerInputs inputs, OrganizerEvent event) {
  final hasVenue = event.venue.trim().isNotEmpty;
  final hasGuests = event.attendees.isNotEmpty;
  final hasTickets = event.ticketTiers.isNotEmpty;
  final published = event.status == OrganizerEventStatus.published ||
      event.status == OrganizerEventStatus.live;

  final base = <PlannerChecklistItem>[
    PlannerChecklistItem(label: 'Confirm venue & date', done: hasVenue, priority: 1),
    PlannerChecklistItem(label: 'Set celebration budget', done: inputs.budgetMinor > 0, priority: 2),
    PlannerChecklistItem(label: 'Build guest list (${inputs.guestCount} target)', done: hasGuests, priority: 3),
    PlannerChecklistItem(label: 'Book catering partner', done: _hasCategoryBooked(event, 'cater'), priority: 4),
    PlannerChecklistItem(label: 'Secure DJ / entertainment', done: _hasCategoryBooked(event, 'dj'), priority: 5),
    PlannerChecklistItem(label: 'Arrange photography', done: _hasCategoryBooked(event, 'photo'), priority: 6),
    PlannerChecklistItem(label: 'Plan décor & styling', done: _hasCategoryBooked(event, 'decor'), priority: 7),
    PlannerChecklistItem(label: 'Send invitations', done: hasGuests, priority: 8),
    PlannerChecklistItem(label: 'Configure tickets / RSVP', done: hasTickets, priority: 9),
    PlannerChecklistItem(label: 'Publish celebration page', done: published, priority: 10),
  ];

  if (inputs.eventType == AiPlannerEventType.wedding) {
    base.insert(4, const PlannerChecklistItem(label: 'Book officiant / MC', done: false, priority: 4));
  }

  base.sort((a, b) => a.priority.compareTo(b.priority));
  return base;
}

bool _hasCategoryBooked(OrganizerEvent event, String needle) {
  return event.vendors.any(
    (v) =>
        v.status == VendorSlotStatus.approved &&
        (v.category.toLowerCase().contains(needle) || v.businessName.toLowerCase().contains(needle)),
  );
}

List<PlannerTimelineItem> _buildTimeline(DateTime eventDate) {
  final now = DateTime.now();
  final milestones = <(int weeks, String label)>[
    (12, 'Book venue & set date'),
    (10, 'Confirm catering & menu tasting'),
    (8, 'Lock in DJ, photo & décor'),
    (6, 'Send invitations to guests'),
    (4, 'Finalize headcount & seating'),
    (2, 'Run-through & vendor confirmations'),
    (0, 'Celebration day'),
  ];

  return milestones.map((m) {
    final due = eventDate.subtract(Duration(days: m.$1 * 7));
    final status = _timelineStatus(due, now, m.$1 == 0);
    return PlannerTimelineItem(
      label: m.$2,
      dueAt: due,
      status: status,
      weeksBefore: m.$1,
    );
  }).toList();
}

PlannerTimelineStatus _timelineStatus(DateTime due, DateTime now, bool isEventDay) {
  if (isEventDay) {
    return now.isAfter(due.subtract(const Duration(hours: 12))) ? PlannerTimelineStatus.dueSoon : PlannerTimelineStatus.upcoming;
  }
  if (now.isAfter(due.add(const Duration(days: 1)))) return PlannerTimelineStatus.overdue;
  if (now.isAfter(due.subtract(const Duration(days: 3)))) return PlannerTimelineStatus.dueSoon;
  if (now.isAfter(due)) return PlannerTimelineStatus.complete;
  return PlannerTimelineStatus.upcoming;
}

List<PlannerMissingRequirement> _detectMissingRequirements(
  AiPlannerInputs inputs,
  OrganizerEvent event,
  int budgetMinor,
) {
  final items = <PlannerMissingRequirement>[];

  if (inputs.location.trim().isEmpty) {
    items.add(
      const PlannerMissingRequirement(
        title: 'Location not set',
        description: 'Add a city or venue so we can match local vendors.',
        severity: PlannerRequirementSeverity.critical,
      ),
    );
  }

  if (inputs.guestCount <= 0) {
    items.add(
      const PlannerMissingRequirement(
        title: 'Guest count missing',
        description: 'Estimate how many guests you expect for accurate catering and budget.',
        severity: PlannerRequirementSeverity.critical,
      ),
    );
  }

  final perGuest = inputs.guestCount > 0 ? budgetMinor / inputs.guestCount : 0;
  if (perGuest > 0 && perGuest < 40000) {
    items.add(
      const PlannerMissingRequirement(
        title: 'Budget may be tight',
        description: 'Your per-guest budget is below typical celebration costs. Consider adjusting.',
        severity: PlannerRequirementSeverity.important,
      ),
    );
  }

  if (event.vendors.where((v) => v.status == VendorSlotStatus.approved).isEmpty) {
    items.add(
      const PlannerMissingRequirement(
        title: 'No vendors confirmed',
        description: 'Browse the marketplace and request quotes from recommended partners.',
        severity: PlannerRequirementSeverity.important,
        actionRoute: 'vendors',
      ),
    );
  }

  if (event.attendees.isEmpty) {
    items.add(
      const PlannerMissingRequirement(
        title: 'Guest list empty',
        description: 'Add guests so you can send invitations and track RSVPs.',
        severity: PlannerRequirementSeverity.important,
        actionRoute: 'guests',
      ),
    );
  }

  if (event.status == OrganizerEventStatus.draft) {
    items.add(
      const PlannerMissingRequirement(
        title: 'Event not published',
        description: 'Publish your celebration page when you are ready to share with guests.',
        severity: PlannerRequirementSeverity.suggestion,
      ),
    );
  }

  final daysUntil = event.startsAt.difference(DateTime.now()).inDays;
  if (daysUntil > 0 && daysUntil < 21) {
    items.add(
      PlannerMissingRequirement(
        title: 'Short planning window',
        description: 'Only $daysUntil days until your event — prioritize vendor bookings now.',
        severity: PlannerRequirementSeverity.critical,
      ),
    );
  }

  return items;
}

List<PlannerRentalRecommendation> _recommendRentals(AiPlannerInputs inputs, OrganizerEvent event) {
  final guests = inputs.guestCount > 0 ? inputs.guestCount : 150;
  final venue = '${event.venue} ${event.city} ${inputs.location}'.toLowerCase();
  final outdoor = venue.contains('outdoor') || venue.contains('garden') || venue.contains('beach');
  final tables = (guests / 8).ceil();
  final chairs = guests;
  final toilets = (guests / 75).ceil().clamp(2, 20);
  final canopies = outdoor ? (guests / 50).ceil().clamp(1, 12) : 0;

  final base = <PlannerRentalRecommendation>[
    PlannerRentalRecommendation(
      categorySlug: 'chairs',
      categoryLabel: 'Chairs',
      suggestedQuantity: chairs,
      rationale: 'Seat every guest comfortably ($guests attendees).',
    ),
    PlannerRentalRecommendation(
      categorySlug: 'tables',
      categoryLabel: 'Tables',
      suggestedQuantity: tables,
      rationale: 'Approx. 8 guests per table for dining and reception.',
    ),
    PlannerRentalRecommendation(
      categorySlug: 'sound-systems',
      categoryLabel: 'Sound Systems',
      suggestedQuantity: 1,
      rationale: 'PA for announcements, music, and MC at $guests-guest scale.',
    ),
    PlannerRentalRecommendation(
      categorySlug: 'lighting-systems',
      categoryLabel: 'Lighting Systems',
      suggestedQuantity: outdoor ? 2 : 1,
      rationale: outdoor ? 'Outdoor events need accent and safety lighting.' : 'Hall uplighting for atmosphere.',
    ),
  ];

  if (outdoor) {
    base.addAll([
      PlannerRentalRecommendation(
        categorySlug: 'canopies',
        categoryLabel: 'Canopies',
        suggestedQuantity: canopies,
        rationale: 'Shade and rain cover for outdoor celebration space.',
      ),
      PlannerRentalRecommendation(
        categorySlug: 'generators',
        categoryLabel: 'Generators',
        suggestedQuantity: 1,
        rationale: 'Backup power for sound, lighting, and catering outdoors.',
      ),
      PlannerRentalRecommendation(
        categorySlug: 'mobile-toilets',
        categoryLabel: 'Mobile Toilets',
        suggestedQuantity: toilets,
        rationale: 'Sanitation capacity for large outdoor guest count.',
      ),
    ]);
  }

  if (inputs.eventType == AiPlannerEventType.wedding) {
    base.add(
      const PlannerRentalRecommendation(
        categorySlug: 'thrones-vip-seating',
        categoryLabel: 'Thrones & VIP Seating',
        suggestedQuantity: 2,
        rationale: 'Reserved seating for the couple and parents.',
      ),
    );
  }

  if (guests >= 200) {
    base.add(
      PlannerRentalRecommendation(
        categorySlug: 'dance-floors',
        categoryLabel: 'Dance Floors',
        suggestedQuantity: 1,
        rationale: 'Dedicated dance floor for large owambe crowd.',
      ),
    );
  }

  return base;
}
