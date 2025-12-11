import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});

    await Supabase.initialize(
      url: 'https://jkvmrzfzmvqedynygkms.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imprdm1yemZ6bXZxZWR5bnlna21zIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTgwMjQyNDEsImV4cCI6MjA3MzYwMDI0MX0.APsSFMSpz1lDBrLWMFOC05_ic1eODAdCdceoh4SBPHY',
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
      ),
    );
  });

  tearDown(() async {
    await Supabase.instance.client.auth.signOut();
  });

  group('Verlof Fetch Tests - Authenticated (RLS works)', () {
    setUp(() async {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: 'test@example.com',
        password: 'w8woord123',
      );

      if (response.session == null) {
        fail('Login failed - check credentials or RLS policy');
      }

      print('Logged in as ${response.user?.email}');
    });

    test('Fetch all verlof records - should work with RLS', () async {
      final response = await Supabase.instance.client
          .from('verlof')
          .select();

      expect(response, isA<List>());
      print('Fetched ${response.length} verlof records (authenticated)');
    });

    test('Fetch first verlof record', () async {
      final row = await Supabase.instance.client
          .from('verlof')
          .select()
          .limit(1)
          .maybeSingle();

      if (row != null) {
        expect(row, isA<Map<String, dynamic>>());
        print('First record ID: ${row['id']}');
      } else {
        print('No verlof records found (table empty)');
      }
    });

    test('Fetch only current user\'s verlof', () async {
      final userId = Supabase.instance.client.auth.currentUser!.id;

      final records = await Supabase.instance.client
          .from('verlof')
          .select()
          .eq('user_id', userId);

      expect(records, isA<List>());
      print('Found ${records.length} records for current user');
    });
  });
}