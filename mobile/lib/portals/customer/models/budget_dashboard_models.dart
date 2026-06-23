import '../../../features/organizer/finance/organizer_finance_api.dart';
import '../../../features/organizer/models/organizer_models.dart';
import '../models/command_center_models.dart';

enum BudgetHealth { healthy, warning, overBudget }

enum BudgetCategory {
  hall,
  catering,
  dj,
  decoration,
  photography,
}

extension BudgetCategoryX on BudgetCategory {
  String get label => switch (this) {
        BudgetCategory.hall => 'Hall',
        BudgetCategory.catering => 'Catering',
        BudgetCategory.dj => 'DJ',
        BudgetCategory.decoration => 'Decoration',
        BudgetCategory.photography => 'Photography',
      };
}

const budgetCategoryWeights = <BudgetCategory, double>{
  BudgetCategory.hall: 0.35,
  BudgetCategory.catering: 0.25,
  BudgetCategory.dj: 0.10,
  BudgetCategory.decoration: 0.15,
  BudgetCategory.photography: 0.15,
};

BudgetCategory mapVendorCategory(String raw) {
  final lower = raw.toLowerCase();
  if (lower.contains('hall') || lower.contains('venue')) return BudgetCategory.hall;
  if (lower.contains('cater') || lower.contains('food') || lower.contains('jollof')) {
    return BudgetCategory.catering;
  }
  if (lower.contains('dj') ||
      lower.contains('music') ||
      lower.contains('production') ||
      lower.contains('av') ||
      lower.contains('sound')) {
    return BudgetCategory.dj;
  }
  if (lower.contains('decor')) return BudgetCategory.decoration;
  if (lower.contains('photo') || lower.contains('camera')) return BudgetCategory.photography;
  return BudgetCategory.decoration;
}

BudgetHealth computeBudgetHealth(int committedMinor, int budgetMinor) {
  if (budgetMinor <= 0) return BudgetHealth.healthy;
  final ratio = committedMinor / budgetMinor;
  if (ratio > 1.0) return BudgetHealth.overBudget;
  if (ratio > 0.85) return BudgetHealth.warning;
  return BudgetHealth.healthy;
}

class CategoryAllocation {
  const CategoryAllocation({
    required this.category,
    required this.allocatedMinor,
    required this.committedMinor,
  });

  final BudgetCategory category;
  final int allocatedMinor;
  final int committedMinor;

  double get utilization => allocatedMinor == 0 ? 0 : committedMinor / allocatedMinor;
}

class VendorBudgetAllocation {
  const VendorBudgetAllocation({
    required this.vendorId,
    required this.businessName,
    required this.category,
    required this.status,
    required this.allocatedMinor,
    required this.committedMinor,
  });

  final String vendorId;
  final String businessName;
  final BudgetCategory category;
  final VendorSlotStatus status;
  final int allocatedMinor;
  final int committedMinor;
}

class BudgetPieSlice {
  const BudgetPieSlice({
    required this.category,
    required this.amountMinor,
    required this.colorArgb,
  });

  final BudgetCategory category;
  final int amountMinor;
  final int colorArgb;
}

class BudgetDashboardSnapshot {
  const BudgetDashboardSnapshot({
    required this.event,
    required this.health,
    required this.budgetMinor,
    required this.committedMinor,
    required this.remainingMinor,
    required this.categories,
    required this.vendors,
    required this.pieSlices,
    this.finance,
  });

  final OrganizerEvent event;
  final BudgetHealth health;
  final int budgetMinor;
  final int committedMinor;
  final int remainingMinor;
  final List<CategoryAllocation> categories;
  final List<VendorBudgetAllocation> vendors;
  final List<BudgetPieSlice> pieSlices;
  final OrganizerEventFinanceSummary? finance;
}

const _pieColors = <int>[
  0xFF4B2C6F,
  0xFFD4A853,
  0xFF0D9488,
  0xFF7B4FA3,
  0xFF2563EB,
];

