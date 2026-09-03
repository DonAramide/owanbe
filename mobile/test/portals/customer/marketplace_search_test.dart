import 'package:flutter_test/flutter_test.dart';
import 'package:owambe/core/api/vendors_api.dart';
import 'package:owambe/portals/customer/models/marketplace_filters.dart';

void main() {
  group('marketplace search filters', () {
    const vendor = MarketplaceVendor(
      id: '11111111-1111-4111-8111-111111111111',
      businessName: 'ABC Mortuary Services',
      city: 'Lagos',
      countryCode: 'NG',
      slug: 'prosper',
      category: 'Mortuary Services',
      servicesOffered: ['Mortuary Services'],
      services: [
        MarketplaceVendorService(
          id: 'svc-1',
          serviceKey: 'mortuary_services',
          serviceName: 'Mortuary Services',
          serviceCode: 'VS-000042',
        ),
      ],
    );

    test('matches public business name, service, city, and code', () {
      expect(vendor.matchesSearchQuery('ABC Mortuary Services'), isTrue);
      expect(vendor.matchesSearchQuery('Mortuary'), isTrue);
      expect(vendor.matchesSearchQuery('Lagos'), isTrue);
      expect(vendor.matchesSearchQuery('VS-000042'), isTrue);
      expect(vendor.matchesSearchQuery('11111111'), isTrue);
    });

    test('does not match leftover account-holder slug or personal name', () {
      expect(vendor.matchesSearchQuery('Prosper'), isFalse);
      expect(vendor.matchesSearchQuery('prosper'), isFalse);
    });

    test('applyMarketplaceFilters honors query and rejects personal name', () {
      final filtered = applyMarketplaceFilters(
        const [vendor],
        const MarketplaceFilters(query: 'VS-000042'),
      );
      expect(filtered, hasLength(1));

      final byService = applyMarketplaceFilters(
        const [vendor],
        const MarketplaceFilters(query: 'Mortuary'),
      );
      expect(byService, hasLength(1));

      final none = applyMarketplaceFilters(
        const [vendor],
        const MarketplaceFilters(query: 'Abuja'),
      );
      expect(none, isEmpty);

      final personal = applyMarketplaceFilters(
        const [vendor],
        const MarketplaceFilters(query: 'Prosper'),
      );
      expect(personal, isEmpty);
    });
  });
}
