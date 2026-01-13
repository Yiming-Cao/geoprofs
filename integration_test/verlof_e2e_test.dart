import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:geoprof/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Verlof E2E Tests - Happy & Unhappy Flow', () {
    Future<void> _goToLogin(WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 10)); // wait for home/welcome

      // Tap the "Login" link in the header (from HeaderBar)
      final loginLink = find.text('Login');
      expect(loginLink, findsOneWidget, reason: 'Login link in header not found - stuck on wrong screen?');

      await tester.tap(loginLink);
      await tester.pumpAndSettle(const Duration(seconds: 6)); // wait for navigation to LoginPage

      // Safety check: make sure we reached the real login form
      expect(find.byKey(const Key('email_field')), findsOneWidget, reason: 'Did not reach login page');
    }

    testWidgets('Happy flow: Create and delete verlof request', (tester) async {
      await _goToLogin(tester);

      // Fill form using your real keys
      await tester.tap(find.byKey(const Key('email_field')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('email_field')), 'test@example.com');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('password_field')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('password_field')), 'w8woord123');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('login_button')));
      await tester.pumpAndSettle(const Duration(seconds: 8)); // auth + redirect

      await tester.tap(find.text('Verlof'));
      await tester.pumpAndSettle(const Duration(seconds: 4));

      await tester.tap(find.text('Quick Type'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('holiday'));
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
      await tester.pumpAndSettle();

      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -700));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.textContaining('Request submitted successfully'), findsOneWidget);

      await tester.longPress(find.textContaining('E2E test request'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Request deleted'), findsOneWidget);
    });

    testWidgets('Unhappy flow: Submit empty form', (tester) async {
      await _goToLogin(tester);

      await tester.tap(find.byKey(const Key('email_field')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('email_field')), 'test@example.com');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('password_field')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('password_field')), 'w8woord123');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('login_button')));
      await tester.pumpAndSettle(const Duration(seconds: 8));

      await tester.tap(find.text('Verlof'));
      await tester.pumpAndSettle(const Duration(seconds: 4));

      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -600));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.textContaining('Please select start and end date'), findsOneWidget);
      expect(find.textContaining('Please select a type or enter a reason'), findsOneWidget);
    });
  });
}