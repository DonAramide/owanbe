import 'package:flutter_test/flutter_test.dart';
import 'package:owambe/portals/customer/models/marketplace_offering_context.dart';

void main() {
  test('organizer has no current vendor — never seller', () {
    expect(
      isMarketplaceOwnOffering(offeringVendorId: 'v-a', currentVendorId: null),
      isFalse,
    );
    expect(
      isMarketplaceOwnOffering(offeringVendorId: 'v-a', currentVendorId: ''),
      isFalse,
    );
  });

  test('vendor is seller only for own offering id', () {
    expect(
      isMarketplaceOwnOffering(offeringVendorId: 'v-a', currentVendorId: 'v-a'),
      isTrue,
    );
    expect(
      isMarketplaceOwnOffering(offeringVendorId: 'v-b', currentVendorId: 'v-a'),
      isFalse,
    );
  });
}
