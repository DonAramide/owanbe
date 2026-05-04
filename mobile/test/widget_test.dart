import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:owanbe/app.dart';

void main() {
  testWidgets('Login screen shows Owanbe title', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: OwanbeApp()));
    await tester.pumpAndSettle();

    expect(find.text('Owanbe'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });
}
