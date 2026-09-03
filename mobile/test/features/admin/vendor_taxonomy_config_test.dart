import 'package:flutter_test/flutter_test.dart';
import 'package:owambe/core/api/event_config_api.dart';

void main() {
  test('parses offering kind on vendor category JSON without dropping existing fields', () {
    final cat = VendorCategoryConfig.fromJson({
      'id': '1',
      'slug': 'dj',
      'label': 'DJ',
      'isActive': true,
      'offeringKind': 'service',
      'capabilities': [
        {'key': 'speakers', 'label': 'Speakers', 'enabled': true, 'tier': 'core'},
      ],
    });
    expect(cat.offeringKind, 'service');
    expect(cat.capabilities.single.key, 'speakers');
  });

  test('parses business capability keys from admin API', () {
    final cap = VendorBusinessCapabilityConfig.fromJson({
      'id': '1',
      'capabilityKey': 'SERVICE_PROVIDER',
      'label': 'Service Provider',
      'isActive': true,
    });
    expect(cap.capabilityKey, 'SERVICE_PROVIDER');
    expect(cap.isActive, isTrue);
  });

  test('parses resource catalogue definitions (not inventory)', () {
    final item = VendorResourceCatalogItem.fromJson({
      'id': '1',
      'slug': 'microphone',
      'label': 'Microphone',
      'description': 'Handheld',
      'isActive': true,
    });
    expect(item.slug, 'microphone');
    expect(item.label, 'Microphone');
  });
}
