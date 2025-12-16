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

  group('Verlof Tests - Create, Fetch, Delete (Authenticated)', () {
    late String currentUserId;

    setUp(() async {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: 'test@example.com',
        password: 'w8woord123',
      );

      if (response.session == null) {
        fail('Login failed - check credentials');
      }

      currentUserId = response.user!.id;
      print('Logged in as ${response.user?.email} (ID: $currentUserId)');
    });

    test('Create a new verlof record', () async {
      final now = DateTime.now();
      final start = now.toUtc().toIso8601String();
      final end = now.add(const Duration(days: 1)).toUtc().toIso8601String();

      final insertResponse = await Supabase.instance.client
          .from('verlof')
          .insert({
        'user_id': currentUserId,
        'start': start,
        'end_time': end,
        'reason': 'Test leave from integration test',
        'verlof_type': 'holiday',
        'verlof_state': 'pending',
        'days_count': 1,
      })
          .select()
          .single();

      expect(insertResponse['id'], isA<int>());
      expect(insertResponse['user_id'], currentUserId);
      expect(insertResponse['reason'], 'Test leave from integration test');

      print('Created verlof record with ID: ${insertResponse['id']}');
    });

    test('Create verlof and then delete it', () async {
      final created = await Supabase.instance.client
          .from('verlof')
          .insert({
        'user_id': currentUserId,
        'start': DateTime.now().toUtc().toIso8601String(),
        'end_time': DateTime.now().add(const Duration(days: 2)).toUtc().toIso8601String(),
        'reason': 'Test to be deleted',
        'verlof_type': 'personal',
        'verlof_state': 'pending',
        'days_count': 2,
      })
          .select()
          .single();

      final createdId = created['id'];
      print('Created record ID: $createdId');

      // Delete
      await Supabase.instance.client
          .from('verlof')
          .delete()
          .eq('id', createdId);

      // verify it's gone
      final deleted = await Supabase.instance.client
          .from('verlof')
          .select()
          .eq('id', createdId);

      expect(deleted, isEmpty);
      print('Record $createdId successfully deleted');
    });

    // Your existing fetch tests (optional)
    test('Fetch current user\'s verlof after creation', () async {
      final records = await Supabase.instance.client
          .from('verlof')
          .select()
          .eq('user_id', currentUserId);

      expect(records, isA<List>());
      print('User has ${records.length} verlof records');
    });
  });
}