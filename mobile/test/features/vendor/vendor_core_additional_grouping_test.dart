import 'package:flutter_test/flutter_test.dart';
import 'package:owambe/core/api/event_config_api.dart';
import 'package:owambe/features/vendor/widgets/vendor_service_capability_editor.dart';

void main() {
  group('vendorCapabilitiesForTier', () {
    final catalogue = [
      const VendorCategoryCapability(key: 'sound_system', label: 'Sound System', tier: 'core'),
      const VendorCategoryCapability(key: 'speakers', label: 'Speakers', tier: 'core'),
      const VendorCategoryCapability(key: 'lighting', label: 'Lighting', tier: 'optional'),
      const VendorCategoryCapability(key: 'stage', label: 'Stage', tier: 'optional'),
      const VendorCategoryCapability(key: 'dj_controller', label: 'DJ Controller', tier: 'core'),
    ];

    test('splits strictly by capability.tier and preserves Admin order within each group', () {
      final core = vendorCapabilitiesForTier(catalogue, 'core');
      final additional = vendorCapabilitiesForTier(catalogue, 'optional');
      expect(core.map((c) => c.key), ['sound_system', 'speakers', 'dj_controller']);
      expect(additional.map((c) => c.key), ['lighting', 'stage']);
      expect({...core.map((c) => c.key)}.intersection({...additional.map((c) => c.key)}), isEmpty);
    });

    test('Admin tier change moves item between groups without duplication', () {
      final after = [
        for (final c in catalogue)
          if (c.key == 'lighting') c.copyWith(tier: 'core') else c,
      ];
      final core = vendorCapabilitiesForTier(after, 'core');
      final additional = vendorCapabilitiesForTier(after, 'optional');
      expect(core.map((c) => c.key), contains('lighting'));
      expect(additional.map((c) => c.key), isNot(contains('lighting')));
      expect(core.where((c) => c.key == 'lighting').length, 1);
    });

    test('missing/unknown tier is treated as core (legacy catalogue rows)', () {
      const legacy = VendorCategoryCapability(key: 'microphones', label: 'Microphones');
      expect(vendorCapabilitiesForTier([legacy], 'core').single.key, 'microphones');
      expect(vendorCapabilitiesForTier([legacy], 'optional'), isEmpty);
    });
  });
}
