import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geoprof/components/auth.dart';
import 'package:geoprof/pages/officemanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final auth = SupabaseAuth();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://jkvmrzfzmvqedynygkms.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imprdm1yemZ6bXZxZWR5bnlna21zIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTgwMjQyNDEsImV4cCI6MjA3MzYwMDI0MX0.APsSFMSpz1lDBrLWMFOC05_ic1eODAdCdceoh4SBPHY',
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
      ),
    );

    final SupabaseClient supabase = Supabase.instance.client;
  });

  tearDown(() async {
    if (Supabase.instance.client.auth.currentSession != null) {
      await Supabase.instance.client.auth.signOut();
    }
  });

  Future<List<Employee>> getUsers() async {
    final res = await Supabase.instance.client.functions.invoke('super-processor');

    if (res.data == null) {
      return [];
    }

    final data = res.data as Map<String, dynamic>;
    final List<dynamic> rawUsers = data['users'] ?? [];

    return rawUsers.map((u) {
      final map = Map<String, dynamic>.from(u);
      return Employee(uuid: map['id']?.toString() ?? '', name: map['user_metadata']?['display_name']?.toString() ?? '', role: map['role']?.toString() ?? '',email: map['email']?.toString() ?? '',);
    }).toList();
  }

  Future<bool> createUser(String email, String name, String role) async {
    try {
      final res = await Supabase.instance.client.functions.invoke('quick-api',body: {'email': email, 'name': name, 'role': role});
      return res.status >= 200 && res.status < 300;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteUser(String uuid) async {
    try {
      final res = await Supabase.instance.client.functions.invoke('dynamic-worker', body: {'user_id': uuid});
      return res.status >= 200 && res.status < 300;
    } catch (_) {
      return false;
    }
  }

  group('User creation test not logged in, as worker, as office manager and as office manager but with office manager role', () {
    test('Create user while not logged in', () async {
      final result = await createUser('tester123@gmail.com', 'tester224', 'worker');

      expect(result, isFalse);

      await auth.loginUser('test@officemanager.com', 'w8woord123');
      final users = await getUsers();

      expect(users.any((u) => u.name == 'tester224'), isFalse);
    });

    test('Create user while logged in as worker', () async {
      await auth.loginUser('test@example.com', 'w8woord123');

      final result = await createUser('tester123@gmail.com', 'tester224', 'worker');

      expect(result, isFalse);

      await Supabase.instance.client.auth.signOut();
      await auth.loginUser('test@officemanager.com', 'w8woord123');

      final users = await getUsers();
      expect(users.any((u) => u.name == 'tester224'), isFalse);
    });

    test('Create user while logged in as office manager', () async {
      await auth.loginUser('test@officemanager.com', 'w8woord123');

      final result = await createUser('tester123@gmail.com', 'tester224', 'worker');

      expect(result, isTrue);

      await Future.delayed(const Duration(seconds: 1));
      final users = await getUsers();
      final Employee user = users.firstWhere((u) => u.name == 'tester224');
      final userExists = user.uuid.isNotEmpty;
      expect(userExists, isTrue);
      expect(await deleteUser(user.uuid), isTrue);
      await Supabase.instance.client.auth.signOut();
    });

    test('Office manager cannot create another office manager', () async {
      await auth.loginUser('test@officemanager.com', 'w8woord123');

      final result = await createUser('tester224@gmail.com', 'tester224', 'office_manager');

      expect(result, isFalse);

      final users = await getUsers();
      expect(users.any((u) => u.name == 'tester224' && u.role == 'office_manager'), isFalse);

      await Supabase.instance.client.auth.signOut();
    });
  });
}