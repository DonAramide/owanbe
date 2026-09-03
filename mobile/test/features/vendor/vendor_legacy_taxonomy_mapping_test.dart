import 'package:flutter_test/flutter_test.dart';
import 'package:owambe/core/api/event_config_api.dart';
import 'package:owambe/features/vendor/models/vendor_legacy_taxonomy_mapping.dart';

VendorCategoryConfig _cat({
  required String id,
  required String slug,
  required String label,
  String offeringKind = 'service',
}) {
  return VendorCategoryConfig(
    id: id,
    slug: slug,
    label: label,
    offeringKind: offeringKind,
  );
}

void main() {
  final serviceCats = [
    _cat(id: '1', slug: 'dj', label: 'DJ'),
    _cat(id: '2', slug: 'catering', label: 'Catering'),
    _cat(id: '3', slug: 'photographer', label: 'Photographer'),
  ];
  final rentalCats = [
    _cat(id: 'r1', slug: 'chairs', label: 'Chairs', offeringKind: 'rental'),
    _cat(id: 'r2', slug: 'rentals-equipment', label: 'Rentals & Event Equipment', offeringKind: 'rental'),
  ];

  group('collectLegacyLabels', () {
    test('merges category CSV and services_offered without duplicates', () {
      final labels = collectLegacyLabels(
        categoryCsv: 'Catering, Photography, DJ',
        servicesOffered: const ['DJ', 'CATERING'],
      );
      expect(labels, containsAll(['Catering', 'Photography', 'DJ', 'CATERING']));
    });
  });

  group('suggestLegacyMappings high confidence', () {
    test('maps DJ to service/dj', () {
      final suggestions = suggestLegacyMappings(
        legacyLabels: const ['DJ'],
        serviceCategories: serviceCats,
        rentalCategories: rentalCats,
        alreadySelectedCategoryIds: const {},
      );
      expect(suggestions.single.confidence, LegacyMappingConfidence.high);
      expect(suggestions.single.suggestedCategory?.slug, 'dj');
    });

    test('maps CATERING to service/catering', () {
      final suggestions = suggestLegacyMappings(
        legacyLabels: const ['CATERING'],
        serviceCategories: serviceCats,
        rentalCategories: rentalCats,
        alreadySelectedCategoryIds: const {},
      );
      expect(suggestions.single.suggestedCategory?.slug, 'catering');
    });

    test('maps PHOTOGRAPHY to service/photographer', () {
      final suggestions = suggestLegacyMappings(
        legacyLabels: const ['PHOTOGRAPHY'],
        serviceCategories: serviceCats,
        rentalCategories: rentalCats,
        alreadySelectedCategoryIds: const {},
      );
      expect(suggestions.single.suggestedCategory?.slug, 'photographer');
    });

    test('does not suggest already selected categories', () {
      final suggestions = suggestLegacyMappings(
        legacyLabels: const ['DJ'],
        serviceCategories: serviceCats,
        rentalCategories: rentalCats,
        alreadySelectedCategoryIds: const {'1'},
      );
      expect(suggestions, isEmpty);
    });
  });

  group('suggestLegacyMappings ambiguous', () {
    test('Rentals is ambiguous — no auto high-confidence mapping', () {
      final suggestions = suggestLegacyMappings(
        legacyLabels: const ['Rentals'],
        serviceCategories: serviceCats,
        rentalCategories: rentalCats,
        alreadySelectedCategoryIds: const {},
      );
      expect(suggestions.single.confidence, LegacyMappingConfidence.ambiguous);
      expect(suggestions.single.suggestedCategory, isNull);
    });

    test('PHOTPGRAPHY typo is ambiguous with optional suggestion', () {
      final suggestions = suggestLegacyMappings(
        legacyLabels: const ['PHOTPGRAPHY'],
        serviceCategories: serviceCats,
        rentalCategories: rentalCats,
        alreadySelectedCategoryIds: const {},
      );
      expect(suggestions.single.confidence, LegacyMappingConfidence.ambiguous);
      expect(suggestions.single.suggestedCategory?.slug, 'photographer');
    });

    test('Entertainment is ambiguous', () {
      final suggestions = suggestLegacyMappings(
        legacyLabels: const ['Entertainment'],
        serviceCategories: serviceCats,
        rentalCategories: rentalCats,
        alreadySelectedCategoryIds: const {},
      );
      expect(suggestions.single.confidence, LegacyMappingConfidence.ambiguous);
    });

    test('Videography is ambiguous', () {
      final suggestions = suggestLegacyMappings(
        legacyLabels: const ['Videography'],
        serviceCategories: serviceCats,
        rentalCategories: rentalCats,
        alreadySelectedCategoryIds: const {},
      );
      expect(suggestions.single.confidence, LegacyMappingConfidence.ambiguous);
    });
  });

  group('capabilityForCategory', () {
    test('returns SERVICE_PROVIDER for service kind', () {
      expect(capabilityForCategory(serviceCats.first), 'SERVICE_PROVIDER');
    });

    test('returns RENTAL_PROVIDER for rental kind', () {
      expect(capabilityForCategory(rentalCats.first), 'RENTAL_PROVIDER');
    });
  });

  group('no artificial limit', () {
    test('many legacy labels all produce suggestions without truncation', () {
      final many = List.generate(10, (i) => 'Service Label $i');
      final extraCats = [
        for (var i = 0; i < 10; i++)
          _cat(id: 'x$i', slug: 'svc-$i', label: 'Service Label $i'),
      ];
      final suggestions = suggestLegacyMappings(
        legacyLabels: many,
        serviceCategories: extraCats,
        rentalCategories: rentalCats,
        alreadySelectedCategoryIds: const {},
      );
      expect(suggestions.length, 10);
    });
  });
}
