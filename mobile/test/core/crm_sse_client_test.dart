import 'package:flutter_test/flutter_test.dart';
import 'package:owambe/core/api/crm_sse_client.dart';

void main() {
  group('CrmRealtimeDedupeCache', () {
    test('drops duplicate eventId', () {
      final cache = CrmRealtimeDedupeCache();
      expect(cache.claim('e1', 'dk1'), isTrue);
      expect(cache.claim('e1', 'dk2'), isFalse);
    });

    test('drops duplicate dedupeKey', () {
      final cache = CrmRealtimeDedupeCache();
      expect(cache.claim('e1', 'vendor_request:r1:new'), isTrue);
      expect(cache.claim('e2', 'vendor_request:r1:new'), isFalse);
    });

    test('allows distinct events', () {
      final cache = CrmRealtimeDedupeCache();
      expect(cache.claim('e1', 'a'), isTrue);
      expect(cache.claim('e2', 'b'), isTrue);
    });
  });

  group('CrmRealtimeEnvelope', () {
    test('parses minimal payload', () {
      final env = CrmRealtimeEnvelope.fromJson({
        'eventId': 'abc',
        'type': 'vendor_request_incoming',
        'tenantId': 't1',
        'resource': {'type': 'vendor_request', 'id': 'r1'},
        'updatedAt': '2026-04-01T12:00:00.000Z',
        'dedupeKey': 'vendor_request:r1:new',
        'occurredAt': '2026-04-01T12:00:00.000Z',
        'meta': {'eventId': 'ev1', 'stage': 'new'},
      });
      expect(env.eventId, 'abc');
      expect(env.resourceId, 'r1');
      expect(env.metaStage, 'new');
      expect(env.type, 'vendor_request_incoming');
    });
  });
}
