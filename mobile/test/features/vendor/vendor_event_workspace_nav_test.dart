import 'package:flutter_test/flutter_test.dart';
import 'package:owambe/features/vendor/providers/vendor_event_workspace_nav.dart';
import 'package:owambe/portals/customer/models/vendor_crm_models.dart';

void main() {
  VendorRequest request({
    required String eventId,
    String? eventExternalRef,
  }) {
    final now = DateTime.utc(2026, 8, 8);
    return VendorRequest(
      id: '68726e00-a442-456c-ac65-81ba844bd02f',
      eventId: eventId,
      vendorId: '401c71d5-5067-42da-a0c3-f1ab03f3aeec',
      stage: 'accepted',
      serviceLabel: 'Celebration vendor',
      message: 'hi',
      eventTitle: 'anger manage',
      organizerName: 'juilio',
      createdAt: now,
      updatedAt: now,
      eventExternalRef: eventExternalRef,
    );
  }

  test('matches CRM UUID against Event Ops evt_* via eventExternalRef', () {
    final r = request(
      eventId: '1aacb543-2169-4d76-8308-fb8921fb648b',
      eventExternalRef: 'evt_anger_manage',
    );
    expect(
      vendorRequestMatchesEventKey(r, eventKey: 'evt_anger_manage'),
      isTrue,
    );
    expect(
      findVendorRequestForEventKey([r], eventKey: 'evt_anger_manage')?.id,
      r.id,
    );
  });

  test('matches CRM UUID when Event Ops provides eventUuid', () {
    final r = request(eventId: '1aacb543-2169-4d76-8308-fb8921fb648b');
    expect(
      vendorRequestMatchesEventKey(
        r,
        eventKey: 'evt_anger_manage',
        eventUuid: '1aacb543-2169-4d76-8308-fb8921fb648b',
      ),
      isTrue,
    );
  });

  test('does not match unrelated events', () {
    final r = request(
      eventId: '1aacb543-2169-4d76-8308-fb8921fb648b',
      eventExternalRef: 'evt_anger_manage',
    );
    expect(
      vendorRequestMatchesEventKey(r, eventKey: 'evt_other_event'),
      isFalse,
    );
  });
}
