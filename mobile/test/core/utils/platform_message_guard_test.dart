import 'package:flutter_test/flutter_test.dart';

import 'package:owambe/core/utils/platform_message_guard.dart';

void main() {
  group('PlatformMessageGuard', () {
    test('allows operational service discussion', () {
      expect(
        PlatformMessageGuard.blockReason('Can you cater for 150 guests at 2pm?'),
        isNull,
      );
      expect(
        PlatformMessageGuard.blockReason('We will bring 4 staff and buffet equipment.'),
        isNull,
      );
    });

    test('blocks contact and payment bypass attempts', () {
      expect(
        PlatformMessageGuard.blockReason('WhatsApp me on this number'),
        PlatformMessageGuard.keepInOwanbe,
      );
      expect(
        PlatformMessageGuard.blockReason('Call me on 08012345678'),
        PlatformMessageGuard.keepInOwanbe,
      );
      expect(
        PlatformMessageGuard.blockReason('Pay me directly outside Owanbe'),
        PlatformMessageGuard.keepInOwanbe,
      );
      expect(
        PlatformMessageGuard.blockReason('Send payment to my GTBank account'),
        PlatformMessageGuard.keepInOwanbe,
      );
    });
  });
}
