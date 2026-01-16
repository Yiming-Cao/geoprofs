import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:geoprof/main.dart' as app;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Desktop mock (prevents MissingPluginException)
  if (defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux) {
    SharedPreferences.setMockInitialValues({});
    print('[E2E] Desktop: shared_preferences mocked');
  }

  group('Verlof E2E Tests - Minimal Working Parts', () {
    Future<void> _ensureOnVerlofPage(WidgetTester tester) async {
      app.main();

      await tester.pumpAndSettle(const Duration(seconds: 12));

      // Force sign out
      await Supabase.instance.client.auth.signOut();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Check if already on Verlof page (skip login)
      if (find.text('New Leave Request').evaluate().isNotEmpty ||
          find.byKey(const Key('reason_field')).evaluate().isNotEmpty) {
        print('[E2E] Al op Verlof pagina — login skip');
        return;
      }

      // Login if needed
      final loginLink = find.text('Login');
      if (loginLink.evaluate().isEmpty) {
        print('Warning: Login link niet gevonden. Current user: ${Supabase.instance.client.auth.currentUser?.email ?? "geen"}');
        fail('Stuck - neither Login nor Verlof page found');
      }

      await tester.ensureVisible(loginLink);
      await tester.tap(loginLink);
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.enterText(find.byKey(const Key('email_field')), 'test@example.com');
      await tester.enterText(find.byKey(const Key('password_field')), 'w8woord123');
      await tester.tap(find.byKey(const Key('login_button')));
      await tester.pumpAndSettle(const Duration(seconds: 20));

      expect(find.text('New Leave Request'), findsOneWidget, reason: 'Niet op Verlof pagina');
    }

    testWidgets('Working part 1: Dropdown tap + create verlof (happy)', (tester) async {
      await _ensureOnVerlofPage(tester);

      // Scroll to form (more aggressive for desktop)
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -800));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Dropdown tap (Quick Type → holiday)
      final quickType = find.text('Quick Type');
      await tester.ensureVisible(quickType);
      await tester.tap(quickType, warnIfMissed: false);
      await tester.pumpAndSettle(const Duration(seconds: 5));

      final holiday = find.text('holiday');
      await tester.ensureVisible(holiday);
      await tester.tap(holiday, warnIfMissed: false);
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Fill reason
      await tester.enterText(find.byKey(const Key('reason_field')), 'E2E dropdown test');
      await tester.pumpAndSettle();

      // Scroll to Submit
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -1400));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Submit
      await tester.tap(find.byKey(const Key('submit_button')), warnIfMissed: false);
      await tester.pumpAndSettle(const Duration(seconds: 12));

      expect(find.textContaining('Request submitted successfully'), findsOneWidget);
    });

    testWidgets('Working part 2: Submit empty form (unhappy)', (tester) async {
      await _ensureOnVerlofPage(tester);

      // Scroll to Submit
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -1400));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Submit empty
      await tester.tap(find.byKey(const Key('submit_button')), warnIfMissed: false);
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(
        find.textContaining('Please select start and end date'),
        findsOneWidget,
        reason: 'Geen datum foutmelding',
      );

      expect(
        find.textContaining('Please select a type or enter a reason'),
        findsOneWidget,
        reason: 'Geen type/reden foutmelding',
      );
    });
  });
}