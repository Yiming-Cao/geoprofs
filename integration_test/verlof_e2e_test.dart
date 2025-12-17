import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:geoprof/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Verlof E2E Tests - Happy & Unhappy Flow', () {
    testWidgets('Happy flow: Create and delete verlof request', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // 1. Login
      await tester.enterText(find.byKey(const Key('email_field')), 'test@example.com');
      await tester.enterText(find.byKey(const Key('password_field')), 'w8woord123');
      await tester.tap(find.byKey(const Key('login_button')));
      await tester.pumpAndSettle();

      // Navigate to Verlof page
      await tester.tap(find.text('Verlof'));
      await tester.pumpAndSettle();

      // 2. Create verlof (happy flow)
      await tester.tap(find.text('Quick Type'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('holiday').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('start_date_field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('end_date_field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('reason_field')), 'E2E test request');
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Request submitted successfully'), findsOneWidget);

      // 3. Delete it
      await tester.longPress(find.textContaining('E2E test request'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete')); // confirm
      await tester.pumpAndSettle();

      expect(find.textContaining('Request deleted'), findsOneWidget);
    });

    testWidgets('Unhappy flow: Submit empty form', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Login
      await tester.enterText(find.byKey(const Key('email_field')), 'test@example.com');
      await tester.enterText(find.byKey(const Key('password_field')), 'w8woord123');
      await tester.tap(find.byKey(const Key('login_button')));
      await tester.pumpAndSettle();

      // Go to verlof
      await tester.tap(find.text('Verlof'));
      await tester.pumpAndSettle();

      // Submit empty
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Please select start and end date'), findsOneWidget);
      expect(find.textContaining('Please select a type or enter a reason'), findsOneWidget);
    });
  });
}