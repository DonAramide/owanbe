import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:owambe/core/api/event_config_api.dart';
import 'package:owambe/eos/eos.dart';
import 'package:owambe/eos/layout/workspace/workspace_definition.dart';
import 'package:owambe/eos/layout/workspace/workspace_widgets.dart';
import 'package:owambe/features/organizer/providers/event_config_providers.dart';
import 'package:owambe/portals/customer/models/customer_event_models.dart';
import 'package:owambe/portals/customer/providers/customer_event_providers.dart';
import 'package:owambe/portals/customer/screens/customer_event_edit_screen.dart';
import 'package:owambe/shared/models/event_access_mode.dart';

CustomerEvent _event() {
  final starts = DateTime(2026, 8, 20, 14);
  return CustomerEvent(
    id: 'evt_edit',
    title: 'Test Date',
    tagline: 'A gathering',
    description: 'Original description',
    city: 'Lagos',
    venue: 'Landmark',
    startsAt: starts,
    endsAt: starts.add(const Duration(hours: 6)),
    category: 'Wedding',
    status: CustomerEventStatus.draft,
    coverGradientStart: 0xFF4B2C6F,
    coverGradientEnd: 0xFFD4A853,
    ticketTiers: const [],
    vendors: const [],
    attendees: const [],
    venueName: 'Landmark',
    venueAddress: 'Victoria Island',
    state: 'Lagos',
    lga: 'Eti-Osa',
    expectedGuests: 120,
    categorySlug: 'wedding',
    eventAccessMode: EventAccessMode.privateInvitation,
    createdAt: DateTime(2026, 6, 1),
    updatedAt: DateTime(2026, 8, 18),
  );
}

void main() {
  testWidgets('event identity header tap opens callback', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: EosTheme.dark(),
        home: Scaffold(
          body: WorkspaceEntityHeader(
            logoText: 'T',
            name: 'Test Date',
            entityType: WorkspaceEntityType.event,
            plan: '',
            environment: 'draft',
            region: 'Lagos',
            primaryContact: 'host@owanbe.dev',
            createdDate: 'Jun 1, 2026',
            lastActivity: '1d ago',
            healthScore: 80,
            onIdentityTap: () => tapped = true,
          ),
        ),
      ),
    );
    expect(find.text('Test Date'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    await tester.tap(find.text('Test Date'));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('event header does not use hardcoded organizer email', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: EosTheme.dark(),
        home: const Scaffold(
          body: WorkspaceEntityHeader(
            logoText: 'T',
            name: 'Live Event',
            entityType: WorkspaceEntityType.event,
            plan: '',
            environment: 'published',
            region: 'Abuja',
            primaryContact: 'real@organizer.dev',
            createdDate: 'Jan 2, 2026',
            lastActivity: 'Just now',
            healthScore: 90,
          ),
        ),
      ),
    );
    expect(find.textContaining('organizer@owanbe.dev'), findsNothing);
    expect(find.textContaining('NG-LAGOS'), findsNothing);
    expect(find.textContaining('real@organizer.dev'), findsOneWidget);
    expect(find.textContaining('Abuja'), findsWidgets);
  });

  testWidgets('edit screen hydrates current event fields', (tester) async {
    final event = _event();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customerEventProvider('evt_edit').overrideWith((ref) async => event),
          eventCategoriesProvider.overrideWith(
            (ref) async => [
              const EventCategoryConfig(
                id: 'wedding',
                slug: 'wedding',
                label: 'Wedding',
                iconKey: 'heart',
                accessMode: EventAccessMode.privateInvitation,
              ),
            ],
          ),
        ],
        child: MaterialApp(
          theme: EosTheme.dark(),
          home: const CustomerEventEditScreen(eventId: 'evt_edit'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Event details'), findsWidgets);
    expect(find.text('Test Date'), findsWidgets);
    expect(find.text('Original description'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Victoria Island'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Victoria Island'), findsOneWidget);
    expect(find.text('Eti-Osa'), findsOneWidget);
  });
}
