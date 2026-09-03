import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:owambe/core/api/vendor_availability_display.dart';
import 'package:owambe/core/api/vendors_api.dart';
import 'package:owambe/eos/eos.dart';
import 'package:owambe/portals/customer/models/vendor_crm_models.dart';
import 'package:owambe/portals/customer/widgets/marketplace/vendor_availability_list.dart';

void main() {
  group('service availability helpers', () {
    test('formats BOOKED / CONFLICTING / UNAVAILABLE / AVAILABLE', () {
      expect(formatServiceAvailability('booked'), 'BOOKED');
      expect(formatServiceAvailability('CONFLICTING'), 'CONFLICTING');
      expect(formatServiceAvailability('unavailable'), 'UNAVAILABLE');
      expect(formatServiceAvailability('AVAILABLE'), 'AVAILABLE');
    });

    test('blocks new requests on booked, conflicting, and unavailable', () {
      expect(serviceWindowBlocksNewRequest('BOOKED'), isTrue);
      expect(serviceWindowBlocksNewRequest('CONFLICTING'), isTrue);
      expect(serviceWindowBlocksNewRequest('UNAVAILABLE'), isTrue);
      expect(serviceWindowBlocksNewRequest('AVAILABLE'), isFalse);
      expect(serviceWindowBlocksNewRequest(null), isFalse);
    });

    test('blocks inactive offers while allowing active and empty status', () {
      expect(serviceOfferInactive('inactive'), isTrue);
      expect(serviceOfferInactive('archived'), isTrue);
      expect(serviceOfferInactive('active'), isFalse);
      expect(serviceOfferInactive(null), isFalse);
      expect(serviceOfferInactive(''), isFalse);
    });

    test('formats event windows as day–month ranges', () {
      expect(
        formatDateWindow(DateTime(2026, 8, 22), DateTime(2026, 8, 23)),
        '22 Aug–23 Aug',
      );
      expect(formatDateWindow(DateTime(2026, 8, 22), DateTime(2026, 8, 22)), '22 Aug');
    });

    test('formats date and clock windows without classifying availability', () {
      expect(
        formatDateTimeWindow(DateTime(2026, 10, 21, 6, 30), DateTime(2026, 10, 21, 12, 30)),
        '21 Oct 2026 · 06:30 – 12:30',
      );
      expect(formatTimeRange(DateTime(2026, 10, 21, 6, 30), DateTime(2026, 10, 21, 12, 30)), '06:30 – 12:30');
      expect(formatDayHeading(DateTime(2026, 10, 21)), '21 OCTOBER');
      expect(formatMonthHeading(DateTime(2026, 10, 21)), 'OCTOBER 2026');
    });

    test('explains CONFLICTING from server bookedRanges without overlap math', () {
      final ranges = [
        BookedRange(startsAt: DateTime(2026, 10, 21, 6, 30), endsAt: DateTime(2026, 10, 21, 12, 30)),
      ];
      expect(
        availabilityConflictExplanation('CONFLICTING', ranges),
        'Vendor is already booked from 06:30 – 12:30.',
      );
      expect(availabilityConflictExplanation('AVAILABLE', ranges), isNull);
      expect(availabilityConflictExplanation('CONFLICTING', const []), isNull);
    });
  });

  group('VendorRequest capability snapshot', () {
    test('parses selectedCapabilities without mutating other commercial fields', () {
      final request = VendorRequest.fromJson({
        'id': 'req_1',
        'eventId': 'evt_1',
        'vendorId': 'vend_1',
        'stage': 'new',
        'serviceLabel': 'DJ',
        'message': 'Need a DJ',
        'createdAt': '2026-08-17T10:00:00.000Z',
        'updatedAt': '2026-08-17T10:00:00.000Z',
        'servicePriceMinor': 12000000,
        'vendorPayoutMinor': 10000000,
        'pricingMarkupBps': 2000,
        'selectedCapabilities': [
          {'key': 'sound_system', 'label': 'Sound System'},
          {'key': 'microphones', 'label': 'Microphones'},
        ],
      });
      expect(request.selectedCapabilities.map((c) => c.key).toList(), [
        'sound_system',
        'microphones',
      ]);
      expect(request.servicePriceMinor, 12000000);
      expect(request.vendorPayoutMinor, 10000000);
      expect(request.pricingMarkupBps, 2000);
      expect(request.stage, 'new');
      expect(request.isAwaitingVendor, isTrue);
      expect(request.isConfirmedBooking, isFalse);
    });

    test('defaults selectedCapabilities to empty when omitted', () {
      final request = VendorRequest.fromJson({
        'id': 'req_2',
        'eventId': 'evt_1',
        'vendorId': 'vend_1',
        'stage': 'accepted',
        'createdAt': '2026-08-17T10:00:00.000Z',
        'updatedAt': '2026-08-17T10:00:00.000Z',
      });
      expect(request.selectedCapabilities, isEmpty);
      expect(request.isConfirmedBooking, isTrue);
      expect(request.isAwaitingVendor, isFalse);
    });
  });

  group('MarketplaceVendorService availability payload', () {
    test('parses organizer-visible availability and provided capabilities', () {
      final service = MarketplaceVendorService.fromJson({
        'id': 'svc_1',
        'serviceKey': 'dj',
        'serviceName': 'DJ',
        'priceFromMinor': 12000000,
        'offerStatus': 'active',
        'availabilityStatus': 'BOOKED',
        'bookedRanges': [
          {
            'startsAt': '2026-08-21T00:00:00.000Z',
            'endsAt': '2026-08-24T00:00:00.000Z',
          },
        ],
        'capabilities': [
          {'key': 'sound_system', 'label': 'Sound System', 'provided': true},
        ],
      });
      expect(service.availabilityStatus, 'BOOKED');
      expect(service.bookedRanges, hasLength(1));
      expect(service.capabilities.single.label, 'Sound System');
      expect(service.serviceCode, isNull);
    });

    test('does not parse private booking fields onto bookedRanges', () {
      final service = MarketplaceVendorService.fromJson({
        'id': 'svc_private',
        'serviceKey': 'catering',
        'serviceName': 'Catering',
        'serviceCode': 'VS-000001',
        'availabilityStatus': 'CONFLICTING',
        'bookedRanges': [
          {
            'startsAt': '2026-10-06T09:00:00.000Z',
            'endsAt': '2026-10-06T13:00:00.000Z',
            'eventTitle': 'Secret Wedding',
            'organizerName': 'Other Host',
            'requestId': 'req_secret',
          },
        ],
      });
      expect(service.bookedRanges.single.startsAt, isA<DateTime>());
      expect(service.bookedRanges.single.endsAt, isA<DateTime>());
    });

    test('parses additive unavailableRanges without private overlay fields', () {
      final service = MarketplaceVendorService.fromJson({
        'id': 'svc_1',
        'serviceKey': 'catering',
        'serviceName': 'Catering',
        'availabilityStatus': 'UNAVAILABLE',
        'bookedRanges': [
          {'startsAt': '2026-10-05T23:03:32.309Z', 'endsAt': '2026-10-06T05:03:32.309Z'},
        ],
        'unavailableRanges': [
          {
            'startsAt': '2026-08-19T00:44:45.540Z',
            'endsAt': '2026-08-19T22:59:59.000Z',
            'kind': 'blackout',
            'reason': 'secret note',
            'sourceId': 'blk_1',
          },
        ],
      });
      expect(service.unavailableRanges, hasLength(1));
      expect(service.unavailableRanges.single.kind, 'blackout');
      expect(service.bookedRanges, hasLength(1));
    });
  });

  group('organizer availability display range', () {
    test('uses today through +90 days so October is visible in August', () {
      final range = organizerAvailabilityDisplayRange(now: DateTime(2026, 8, 19, 9));
      expect(range.from, DateTime(2026, 8, 19));
      expect(range.to, DateTime(2026, 11, 17));
    });
  });

  group('availability day rows from bookedRanges', () {
    test('marks occupied windows BOOKED and gaps AVAILABLE without inventing bookings', () {
      final rows = availabilityDayRows(
        from: DateTime(2026, 10, 6),
        to: DateTime(2026, 10, 9),
        bookedRanges: [
          BookedRange(startsAt: DateTime(2026, 10, 6, 10), endsAt: DateTime(2026, 10, 6, 14)),
          BookedRange(startsAt: DateTime(2026, 10, 9, 16), endsAt: DateTime(2026, 10, 9, 21)),
        ],
      );
      expect(rows, hasLength(4));
      expect(rows[0].booked, isTrue);
      expect(formatTimeRange12(rows[0].windows.single.startsAt, rows[0].windows.single.endsAt), '10:00 AM – 2:00 PM');
      expect(rows[1].kind, AvailabilityDayKind.available);
      expect(rows[2].kind, AvailabilityDayKind.available);
      expect(rows[3].booked, isTrue);
      expect(formatTimeRange12(rows[3].windows.single.startsAt, rows[3].windows.single.endsAt), '4:00 PM – 9:00 PM');
    });

    test('one-day blackout inside a 90-day range does not mark every day unavailable', () {
      final rows = availabilityDayRows(
        from: DateTime(2026, 8, 19),
        to: DateTime(2026, 11, 17),
        bookedRanges: [
          BookedRange(startsAt: DateTime(2026, 10, 6, 0, 3), endsAt: DateTime(2026, 10, 6, 6, 3)),
          BookedRange(startsAt: DateTime(2026, 10, 21, 6, 30), endsAt: DateTime(2026, 10, 24, 12, 30)),
        ],
        unavailableRanges: [
          BookedRange(
            startsAt: DateTime(2026, 8, 19, 1, 44),
            endsAt: DateTime(2026, 8, 19, 23, 59),
            kind: 'blackout',
          ),
        ],
      );
      AvailabilityDayRow day(int month, int d) =>
          rows.firstWhere((r) => r.day.month == month && r.day.day == d);
      expect(day(8, 19).vendorUnavailable, isTrue);
      expect(day(8, 20).kind, AvailabilityDayKind.available);
      expect(day(10, 6).booked, isTrue);
      expect(day(10, 7).kind, AvailabilityDayKind.available);
      expect(day(10, 21).booked, isTrue);
      expect(day(10, 24).booked, isTrue);
      expect(rows.where((r) => r.vendorUnavailable), hasLength(1));
    });

    test('keeps Catering and DJ occupancy independent', () {
      final catering = [
        BookedRange(startsAt: DateTime(2026, 10, 6, 10), endsAt: DateTime(2026, 10, 6, 14)),
      ];
      final dj = <BookedRange>[];
      final cateringRows = availabilityDayRows(
        from: DateTime(2026, 10, 6),
        to: DateTime(2026, 10, 6),
        bookedRanges: catering,
      );
      final djRows = availabilityDayRows(
        from: DateTime(2026, 10, 6),
        to: DateTime(2026, 10, 6),
        bookedRanges: dj,
      );
      expect(cateringRows.single.booked, isTrue);
      expect(djRows.single.booked, isFalse);
    });
  });

  group('VendorAvailabilityList', () {
    testWidgets('renders booked times and available days without private booking copy', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: EosTheme.dark(),
          home: Scaffold(
            body: VendorAvailabilityList(
              vendorName: 'Jollof & Co',
              serviceName: 'Catering',
              serviceCode: 'VS-000001',
              from: DateTime(2026, 10, 6),
              to: DateTime(2026, 10, 9),
              availabilityStatus: 'CONFLICTING',
              bookedRanges: [
                BookedRange(startsAt: DateTime(2026, 10, 6, 10), endsAt: DateTime(2026, 10, 6, 14)),
                BookedRange(startsAt: DateTime(2026, 10, 9, 16), endsAt: DateTime(2026, 10, 9, 21)),
              ],
            ),
          ),
        ),
      );
      expect(find.text('CATERING AVAILABILITY'), findsOneWidget);
      expect(find.text('October 2026'), findsOneWidget);
      expect(find.text('6 October'), findsOneWidget);
      expect(find.text('BOOKED'), findsNWidgets(2));
      expect(find.text('10:00 AM – 2:00 PM'), findsOneWidget);
      expect(find.text('7 October'), findsOneWidget);
      expect(find.text('AVAILABLE'), findsWidgets);
      expect(find.text('4:00 PM – 9:00 PM'), findsOneWidget);
      expect(find.text('Service Code: VS-000001'), findsOneWidget);
      expect(find.textContaining('Secret'), findsNothing);
      expect(find.textContaining('Wedding'), findsNothing);
      expect(find.textContaining('Organizer'), findsNothing);
    });

    testWidgets('one-day blackout does not hide October bookings when status is UNAVAILABLE', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: EosTheme.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: VendorAvailabilityList(
              serviceName: 'Catering',
              serviceCode: 'VS-000002',
              from: DateTime(2026, 8, 19),
              to: DateTime(2026, 11, 17),
              availabilityStatus: 'UNAVAILABLE',
              bookedRanges: [
                BookedRange(startsAt: DateTime(2026, 10, 6, 0, 3), endsAt: DateTime(2026, 10, 6, 6, 3)),
                BookedRange(startsAt: DateTime(2026, 10, 21, 6, 30), endsAt: DateTime(2026, 10, 24, 12, 30)),
              ],
              unavailableRanges: [
                BookedRange(
                  startsAt: DateTime(2026, 8, 19, 1, 44),
                  endsAt: DateTime(2026, 8, 19, 23, 59),
                  kind: 'blackout',
                ),
              ],
            ),
            ),
          ),
        ),
      );
      expect(find.text('19 August'), findsOneWidget);
      expect(find.text('VENDOR UNAVAILABLE'), findsOneWidget);
      expect(find.text('20 August'), findsOneWidget);
      expect(find.text('AVAILABLE'), findsWidgets);
      expect(find.text('6 October'), findsOneWidget);
      expect(find.text('BOOKED'), findsWidgets);
      expect(find.text('12:03 AM – 6:03 AM'), findsOneWidget);
      expect(find.text('21 October'), findsOneWidget);
    });
  });
}
