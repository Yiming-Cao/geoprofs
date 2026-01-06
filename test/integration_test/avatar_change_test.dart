import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geoprof/pages/profile.dart';
import 'package:geoprof/components/protected_route.dart';

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
  group('Profile Page – Avatar change test', () {
    testWidgets('Account Settings dialog shows Change Avatar and default avatar when unauthenticated', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: MobileLayout())));
      await tester.pumpAndSettle();

      // find settings icon and open dialog
      final settingsFinder = find.byIcon(Icons.settings);
      expect(settingsFinder, findsOneWidget);
      await tester.tap(settingsFinder);
      await tester.pumpAndSettle();

      expect(find.text('Account Settings'), findsOneWidget);
      expect(find.text('Change Avatar'), findsOneWidget);

      // find CircleAvatar in dialog (radius 36)
      final avatarFinder = find.byWidgetPredicate((w) => w is CircleAvatar && w.radius == 36);
      expect(avatarFinder, findsOneWidget);

      final CircleAvatar avatarWidget = tester.widget<CircleAvatar>(avatarFinder);
      final img = avatarWidget.backgroundImage;
      expect(img, isA<NetworkImage>());
      final NetworkImage ni = img as NetworkImage;
      expect(ni.url, contains('default_avatar.png'));
    });
  });
}