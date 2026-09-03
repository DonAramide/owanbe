import 'package:flutter_test/flutter_test.dart';

import 'package:owambe/portals/customer/models/vendor_crm_models.dart';

void main() {
  group('VendorCalendarBlock manageability', () {
    VendorCalendarBlock block({
      required String kind,
      String? sourceType,
      String? sourceId,
    }) {
      return VendorCalendarBlock(
        id: '11111111-1111-4111-8111-111111111111',
        kind: kind,
        startsAt: DateTime(2026, 8, 19),
        endsAt: DateTime(2026, 8, 19, 23, 59),
        allDay: true,
        reason: 'Personal commitment',
        sourceType: sourceType,
        sourceId: sourceId,
      );
    }

    test('manual Block Dates blackout is vendor-manageable', () {
      final parsed = VendorCalendarBlock.fromJson({
        'id': '11111111-1111-4111-8111-111111111111',
        'kind': 'blackout',
        'startsAt': '2026-08-19T00:00:00.000Z',
        'endsAt': '2026-08-19T23:59:59.000Z',
        'allDay': true,
        'reason': 'Personal commitment',
        'sourceType': null,
        'sourceId': null,
      });
      expect(parsed.isManualBlackout, isTrue);
      expect(parsed.sourceType, isNull);
      expect(parsed.sourceId, isNull);
    });

    test('vacation and CRM/rental blocks are read-only', () {
      expect(block(kind: 'vacation').isManualBlackout, isFalse);
      expect(
        block(kind: 'blackout', sourceType: 'vendor_request', sourceId: 'req_1').isManualBlackout,
        isFalse,
      );
      expect(
        block(kind: 'crm_scheduled', sourceType: 'vendor_request', sourceId: 'req_1').isManualBlackout,
        isFalse,
      );
      expect(
        block(kind: 'blackout', sourceType: 'rental_blackout').isManualBlackout,
        isFalse,
      );
    });
  });
}
