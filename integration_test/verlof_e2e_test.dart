import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:geoprof/main.dart' as app;
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Verlof E2E Tests - Happy & Unhappy Flow', () {
    Future<void> _loginAndReachVerlof(WidgetTester tester) async {
      app.main();

      // Force sign out → ensure "Login" link
      await Supabase.instance.client.auth.signOut();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await tester.pumpAndSettle(const Duration(seconds: 12));

      final loginLink = find.text('Login');
      if (loginLink.evaluate().isEmpty) {
        print('Warning: Login link not found - checking current user');
        print('Current user: ${Supabase.instance.client.auth.currentUser?.email ?? "null"}');
      }
      expect(loginLink, findsOneWidget, reason: 'Login link not found after signOut');

      await tester.ensureVisible(loginLink);
      await tester.tap(loginLink);
      await tester.pumpAndSettle(const Duration(seconds: 8));

      expect(find.byKey(const Key('email_field')), findsOneWidget, reason: 'Login form not loaded');

      // Fill & submit login
      await tester.tap(find.byKey(const Key('email_field')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('email_field')), 'test@example.com');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('password_field')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('password_field')), 'w8woord123');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('login_button')));
      await tester.pumpAndSettle(const Duration(seconds: 15)); // long wait for auth + redirect + fetch

      // Confirm Verlof page
      expect(find.text('New Leave Request'), findsOneWidget, reason: 'Not on Verlof page');
      expect(find.byKey(const Key('reason_field')), findsOneWidget);
    }

    testWidgets('Happy flow: Create and delete verlof request', (tester) async {
      await _loginAndReachVerlof(tester);

      // Scroll to top of form if needed
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, 600));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Ensure Quick Type is visible & tap it
      final quickType = find.text('Quick Type');
      await tester.ensureVisible(quickType);
      await tester.tap(quickType);
      await tester.pumpAndSettle(const Duration(seconds: 4)); // wait for dropdown overlay

      // Tap 'holiday' (may be in overlay — increase settle time)
      final holiday = find.text('holiday').last; // .last in case multiple
      await tester.ensureVisible(holiday);
      await tester.tap(holiday);
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Dates
      await tester.tap(find.byKey(const Key('start_date_field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('end_date_field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Reason
      await tester.enterText(find.byKey(const Key('reason_field')), 'E2E test request');
      await tester.pumpAndSettle();

      // Scroll to bottom for Submit
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -1200));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle(const Duration(seconds: 8));

      expect(find.textContaining('Request submitted successfully'), findsOneWidget);

      // Delete (long press on reason text)
      await tester.longPress(find.textContaining('E2E test request'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Request deleted'), findsOneWidget);
    });

    testWidgets('Unhappy flow: Submit empty form', (tester) async {
      await _loginAndReachVerlof(tester);

      // Clear any pre-filled fields
      await tester.enterText(find.byKey(const Key('reason_field')), '');
      await tester.pumpAndSettle();

      // Scroll to Submit
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -1000));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle(const Duration(seconds: 8)); // longer for snackbar animation

      // Check errors (exact strings from your _submitRequest)
      expect(
        find.textContaining('Please select start and end date'),
        findsOneWidget,
        reason: 'No start/end date error',
      );
      expect(
        find.textContaining('Please select a type or enter a reason'),
        findsOneWidget,
        reason: 'No type/reason error',
      );
    });
  });
}