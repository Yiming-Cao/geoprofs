// test/team_page_widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geoprof/pages/team.dart'; // pas het pad aan als nodig

void main() {
  setUpAll(() async {
    WidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    await Supabase.initialize(
      url: 'https://fake.supabase.co',
      anonKey: 'fake',
      debug: false,
    );

    // Fake ingelogde gebruiker
    final fakeUser = User(
      id: 'user-123',
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
    );

    // Zet een nep gebruiker in de auth state (Supabase kijkt hiernaar)
    Supabase.instance.client.auth.onAuthStateChange.add(
      AuthState(AuthChangeEvent.signedIn, Session(accessToken: 'fake', user: fakeUser)),
    );
    Supabase.instance.client.auth.currentUser = fakeUser;
    Supabase.instance.client.auth.currentSession = Session(accessToken: 'fake', user: fakeUser);
  });

  group('TeamPage – DesktopLayout', () {

    testWidgets('toont rol + manager-team + teamleden na uitklappen', (tester) async {
      // Fake de database antwoorden
      final client = Supabase.instance.client;

      when(client.from('permissions').select('role').eq('user_uuid', 'user-123').maybeSingle())
          .thenAnswer((_) async => {'role': 'Office_manager'});

      when(client.from('teams').select()).thenAnswer((_) async => [
        {
          'id': 'team-1',
          'created_at': '2025-01-01T00:00:00Z',
          'users': ['user-123', 'user-456', 'user-789'],
          'manager': 'user-123',
        },
      ]);

      when(client.from('user_profiles').select('id, email, name').inFilter('id', any(named: 'id')))
          .thenAnswer((invocation) {
        final List<String> ids = invocation.namedArguments[#inFilter] ?? [];
        return ids.map((id) => {
          'id': id,
          'name': 'Naam van $id',
          'email': '$id@bedrijf.nl',
        }).toList();
      });

      await tester.pumpWidget(const MaterialApp(home: TeamPage()));
      await tester.pumpAndSettle(); // wacht op FutureBuilder

      // 1. Rol wordt getoond
      expect(find.textContaining('OFFICE_MANAGER'), findsOneWidget);

      // 2. Manager team sectie
      expect(find.text('Jij bent manager van:'), findsOneWidget);

      // 3. Teamkaart
      expect(find.text('Jouw team (3 leden)'), findsOneWidget);

      // 4. Uitklappen → teamleden zichtbaar
      await tester.tap(find.text('Jouw team (3 leden)'));
      await tester.pumpAndSettle();

      expect(find.text('Naam van user-123'), findsOneWidget);
      expect(find.text('JIJ'), findsOneWidget);           // huidige gebruiker
      expect(find.text('Manager'), findsOneWidget);
      expect(find.text('Naam van user-456'), findsOneWidget);

      //5. Refresh knop herlaadt data
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      expect(find.text('Jouw team (3 leden)'), findsOneWidget); // nog steeds daar
    });

    testWidgets('toont "Niet ingelogd" wanneer geen gebruiker', (tester) async {
      // Verwijder de fake user
      Supabase.instance.client.auth.currentUser = null;

      await tester.pumpWidget(const MaterialApp(home: TeamPage()));
      await tester.pumpAndSettle();

      expect(find.text('NIET INGELOGD'), findsOneWidget);
      expect(find.text('Je zit nog niet in een team'), findsOneWidget);
    });
  });
}