BudgetDashboardSnapshot buildBudgetDashboardSnapshot({
  required OrganizerEvent event,
  OrganizerEventFinanceSummary? finance,
  List<OrganizerFinanceTransaction> transactions = const [],
}) {
  final budgetBase = budgetStats(event, finance);
  final budgetMinor = budgetBase.budgetMinor;

  final categoryCommitted = <BudgetCategory, int>{
    for (final c in BudgetCategory.values) c: 0,
  };

  for (final vendor in event.vendors) {
    final cat = mapVendorCategory(vendor.category);
    categoryCommitted[cat] = (categoryCommitted[cat] ?? 0) + vendor.revenueMinor;
  }

  var committedMinor = categoryCommitted.values.fold<int>(0, (a, b) => a + b);
  if (committedMinor == 0 && finance != null) {
    committedMinor = int.tryParse(finance.grossCollectedMinor) ?? event.revenueMinor;
    _distributeCommitted(categoryCommitted, committedMinor);
  } else if (committedMinor == 0) {
    committedMinor = event.revenueMinor;
    if (committedMinor > 0) _distributeCommitted(categoryCommitted, committedMinor);
  }

  final remainingMinor = budgetMinor - committedMinor;

  final categories = BudgetCategory.values.map((cat) {
    final weight = budgetCategoryWeights[cat] ?? 0;
    return CategoryAllocation(
      category: cat,
      allocatedMinor: (budgetMinor * weight).round(),
      committedMinor: categoryCommitted[cat] ?? 0,
    );
  }).toList();

  final vendorList = event.vendors
      .map((v) {
        final cat = mapVendorCategory(v.category);
        final weight = budgetCategoryWeights[cat] ?? 0.1;
        return VendorBudgetAllocation(
          vendorId: v.id,
          businessName: v.businessName,
          category: cat,
          status: v.status,
          allocatedMinor: (budgetMinor * weight).round(),
          committedMinor: v.revenueMinor,
        );
      })
      .toList();

  if (vendorList.isEmpty && budgetMinor > 0) {
    vendorList.add(
      VendorBudgetAllocation(
        vendorId: 'venue',
        businessName: event.venue,
        category: BudgetCategory.hall,
        status: VendorSlotStatus.approved,
        allocatedMinor: (budgetMinor * 0.35).round(),
        committedMinor: categoryCommitted[BudgetCategory.hall] ?? 0,
      ),
    );
  }

  final pieSlices = <BudgetPieSlice>[];
  for (var i = 0; i < BudgetCategory.values.length; i++) {
    final cat = BudgetCategory.values[i];
    final amount = categoryCommitted[cat] ?? 0;
    if (amount > 0) {
      pieSlices.add(
        BudgetPieSlice(
          category: cat,
          amountMinor: amount,
          colorArgb: _pieColors[i % _pieColors.length],
        ),
      );
    }
  }

  if (pieSlices.isEmpty && budgetMinor > 0) {
    for (var i = 0; i < categories.length; i++) {
      final c = categories[i];
      if (c.allocatedMinor > 0) {
        pieSlices.add(
          BudgetPieSlice(
            category: c.category,
            amountMinor: c.allocatedMinor,
            colorArgb: _pieColors[i % _pieColors.length],
          ),
        );
      }
    }
  }

  return BudgetDashboardSnapshot(
    event: event,
    health: computeBudgetHealth(committedMinor, budgetMinor),
    budgetMinor: budgetMinor,
    committedMinor: committedMinor,
    remainingMinor: remainingMinor,
    categories: categories,
    vendors: vendorList,
    pieSlices: pieSlices,
    finance: finance,
  );
}

void _distributeCommitted(Map<BudgetCategory, int> categoryCommitted, int total) {
  for (final cat in BudgetCategory.values) {
    final weight = budgetCategoryWeights[cat] ?? 0;
    categoryCommitted[cat] = (total * weight).round();
  }
}
