import 'package:flutter/foundation.dart' show kDebugMode, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:geoprof/main.dart' as app;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  if (defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux) {
    SharedPreferences.setMockInitialValues({});
    print('[Desktop: shared_preferences mocked');
  }

  group('Admin Audit Trail E2E Tests', () {
    Future<void> _loginAsAdmin(WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 12));

      await Supabase.instance.client.auth.signOut();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      if (find.byKey(const Key('admin_page')).evaluate().isNotEmpty) {
        print('Al op Admin pagina - skip login');
        return;
      }

      final loginLink = find.text('Login');
      if (loginLink.evaluate().isEmpty) {
        fail('Login link niet gevonden en niet al ingelogd');
      }
      await tester.tap(loginLink);
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.enterText(find.byKey(const Key('email_field')), 'test@example.com'); // ← PAS AAN: je admin email
      await tester.enterText(find.byKey(const Key('password_field')), 'w8woord123'); // ← PAS AAN: admin wachtwoord
      await tester.tap(find.byKey(const Key('login_button')));
      await tester.pumpAndSettle(const Duration(seconds: 20));

      expect(find.byKey(const Key('admin_page')), findsOneWidget, reason: 'Admin pagina niet geladen na login');
    }
  }
  );
  }