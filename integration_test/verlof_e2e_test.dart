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

      // 1. Wait for login screen to fully load
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // 2. Enter email and password (focus fields first)
      final emailFinder = find.byKey(const Key('email_field'));
      final passwordFinder = find.byKey(const Key('password_field'));

      await tester.tap(emailFinder);
      await tester.pumpAndSettle();
      await tester.enterText(emailFinder, 'test@example.com');
      await tester.pumpAndSettle();

      await tester.tap(passwordFinder);
      await tester.pumpAndSettle();
      await tester.enterText(passwordFinder, 'w8woord123');
      await tester.pumpAndSettle();

      // 3. Tap login button
      await tester.tap(find.byKey(const Key('login_button')));
      await tester.pumpAndSettle(const Duration(seconds: 3)); // wait for navigation

      // 4. Navigate to Verlof page
      await tester.tap(find.text('Verlof'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // 5. Create verlof request
      // Tap Quick Type dropdown
      await tester.tap(find.text('Quick Type'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('holiday'));
      await tester.pumpAndSettle();

      // Pick start date
      await tester.tap(find.byKey(const Key('start_date_field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Pick end date (same day for simplicity)
      await tester.tap(find.byKey(const Key('end_date_field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Enter reason
      await tester.enterText(find.byKey(const Key('reason_field')), 'E2E test request');
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.textContaining('Request submitted successfully'), findsOneWidget);

      // 6. Delete the request
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

      // Login (same as above)
      final emailFinder = find.byKey(const Key('email_field'));
      final passwordFinder = find.byKey(const Key('password_field'));

      await tester.tap(emailFinder);
      await tester.enterText(emailFinder, 'test@example.com');
      await tester.pumpAndSettle();

      await tester.tap(passwordFinder);
      await tester.enterText(passwordFinder, 'w8woord123');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('login_button')));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Go to Verlof
      await tester.tap(find.text('Verlof'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Scroll to make Submit visible
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();

      // Try to submit empty form
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.textContaining('Please select start and end date'), findsOneWidget);
      expect(find.textContaining('Please select a type or enter a reason'), findsOneWidget);
    });
  });
}