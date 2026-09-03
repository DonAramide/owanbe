import 'package:flutter_test/flutter_test.dart';
import 'package:owambe/core/api/event_config_api.dart';
import 'package:owambe/core/api/vendors_api.dart';
import 'package:owambe/features/vendor/models/vendor_workspace_profile.dart';

void main() {
  group('Admin capability tier', () {
    test('parses core and optional from catalogue JSON', () {
      final core = VendorCategoryCapability.fromJson({
        'key': 'sound_system',
        'label': 'Sound System',
        'enabled': true,
        'tier': 'core',
      });
      final optional = VendorCategoryCapability.fromJson({
        'key': 'stage',
        'label': 'Stage',
        'enabled': true,
        'tier': 'optional',
      });
      expect(core.isCore, isTrue);
      expect(optional.isOptional, isTrue);
      expect(VendorCategoryCapability.fromJson({'key': 'x', 'label': 'X'}).isCore, isTrue);
    });
  });

  group('Vendor selection shape', () {
    test('parses provided flags without Vendor-created catalogue entries', () {
      final service = VendorServiceEntity.fromJson({
        'id': 'svc_1',
        'serviceKey': 'dj',
        'serviceName': 'DJ',
        'status': 'active',
        'capabilities': [
          {'key': 'sound_system', 'label': 'Sound System', 'provided': true},
          {'key': 'stage', 'label': 'Stage', 'provided': false},
        ],
      });
      expect(service.capabilities.where((c) => c.provided).map((c) => c.key), ['sound_system']);
    });
  });

  group('Marketplace / request visibility', () {
    test('public service shows only Admin∩Vendor capabilities', () {
      final service = MarketplaceVendorService.fromJson({
        'id': 'svc_1',
        'serviceKey': 'dj',
        'serviceName': 'DJ',
        'capabilities': [
          {'key': 'sound_system', 'label': 'Sound System'},
          {'key': 'stage', 'label': 'Stage'},
        ],
      });
      expect(service.capabilities.map((c) => c.key), ['sound_system', 'stage']);
      expect(service.matchesLabel('stage'), isTrue);
      expect(service.matchesLabel('karaoke'), isFalse);
    });

    test('search uses capability labels from public payload', () {
      final vendor = MarketplaceVendor(
        id: 'v1',
        businessName: 'INTERNATIONAL REVREND',
        services: [
          MarketplaceVendorService.fromJson({
            'id': 'svc_1',
            'serviceKey': 'dj',
            'serviceName': 'DJ Performance',
            'serviceCode': 'VS-000010',
            'capabilities': [
              {'key': 'sound_system', 'label': 'Sound System'},
            ],
          }),
        ],
      );
      expect(vendor.matchesSearchQuery('sound system'), isTrue);
      expect(vendor.matchesSearchQuery('VS-000010'), isTrue);
      expect(vendor.matchesSearchQuery('not-a-match-xyz'), isFalse);
    });
  });
}
