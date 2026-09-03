import '../../../core/api/event_config_api.dart';

/// Display group for Super Admin taxonomy categories (presentation only).
class VendorCategoryGroup {
  const VendorCategoryGroup({required this.title, required this.categories});

  final String title;
  final List<VendorCategoryConfig> categories;
}

/// Ordered slug membership for service category UX groups.
const serviceCategoryGroupSlugs = <String, List<String>>{
  'Entertainment': ['dj', 'mc', 'live-band', 'av-production'],
  'Food & Hospitality': ['catering', 'cake', 'drinks', 'ushers'],
  'Fashion': [
    'fashion-attire',
    'aso-ebi',
    'traditional-wear',
    'wedding-gowns',
    'bridesmaid-dresses',
    'suits',
    'gele',
    'fashion-accessories',
    'tailoring',
  ],
  'Event Professionals': ['photographer', 'decorator', 'venue', 'security', 'florist'],
};

/// Ordered slug membership for rental category UX groups.
const rentalCategoryGroupSlugs = <String, List<String>>{
  'Furniture': ['chairs', 'tables', 'thrones-vip-seating'],
  'Structures': ['canopies', 'tents', 'stage-platforms', 'backdrops'],
  'Technical Equipment': [
    'led-screens',
    'sound-systems',
    'lighting-systems',
    'generators',
    'cooling-fans',
    'air-conditioners',
  ],
  'Event Accessories': [
    'cutlery-crockery',
    'photo-booths',
    'event-equipment',
    'rentals-equipment',
    'mobile-toilets',
    'dance-floors',
  ],
};

/// Groups [categories] using [groupSlugs]. Unknown slugs land in "Other".
List<VendorCategoryGroup> groupVendorCategories(
  List<VendorCategoryConfig> categories, {
  required Map<String, List<String>> groupSlugs,
}) {
  final bySlug = <String, VendorCategoryConfig>{
    for (final c in categories) c.slug.toLowerCase(): c,
  };
  final used = <String>{};
  final groups = <VendorCategoryGroup>[];

  for (final entry in groupSlugs.entries) {
    final items = <VendorCategoryConfig>[];
    for (final slug in entry.value) {
      final cat = bySlug[slug.toLowerCase()];
      if (cat == null) continue;
      items.add(cat);
      used.add(cat.id);
    }
    if (items.isNotEmpty) {
      groups.add(VendorCategoryGroup(title: entry.key, categories: items));
    }
  }

  final other = [
    for (final c in categories)
      if (!used.contains(c.id)) c,
  ];
  if (other.isNotEmpty) {
    groups.add(VendorCategoryGroup(title: 'Other', categories: other));
  }
  return groups;
}

List<VendorCategoryGroup> groupServiceCategories(List<VendorCategoryConfig> categories) =>
    groupVendorCategories(categories, groupSlugs: serviceCategoryGroupSlugs);

List<VendorCategoryGroup> groupRentalCategories(List<VendorCategoryConfig> categories) =>
    groupVendorCategories(categories, groupSlugs: rentalCategoryGroupSlugs);
