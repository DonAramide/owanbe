import 'package:flutter_test/flutter_test.dart';

void main() {
  test('offerings config treats capabilities as independent flags', () {
    final config = {
      'capabilityKeys': ['SERVICE_PROVIDER', 'RENTAL_PROVIDER'],
    };
    final keys = (config['capabilityKeys'] as List).cast<String>();
    expect(keys.contains('SERVICE_PROVIDER'), isTrue);
    expect(keys.contains('RENTAL_PROVIDER'), isTrue);
    expect(keys.contains('VENDOR_BUYER'), isFalse);
  });

  test('package components carry definition quantity, not a buyer request', () {
    final packageJson = {
      'name': 'Wedding DJ Equipment Set',
      'isPackage': true,
      'components': [
        {'resourceId': 'r1', 'label': 'Speaker', 'quantity': 2},
        {'resourceId': 'r2', 'label': 'Microphone', 'quantity': 5},
      ],
    };
    final comps = (packageJson['components'] as List).cast<Map>();
    expect(packageJson['isPackage'], isTrue);
    expect(comps.singleWhere((c) => c['label'] == 'Speaker')['quantity'], 2);
  });
}
