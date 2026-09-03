import 'package:flutter_test/flutter_test.dart';
import 'package:owambe/portals/customer/models/rentals_models.dart';

void main() {
  test('parses rental package components from marketplace catalog JSON', () {
    final item = RentalCatalogItem.fromJson({
      'id': 'p1',
      'vendorId': 'v1',
      'vendorName': 'SoundPro',
      'categorySlug': 'dj-equipment',
      'name': 'Wedding DJ Equipment Set',
      'description': 'Package',
      'totalQuantity': 1,
      'availableQuantity': 1,
      'reservedQuantity': 0,
      'rentalFeeMinor': 5000000,
      'depositMinor': 1000000,
      'active': true,
      'isPackage': true,
      'components': [
        {'resourceId': 'r1', 'quantity': 2, 'slug': 'speaker', 'label': 'Speaker'},
      ],
    });
    expect(item.isPackage, isTrue);
    expect(item.components.single.quantity, 2);
    expect(item.vendorName, 'SoundPro');
  });
}
