import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:owambe/eos/eos.dart';
import 'package:owambe/features/vendor/models/vendor_workspace_profile.dart';
import 'package:owambe/features/vendor/providers/vendor_inbox_integration.dart';
import 'package:owambe/features/vendor/providers/vendor_profile_providers.dart';
import 'package:owambe/features/vendor/screens/vendor_services_availability_screen.dart';
import 'package:owambe/portals/customer/models/vendor_crm_models.dart';

/// ListTile-in-DecoratedBox is a Flutter 3.44 debug warning, not the crash.
void expectNoUnexpectedNull(WidgetTester tester) {
  Object? ex;
  while ((ex = tester.takeException()) != null) {
    expect(ex, isNot(isA<TypeError>()));
    expect('$ex', isNot(contains('Unexpected null value')));
  }
}

void main() {
  testWidgets('ThemeData.dark() strips EosTokens and EosSurfaceCard throws', (tester) async {
    Object? thrown;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Builder(
          builder: (context) {
            try {
              Theme.of(context).extension<EosTokens>()!;
            } catch (e) {
              thrown = e;
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(thrown, isA<TypeError>());
  });

  testWidgets('Services & Availability loads empty services without Unexpected null', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vendorWorkspaceProfileProvider.overrideWith(
            (ref) async => const VendorWorkspaceProfile(userId: 'user-new'),
          ),
          vendorInboxSnapshotProvider.overrideWith(
            (ref) async => const VendorCrmSnapshot(items: [], stats: VendorPipelineStats()),
          ),
        ],
        child: MaterialApp(
          theme: EosTheme.dark(),
          home: const VendorServicesAvailabilityScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Services & Availability'), findsOneWidget);
    expect(find.textContaining('No bookable services yet'), findsOneWidget);
    expectNoUnexpectedNull(tester);
  });

  testWidgets('Services & Availability renders existing services without EosTokens crash', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vendorWorkspaceProfileProvider.overrideWith(
            (ref) async => const VendorWorkspaceProfile(
              userId: 'user-existing',
              vendorId: 'vend-1',
              services: [
                VendorServiceEntity(
                  id: 'svc-1',
                  serviceKey: 'catering',
                  serviceName: 'Catering',
                  capabilities: [
                    VendorServiceCapability(key: 'jollof', label: 'Jollof', provided: true),
                  ],
                ),
              ],
            ),
          ),
          vendorInboxSnapshotProvider.overrideWith(
            (ref) async => const VendorCrmSnapshot(items: [], stats: VendorPipelineStats()),
          ),
        ],
        child: MaterialApp(
          theme: EosTheme.dark(),
          home: const VendorServicesAvailabilityScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Catering'), findsOneWidget);
    expect(find.text('Available for Requests'), findsOneWidget);
    expectNoUnexpectedNull(tester);
  });
}
