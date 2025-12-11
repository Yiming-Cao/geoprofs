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
      authOptions: FlutterAuthClientOptions(
        autoRefreshToken: false,
      ),
    );
  });

  tearDown(() async {
    await Supabase.instance.client.auth.signOut();
  });

  group('Verlof Fetch Tests - Real Supabase (WORKS)', () {
    test('Fetch all verlof records', () async {
      final response = await Supabase.instance.client.from('verlof').select();

      expect(response, isA<List>());
      print('Fetched ${response.length} verlof records');
    });

    test('Fetch first verlof record', () async {
      final row = await Supabase.instance.client
          .from('verlof')
          .select()
          .limit(1)
          .single();

      expect(row, isA<Map<String, dynamic>>());
      print('First record ID: ${row['id']}');
    });
  });
}
