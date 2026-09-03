import '../../../core/api/event_config_api.dart';

/// Confidence tier for legacy label → canonical taxonomy mapping.
enum LegacyMappingConfidence { high, ambiguous, none }

class LegacyMappingSuggestion {
  const LegacyMappingSuggestion({
    required this.legacyLabel,
    required this.confidence,
    this.suggestedCategory,
    this.alternateCategories = const [],
  });

  final String legacyLabel;
  final LegacyMappingConfidence confidence;
  final VendorCategoryConfig? suggestedCategory;
  final List<VendorCategoryConfig> alternateCategories;
}

/// Labels that must never be auto-applied — vendor must choose explicitly.
const ambiguousLegacyLabels = <String>{
  'rentals',
  'rentals & equipment',
  'entertainment',
  'videography',
  'equipment rental',
  'wedding buffet',
};

/// High-confidence normalized legacy token → taxonomy slug (verified against Phase 1 seeds).
const highConfidenceLegacySlugAliases = <String, String>{
  'dj': 'dj',
  'catering': 'catering',
  'photography': 'photographer',
  'photographer': 'photographer',
  'decorator': 'decorator',
  'decoration': 'decorator',
  'security': 'security',
  'cake': 'cake',
  'drinks': 'drinks',
  'ushers': 'ushers',
  'live band': 'live-band',
  'live-band': 'live-band',
  'florist': 'florist',
  'floristery': 'florist',
  'mc': 'mc',
  'venue': 'venue',
  'fashion & attire': 'fashion-attire',
  'fashion-attire': 'fashion-attire',
  'aso-ebi': 'aso-ebi',
  'aso ebi': 'aso-ebi',
  'logistics': 'av-production',
};

String normalizeLegacyLabel(String raw) =>
    raw.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

String normalizeLegacyToken(String raw) =>
    raw.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'_+'), '_');

/// Collect distinct legacy labels from profile fields (does not mutate source data).
Set<String> collectLegacyLabels({
  required String categoryCsv,
  required Iterable<String> servicesOffered,
  String? subcategory,
}) {
  final labels = <String>{};
  for (final part in categoryCsv.split(',')) {
    final t = part.trim();
    if (t.isNotEmpty) labels.add(t);
  }
  for (final s in servicesOffered) {
    final t = s.trim();
    if (t.isNotEmpty) labels.add(t);
  }
  final sub = subcategory?.trim();
  if (sub != null && sub.isNotEmpty) labels.add(sub);
  return labels;
}

VendorCategoryConfig? _findBySlug(List<VendorCategoryConfig> taxonomy, String slug) {
  final needle = slug.toLowerCase();
  for (final c in taxonomy) {
    if (c.slug.toLowerCase() == needle) return c;
  }
  return null;
}

VendorCategoryConfig? _findByLabel(List<VendorCategoryConfig> taxonomy, String label) {
  final needle = normalizeLegacyLabel(label);
  VendorCategoryConfig? partial;
  for (final c in taxonomy) {
    final catLabel = normalizeLegacyLabel(c.label);
    if (catLabel == needle) return c;
    if (catLabel.contains(needle) || needle.contains(catLabel)) {
      partial ??= c;
    }
  }
  return partial;
}

List<VendorCategoryConfig> _findAllMatches(List<VendorCategoryConfig> taxonomy, String legacyLabel) {
  final normalized = normalizeLegacyLabel(legacyLabel);
  final token = normalizeLegacyToken(legacyLabel);
  final matches = <VendorCategoryConfig>[];
  for (final c in taxonomy) {
    if (normalizeLegacyLabel(c.label) == normalized) {
      matches.add(c);
      continue;
    }
    if (c.slug.toLowerCase() == token || normalizeLegacyToken(c.slug) == token) {
      matches.add(c);
    }
  }
  return matches;
}

/// Suggest canonical taxonomy mappings for legacy labels against live Super Admin taxonomy.
List<LegacyMappingSuggestion> suggestLegacyMappings({
  required Iterable<String> legacyLabels,
  required List<VendorCategoryConfig> serviceCategories,
  required List<VendorCategoryConfig> rentalCategories,
  required Set<String> alreadySelectedCategoryIds,
}) {
  final taxonomy = [...serviceCategories, ...rentalCategories];
  final suggestions = <LegacyMappingSuggestion>[];

  for (final raw in legacyLabels) {
    final label = raw.trim();
    if (label.isEmpty) continue;

    final normalized = normalizeLegacyLabel(label);
    if (ambiguousLegacyLabels.contains(normalized)) {
      suggestions.add(LegacyMappingSuggestion(
        legacyLabel: label,
        confidence: LegacyMappingConfidence.ambiguous,
      ));
      continue;
    }

    // Typo-prone labels (e.g. PHOTPGRAPHY) — suggest only, never auto-apply.
    if (_isLikelyTypo(normalized)) {
      final fuzzy = _fuzzyPhotographyMatch(serviceCategories);
      suggestions.add(LegacyMappingSuggestion(
        legacyLabel: label,
        confidence: LegacyMappingConfidence.ambiguous,
        suggestedCategory: fuzzy,
      ));
      continue;
    }

    final aliasSlug = highConfidenceLegacySlugAliases[normalized] ??
        highConfidenceLegacySlugAliases[normalizeLegacyToken(label)];
    if (aliasSlug != null) {
      final cat = _findBySlug(taxonomy, aliasSlug);
      if (cat != null) {
        if (!alreadySelectedCategoryIds.contains(cat.id)) {
          suggestions.add(LegacyMappingSuggestion(
            legacyLabel: label,
            confidence: LegacyMappingConfidence.high,
            suggestedCategory: cat,
          ));
        }
        continue;
      }
    }

    final allMatches = _findAllMatches(taxonomy, label);
    if (allMatches.length == 1) {
      final cat = allMatches.first;
      if (!alreadySelectedCategoryIds.contains(cat.id)) {
        suggestions.add(LegacyMappingSuggestion(
          legacyLabel: label,
          confidence: LegacyMappingConfidence.high,
          suggestedCategory: cat,
        ));
      }
      continue;
    } else if (allMatches.length > 1) {
      suggestions.add(LegacyMappingSuggestion(
        legacyLabel: label,
        confidence: LegacyMappingConfidence.ambiguous,
        alternateCategories: allMatches,
      ));
      continue;
    }

    final byLabel = _findByLabel(taxonomy, label);
    if (byLabel != null) {
      if (!alreadySelectedCategoryIds.contains(byLabel.id)) {
        suggestions.add(LegacyMappingSuggestion(
          legacyLabel: label,
          confidence: LegacyMappingConfidence.high,
          suggestedCategory: byLabel,
        ));
      }
      continue;
    }

    suggestions.add(LegacyMappingSuggestion(
      legacyLabel: label,
      confidence: LegacyMappingConfidence.none,
    ));
  }

  return suggestions;
}

bool _isLikelyTypo(String normalized) {
  if (normalized.contains('phot') && !normalized.contains('photographer') && normalized != 'photography') {
    return true;
  }
  return false;
}

VendorCategoryConfig? _fuzzyPhotographyMatch(List<VendorCategoryConfig> serviceCategories) {
  return _findBySlug(serviceCategories, 'photographer');
}

/// After confirming a high-confidence suggestion, ensure the matching capability is enabled.
String? capabilityForCategory(VendorCategoryConfig category) {
  switch (category.offeringKind.toLowerCase()) {
    case 'service':
      return 'SERVICE_PROVIDER';
    case 'rental':
      return 'RENTAL_PROVIDER';
    default:
      return null;
  }
}
