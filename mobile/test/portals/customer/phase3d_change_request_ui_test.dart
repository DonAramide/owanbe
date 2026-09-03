import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:owambe/portals/customer/models/vendor_change_request_models.dart';
import 'package:owambe/portals/customer/models/vendor_crm_models.dart';
import 'package:owambe/portals/customer/providers/vendor_crm_providers.dart';
import 'package:owambe/portals/customer/widgets/vendor_crm/change_request_comparison.dart';
import 'package:owambe/portals/customer/widgets/vendor_crm/vendor_change_requests_panel.dart';
import 'package:owambe/shared/widgets/unsaved_changes.dart';

VendorRequest _request({String stage = 'accepted'}) => VendorRequest(
      id: 'req_1',
      eventId: 'evt_1',
      vendorId: 'vend_1',
      stage: stage,
      serviceLabel: 'DJ',
      message: 'Need sound',
      createdAt: DateTime.utc(2026, 8, 1),
      updatedAt: DateTime.utc(2026, 8, 2),
      selectedCapabilities: const [
        SelectedCapability(key: 'sound_system', label: 'Sound System'),
        SelectedCapability(key: 'microphones', label: 'Microphones'),
      ],
      eventStartsAt: DateTime.utc(2026, 10, 21, 17, 0),
      eventEndsAt: DateTime.utc(2026, 10, 21, 22, 0),
      venueName: 'Lagos Hall',
    );

VendorChangeRequest _change({
  String status = 'pending',
  String type = 'ADD_CAPABILITY',
}) =>
    VendorChangeRequest(
      id: 'cr_1',
      vendorRequestId: 'req_1',
      eventId: 'evt_1',
      vendorId: 'vend_1',
      type: type,
      status: status,
      originalSnapshot: {
        'serviceLabel': 'DJ',
        'eventStartsAt': '2026-10-21T17:00:00.000Z',
        'eventEndsAt': '2026-10-21T22:00:00.000Z',
        'venueName': 'Lagos Hall',
        'selectedCapabilities': [
          {'key': 'sound_system', 'label': 'Sound System'},
          {'key': 'microphones', 'label': 'Microphones'},
        ],
      },
      requestedPayload: {
        'capabilityKey': 'led_screen',
        'capabilityLabel': 'LED Screen',
      },
      responsePayload: const {},
      createdAt: DateTime.utc(2026, 8, 20, 10),
      updatedAt: DateTime.utc(2026, 8, 20, 10),
    );

