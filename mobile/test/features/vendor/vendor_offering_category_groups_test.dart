import 'package:flutter_test/flutter_test.dart';
import 'package:owambe/core/api/event_config_api.dart';
import 'package:owambe/features/vendor/models/vendor_offering_category_groups.dart';

VendorCategoryConfig _c(String slug, String label, {String kind = 'service'}) =>
    VendorCategoryConfig(id: slug, slug: slug, label: label, offeringKind: kind);

void main() {
  group('groupServiceCategories', () {
    test('groups known slugs and preserves Other for unknowns', () {
      final cats = [
        _c('dj', 'DJ'),
        _c('mc', 'MC'),
        _c('catering', 'Catering'),
        _c('photographer', 'Photographer'),
        _c('custom-xyz', 'Custom XYZ'),
      ];
      final groups = groupServiceCategories(cats);
      expect(groups.map((g) => g.title), ['Entertainment', 'Food & Hospitality', 'Event Professionals', 'Other']);
      expect(groups.firstWhere((g) => g.title == 'Entertainment').categories.map((c) => c.slug), ['dj', 'mc']);
      expect(groups.firstWhere((g) => g.title == 'Other').categories.single.slug, 'custom-xyz');
    });

    test('does not invent categories missing from taxonomy', () {
      final groups = groupServiceCategories([_c('dj', 'DJ')]);
      expect(groups.single.title, 'Entertainment');
      expect(groups.single.categories.single.slug, 'dj');
    });
  });

  group('groupRentalCategories', () {
    test('groups furniture and technical equipment', () {
      final cats = [
        _c('chairs', 'Chairs', kind: 'rental'),
        _c('tables', 'Tables', kind: 'rental'),
        _c('sound-systems', 'Sound Systems', kind: 'rental'),
        _c('photo-booths', 'Photo Booths', kind: 'rental'),
      ];
      final groups = groupRentalCategories(cats);
      expect(groups.map((g) => g.title), [
        'Furniture',
        'Technical Equipment',
        'Event Accessories',
      ]);
    });
  });
}
