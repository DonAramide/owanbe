import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:owambe/shared/widgets/unsaved_changes.dart';

void main() {
  testWidgets('unsaved changes dialog Stay does not discard', (tester) async {
    var discarded = false;
    final binder = UnsavedChangesBinder(
      isDirty: () => true,
      discard: () => discarded = true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => UnsavedChangesRegistry.confirmLeave(context, binder: binder),
            child: const Text('leave'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('leave'));
    await tester.pumpAndSettle();
    expect(find.text('You have unsaved changes.'), findsOneWidget);

    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(discarded, isFalse);
    expect(find.text('You have unsaved changes.'), findsNothing);
  });

  testWidgets('unsaved changes dialog Discard restores locally without implying save', (tester) async {
    var discarded = false;
    final binder = UnsavedChangesBinder(
      isDirty: () => true,
      discard: () => discarded = true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => UnsavedChangesRegistry.confirmLeave(context, binder: binder),
            child: const Text('leave'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('leave'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard Changes'));
    await tester.pumpAndSettle();
    expect(discarded, isTrue);
  });
}
