import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geoprof/main.dart';
import 'package:geoprof/pages/dashboard.dart';
import 'package:geoprof/pages/homepage.dart';
import 'package:geoprof/pages/login.dart';
import 'package:mockito/mockito.dart';

// Mock NavigatorObserver to track navigation
class MockNavigatorObserver extends Mock implements NavigatorObserver {}

void main() {
  // Ensure Flutter bindings are initialized for tests
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('MyApp Tests', () {
    testWidgets('MyApp renders MaterialApp with correct title and routes', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());

      // Verify MaterialApp is rendered
      expect(find.byType(MaterialApp), findsOneWidget);

      // Verify title
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.title, 'GeoProfs');

      // Verify debug banner is disabled
      expect(materialApp.debugShowCheckedModeBanner, false);

      // Verify initial route leads to HomeScreen
      expect(find.byType(Homepage), findsOneWidget);
    });
  });

  group('HomeScreen Tests', () {
    testWidgets('HomeScreen renders gradient background and logo', (WidgetTester tester) async {
      // Mock image loading for Image.asset
      await tester.pumpWidget(
        MaterialApp(
          home: const Homepage(),
        ),
      );

      // Verify Scaffold
      expect(find.byType(Scaffold), findsOneWidget);

      // Verify Container with gradient
      expect(find.byType(Container), findsOneWidget);
      final container = tester.widget<Container>(find.byType(Container));
      expect(container.decoration, isA<BoxDecoration>());
      final boxDecoration = container.decoration as BoxDecoration;
      expect(boxDecoration.gradient, isA<LinearGradient>());

      // Verify logo image
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('web/icons/geoprofs.png'), findsNothing); // Image.asset uses path, not text
    });

    testWidgets('HomeScreen renders navigation bar with correct icons', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const Homepage(),
        ),
      );

      // Verify navigation bar (Container in floatingActionButton)
      expect(find.byType(Container), findsAtLeastNWidgets(1));
      expect(find.byType(IconButton), findsNWidgets(5)); // 5 IconButtons
      expect(find.byIcon(Icons.calendar_today), findsOneWidget);
      expect(find.byIcon(Icons.person), findsOneWidget);
      expect(find.byIcon(Icons.home), findsOneWidget);
      expect(find.byIcon(Icons.mail), findsOneWidget);
      expect(find.byIcon(Icons.notifications), findsOneWidget);
    });
  });

  group('_onItemTapped Tests', () {
    testWidgets('_onItemTapped updates selectedIndex and navigates correctly', (WidgetTester tester) async {
      // Create a mock NavigatorObserver
      final mockObserver = MockNavigatorObserver();

      // Build HomeScreen with mocked routes
      await tester.pumpWidget(
        MaterialApp(
          home: const Homepage(),
          routes: {
            '/login': (context) => const LoginPage(),
            '/dashboard': (context) => const Dashboard(),
          },
          navigatorObservers: [mockObserver],
        ),
      );

      // Tap person icon (index 1)
      await tester.tap(find.byIcon(Icons.person));
      await tester.pumpAndSettle();

      // Verify navigation to /login
      verify(mockObserver.didPush(any as Route<dynamic>, any as Route<dynamic>?)).called(1);
      expect(find.byType(LoginPage), findsOneWidget);

      // Tap home icon (index 2)
      await tester.tap(find.byIcon(Icons.home));
      await tester.pumpAndSettle();

      // Verify navigation to /dashboard
      verify(mockObserver.didPush(any as Route<dynamic>, any as Route<dynamic>?)).called(1);
      expect(find.byType(Dashboard), findsOneWidget);
    });
  });
}