import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geoprof/pages/profile.dart';

void main(){
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Mock shared_preferences + 初始化 Supabase（用假 key，防止真实网络请求）
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://jkvmrzfzmvqedynygkms.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imprdm1yemZ6bXZxZWR5bnlna21zIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTgwMjQyNDEsImV4cCI6MjA3MzYwMDI0MX0.APsSFMSpz1lDBrLWMFOC05_ic1eODAdCdceoh4SBPHY',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
    );
    // 确保未登录状态
    await Supabase.instance.client.auth.signOut();
  });

  group('Profile Page – Leave view test', () {
    testWidgets('Selecting Leave shows empty state when unauthenticated', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: MobileLayout())));
      await tester.pumpAndSettle();

      // Tap the Leave sidebar item
      final leaveFinder = find.text('Leave');
      expect(leaveFinder, findsOneWidget);
      await tester.tap(leaveFinder);
      await tester.pumpAndSettle();

      // Should show the empty state message
      expect(find.text('No leave requests found.'), findsOneWidget);
    });
  });
}
