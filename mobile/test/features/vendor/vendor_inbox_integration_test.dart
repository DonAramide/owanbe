import 'package:flutter_test/flutter_test.dart';

import 'package:owambe/features/vendor/providers/vendor_inbox_integration.dart';
import 'package:owambe/features/vendor/vendor_identity.dart';
import 'package:owambe/portals/customer/models/vendor_crm_models.dart';

void main() {
  group('VendorIdentity', () {
    test('resolves legacy marketplace aliases to canonical vendor id', () {
      expect(VendorIdentity.resolveMarketplaceVendorId('v12'), VendorIdentity.canonicalDevVendorId);
      expect(VendorIdentity.resolveMarketplaceVendorId('vendor_jollof'), VendorIdentity.canonicalDevVendorId);
      expect(
        VendorIdentity.resolveMarketplaceVendorId(VendorIdentity.canonicalDevVendorId),
        VendorIdentity.canonicalDevVendorId,
      );
    });
  });

  group('vendor inbox integration', () {
    final now = DateTime(2026, 7, 9, 12);

    VendorRequest request({
      required String id,
      required String stage,
      String? eventTitle,
      String? organizerName,
    }) {
      return VendorRequest(
        id: id,
        eventId: 'evt_1',
        vendorId: VendorIdentity.canonicalDevVendorId,
        stage: stage,
        serviceLabel: 'Catering',
        message: 'Please cater our event',
        eventTitle: eventTitle,
        organizerName: organizerName,
        createdAt: now,
        updatedAt: now,
      );
    }

    test('maps pending CRM requests to negotiation items', () {
      final snapshot = VendorCrmSnapshot(
        items: [
          request(id: 'req_1', stage: 'new', eventTitle: 'Don Wedding', organizerName: 'RC'),
        ],
        stats: const VendorPipelineStats(newCount: 1, total: 1),
      );

      final negotiations = vendorInboxNegotiations(snapshot);
      expect(negotiations, hasLength(1));
      expect(negotiations.first.id, 'req_1');
      expect(negotiations.first.clientName, 'RC');
      expect(negotiations.first.eventName, 'Don Wedding');
      expect(negotiations.first.status, 'pending_vendor');
    });

    test('partitions inbox by lifecycle stage', () {
      final snapshot = VendorCrmSnapshot(
        items: [
          request(id: 'req_1', stage: 'new'),
          request(id: 'req_2', stage: 'accepted', eventTitle: 'Don Wedding'),
          request(id: 'req_3', stage: 'declined'),
          request(id: 'req_4', stage: 'completed'),
        ],
        stats: const VendorPipelineStats(total: 4),
      );

      expect(vendorInboxPendingRequests(snapshot), hasLength(1));
      expect(vendorInboxAcceptedJobs(snapshot), hasLength(1));
      expect(vendorInboxDeclinedRequests(snapshot), hasLength(1));
      expect(vendorInboxCompletedJobs(snapshot), hasLength(1));
    });

    test('builds notification summaries from live inbox', () {
      final snapshot = VendorCrmSnapshot(
        items: [request(id: 'req_1', stage: 'new', eventTitle: 'Don Wedding')],
        stats: const VendorPipelineStats(newCount: 1, total: 1),
      );
      final notes = vendorInboxNotifications(snapshot);
      expect(notes.first, contains('Don Wedding'));
    });
  });
}