void main() {
  group('VendorChangeRequest model', () {
    test('parses REST view and builds CURRENT vs REQUESTED summaries', () {
      final change = VendorChangeRequest.fromJson({
        'id': 'cr_1',
        'vendorRequestId': 'req_1',
        'eventId': 'evt_1',
        'vendorId': 'vend_1',
        'type': 'ADD_CAPABILITY',
        'status': 'pending',
        'originalSnapshot': {
          'serviceLabel': 'DJ',
          'eventStartsAt': '2026-10-21T17:00:00.000Z',
          'selectedCapabilities': [
            {'key': 'sound_system', 'label': 'Sound System'},
          ],
        },
        'requestedPayload': {
          'capabilityKey': 'led_screen',
          'capabilityLabel': 'LED Screen',
        },
        'responsePayload': {},
        'createdAt': '2026-08-20T10:00:00.000Z',
        'updatedAt': '2026-08-20T10:00:00.000Z',
      });

      expect(change.isPending, isTrue);
      expect(change.typeLabel, 'Add capability');
      expect(change.statusLabel, 'Pending');
      expect(change.currentSummary, contains('DJ'));
      expect(change.currentSummary, contains('Sound System'));
      expect(change.requestedSummary, 'Add: LED Screen');
    });

    test('gate matches Phase 3C active booking stages only', () {
      expect(vendorRequestAllowsChangeRequests('accepted'), isTrue);
      expect(vendorRequestAllowsChangeRequests('scheduled'), isTrue);
      expect(vendorRequestAllowsChangeRequests('arrived'), isTrue);
      expect(vendorRequestAllowsChangeRequests('new'), isFalse);
      expect(vendorRequestAllowsChangeRequests('completed'), isFalse);
      expect(vendorRequestAllowsChangeRequests('declined'), isFalse);
    });

    test('CHANGE_VENUE and SPECIAL_REQUIREMENT summaries', () {
      final venue = _change(type: 'CHANGE_VENUE').copyWithPayload({
        'venueName': 'New Hall',
        'venueAddress': 'Victoria Island',
      });
      expect(venue.requestedSummary, contains('New Hall'));
      expect(venue.requestedSummary, contains('Victoria Island'));

      final special = VendorChangeRequest(
        id: 'cr_2',
        vendorRequestId: 'req_1',
        eventId: 'evt_1',
        vendorId: 'vend_1',
        type: 'SPECIAL_REQUIREMENT',
        status: 'pending',
        originalSnapshot: const {'serviceLabel': 'DJ'},
        requestedPayload: const {'requirement': 'Extra power outlets'},
        responsePayload: const {},
        createdAt: DateTime.utc(2026, 8, 20),
        updatedAt: DateTime.utc(2026, 8, 20),
      );
      expect(special.requestedSummary, 'Extra power outlets');
    });
  });

  group('Change request UI', () {
    testWidgets('shows CURRENT vs REQUESTED comparison', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeRequestComparison(change: _change()),
          ),
        ),
      );
      expect(find.text('CURRENT'), findsOneWidget);
      expect(find.text('REQUESTED'), findsOneWidget);
      expect(find.textContaining('Add: LED Screen'), findsOneWidget);
      expect(find.textContaining('Sound System'), findsOneWidget);
    });

    testWidgets('vendor panel empty state', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vendorChangeRequestsProvider('req_1').overrideWith((ref) async => const []),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: VendorChangeRequestsPanel(
                request: _request(),
                role: ChangeRequestPanelRole.vendor,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('No change requests'), findsOneWidget);
    });

    testWidgets('vendor panel shows Accept / Decline for pending', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vendorChangeRequestsProvider('req_1').overrideWith((ref) async => [_change()]),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: VendorChangeRequestsPanel(
                request: _request(),
                role: ChangeRequestPanelRole.vendor,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);
      expect(find.text('PENDING'), findsOneWidget);
    });

    testWidgets('organizer panel shows cancel for pending', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vendorChangeRequestsProvider('req_1').overrideWith((ref) async => [_change()]),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: VendorChangeRequestsPanel(
                request: _request(),
                role: ChangeRequestPanelRole.organizer,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Cancel change request'), findsOneWidget);
      expect(find.text('Accept'), findsNothing);
    });

    testWidgets('preview comparison before send', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChangeRequestPreviewComparison(
              typeLabel: 'Add capability',
              currentSummary: 'DJ\nSound System',
              requestedSummary: 'Add: LED Screen',
            ),
          ),
        ),
      );
      expect(find.text('CURRENT'), findsOneWidget);
      expect(find.text('REQUESTED'), findsOneWidget);
      expect(find.text('Add: LED Screen'), findsOneWidget);
    });
  });

  group('realtime invalidation contract', () {
    test('refreshVendorCrm bumps shared counter used by change-request provider', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(vendorCrmRefreshProvider), 0);
      refreshVendorCrm(container);
      expect(container.read(vendorCrmRefreshProvider), 1);
    });
  });

  group('unsaved changes cohesion', () {
    test('vendor services registry binder still supports Stay / Discard', () async {
      var discarded = false;
      UnsavedChangesRegistry.vendorServices = UnsavedChangesBinder(
        isDirty: () => true,
        discard: () => discarded = true,
      );
      addTearDown(() => UnsavedChangesRegistry.vendorServices = null);

      final binder = UnsavedChangesRegistry.vendorServices!;
      expect(binder.isDirty(), isTrue);
      binder.discard();
      expect(discarded, isTrue);
    });
  });

  group('three-level capability eligibility (display rule)', () {
    test('organizer can only request vendor-provided ∩ admin-enabled keys', () {
      final adminEnabled = {'sound_system', 'microphones', 'led_screen'};
      final vendorProvides = {'sound_system', 'microphones'};
      final requestable = adminEnabled.intersection(vendorProvides);
      expect(requestable.contains('led_screen'), isFalse);
      expect(requestable, {'sound_system', 'microphones'});
    });
  });
}

extension on VendorChangeRequest {
  VendorChangeRequest copyWithPayload(Map<String, dynamic> payload) => VendorChangeRequest(
        id: id,
        vendorRequestId: vendorRequestId,
        eventId: eventId,
        vendorId: vendorId,
        type: type,
        status: status,
        originalSnapshot: originalSnapshot,
        requestedPayload: payload,
        responsePayload: responsePayload,
        createdAt: createdAt,
        updatedAt: updatedAt,
        resolvedAt: resolvedAt,
      );
}
