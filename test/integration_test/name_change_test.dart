import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geoprof/pages/profile.dart';

void main(){
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Mock shared_preferences + Initialize Supabase (with fake key to prevent real network requests)
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://jkvmrzfzmvqedynygkms.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imprdm1yemZ6bXZxZWR5bnlna21zIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTgwMjQyNDEsImV4cCI6MjA3MzYwMDI0MX0.APsSFMSpz1lDBrLWMFOC05_ic1eODAdCdceoh4SBPHY',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
    );
    // Ensure unauthenticated state
    await Supabase.instance.client.auth.signOut();
  });

  group('Profile Page – Name change test', () {
    testWidgets('Account Settings dialog shows Username field and default name when unauthenticated', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: MobileLayout())));
      await tester.pumpAndSettle();

      // Verify that the default display name is "User Name" for unauthenticated users
      expect(find.text('User Name'), findsOneWidget);

      // find settings icon and open dialog
      final settingsFinder = find.byIcon(Icons.settings);
      expect(settingsFinder, findsOneWidget);
      await tester.tap(settingsFinder);
      await tester.pumpAndSettle();

      expect(find.text('Account Settings'), findsOneWidget);
      // Verify that the Username field is present in the dialog
      expect(find.text('Username'), findsOneWidget);

      // Find the Username TextField and verify its default value is empty
      final usernameFieldFinder = find.byWidgetPredicate((w) => w is TextField && w.decoration is InputDecoration && (w.decoration as InputDecoration).labelText == 'Username');
      expect(usernameFieldFinder, findsOneWidget);

      final TextField usernameField = tester.widget<TextField>(usernameFieldFinder);
      // Verify that the default username is empty for unauthenticated users
      expect(usernameField.controller?.text ?? '', isEmpty);
    });
  });
}
