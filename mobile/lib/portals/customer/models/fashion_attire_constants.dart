// Fashion & Attire — marketplace vertical and subcategories.

/// Parent marketplace vertical.
const fashionAttireVertical = 'Fashion & Attire';

/// Subcategories under Fashion & Attire.
const fashionAttireSubcategories = <String>[
  'Aso-Ebi',
  'Traditional Wear',
  'Wedding Gowns',
  'Bridesmaid Dresses',
  'Suits',
  'Gele',
  'Accessories',
  'Tailoring',
];

/// Slug → label for tenant vendor categories.
const fashionAttireCategorySlugs = <String, String>{
  'fashion-attire': fashionAttireVertical,
  'aso-ebi': 'Aso-Ebi',
  'traditional-wear': 'Traditional Wear',
  'wedding-gowns': 'Wedding Gowns',
  'bridesmaid-dresses': 'Bridesmaid Dresses',
  'suits': 'Suits',
  'gele': 'Gele',
  'fashion-accessories': 'Accessories',
  'tailoring': 'Tailoring',
};

/// Icon keys aligned with Material icon names in admin/config.
const fashionAttireCategoryIcons = <String, String>{
  'fashion-attire': 'checkroom',
  'aso-ebi': 'style',
  'traditional-wear': 'dry_cleaning',
  'wedding-gowns': 'favorite_border',
  'bridesmaid-dresses': 'groups',
  'suits': 'business_center',
  'gele': 'face_retouching_natural',
  'fashion-accessories': 'diamond',
  'tailoring': 'content_cut',
};

bool isFashionAttireCategory(String label) {
  final lower = label.toLowerCase();
  if (lower == fashionAttireVertical.toLowerCase()) return true;
  return fashionAttireSubcategories.any((c) => c.toLowerCase() == lower);
}

String? fashionSubcategoryFromSlug(String raw) {
  final lower = raw.toLowerCase();
  if (lower.contains('aso') && lower.contains('ebi')) return 'Aso-Ebi';
  if (lower.contains('aso-ebi') || lower.contains('asoebi')) return 'Aso-Ebi';
  if (lower.contains('traditional')) return 'Traditional Wear';
  if (lower.contains('wedding') && lower.contains('gown')) return 'Wedding Gowns';
  if (lower.contains('bridesmaid')) return 'Bridesmaid Dresses';
  if (lower.contains('suit')) return 'Suits';
  if (lower.contains('gele')) return 'Gele';
  if (lower.contains('accessor')) return 'Accessories';
  if (lower.contains('tailor')) return 'Tailoring';
  if (lower.contains('fabric') || lower.contains('attire') || lower.contains('fashion')) {
    return fashionAttireVertical;
  }
  return null;
}
