import 'package:flutter_test/flutter_test.dart';
import 'package:owambe/portals/customer/models/vendor_crm_models.dart';

void main() {
  test('parses additive vendor buyer context without dropping organizer name', () {
    final r = VendorRequest.fromJson({
      'id': 'req1',
      'eventId': 'e1',
      'vendorId': 'provider',
      'stage': 'new',
      'serviceLabel': 'Photography',
      'message': '',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'organizerName': 'Event Host Org',
      'buyerKind': 'vendor',
      'buyerVendorId': 'buyer',
      'buyerVendorName': 'DJ Mike',
      'vendorName': 'Lens Co',
      'eventTitle': 'Aramide Wedding',
    });
    expect(r.buyerKind, 'vendor');
    expect(r.displayBuyerName, 'DJ Mike');
    expect(r.organizerName, 'Event Host Org');
  });
}
