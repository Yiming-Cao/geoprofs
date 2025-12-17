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
      final res = await Supabase.instance.client.functions.invoke('quick-api', body: {'email': email, 'name': name, 'role': role});
      return res.status >= 200 && res.status < 300;
    } catch (_) {
      return false;
    }
  }

    Future<bool> updateUser({required String uuid, String? email, String? name, String? role}) async {
      try {
      final body = <String, dynamic>{};
      body['user_id'] = uuid;
      if (email != null) body['email'] = email;
      if (name != null) body['name'] = name;
      if (role != null) body['role'] = role;
      
      final res = await Supabase.instance.client.functions.invoke('super-api', body: body);
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
      // try to create user
      final result = await createUser('tester123@gmail.com', 'tester224', 'worker');

      expect(result, isFalse);

      // check if user exists
      await auth.loginUser('test@officemanager.com', 'w8woord123');
      final users = await getUsers();

      expect(users.any((u) => u.name == 'tester224'), isFalse);
    });

    test('Create user while logged in as worker', () async {
      await auth.loginUser('test@example.com', 'w8woord123');
      // try to create user
      final result = await createUser('tester123@gmail.com', 'tester224', 'worker');

      expect(result, isFalse);

      // check if user exists
      await Supabase.instance.client.auth.signOut();
      await auth.loginUser('test@officemanager.com', 'w8woord123');

      final users = await getUsers();
      expect(users.any((u) => u.name == 'tester224'), isFalse);
    });

    test('Create user while logged in as office manager', () async {
      await auth.loginUser('test@officemanager.com', 'w8woord123');
      // try to create user

      final result = await createUser('tester123@gmail.com', 'tester224', 'worker');
      expect(result, isTrue);

      // check if user exists
      await Future.delayed(const Duration(milliseconds: 100));
      final users = await getUsers();
      final Employee user = users.firstWhere((u) => u.name == 'tester224');
      final userExists = user.uuid.isNotEmpty;
      expect(userExists, isTrue);
      expect(await deleteUser(user.uuid), isTrue);
      await Supabase.instance.client.auth.signOut();
    });

    test('Office manager cannot create another office manager', () async {
      await auth.loginUser('test@officemanager.com', 'w8woord123');
      // try to create user
      final result = await createUser('tester224@gmail.com', 'tester224', 'office_manager');
      expect(result, isFalse);
      await Future.delayed(const Duration(milliseconds: 100));

      // check if user exists
      final users = await getUsers();
      expect(users.any((u) => u.name == 'tester224' && u.role == 'office_manager'), isFalse);

      await Supabase.instance.client.auth.signOut();
    });
  });



  group('User delete test not logged in, as worker, as office manager and as office manager but with office manager role', () {
    test('Delete user while not logged in', () async {
      // try to delete user
      bool result = await deleteUser('8b65ba2e-ba61-48af-bf44-a0093bdde34e');
      expect(result, isFalse);
      await Supabase.instance.client.auth.signOut();
      await Future.delayed(const Duration(milliseconds: 100));

      await auth.loginUser('test@officemanager.com', 'w8woord123');

      // is deleted?
      final users = await getUsers();
      expect(users.any((u) => u.uuid == '8b65ba2e-ba61-48af-bf44-a0093bdde34e'), isFalse);
    });

    test('Delete user while logged in as worker', () async {
      await auth.loginUser('test@example.com', 'w8woord123');
      // try to delete user
      bool result = await deleteUser('8b65ba2e-ba61-48af-bf44-a0093bdde34e');
      expect(result, isFalse);

      await Supabase.instance.client.auth.signOut();
      await Future.delayed(const Duration(milliseconds: 100));
      
      await auth.loginUser('test@officemanager.com', 'w8woord123');

      // is deleted?
      final users = await getUsers();
      expect(users.any((u) => u.uuid == '8b65ba2e-ba61-48af-bf44-a0093bdde34e'), isFalse);
    });

    test('Delete user while logged in as office manager', () async {
      await auth.loginUser('test@officemanager.com', 'w8woord123');
      // create user to delete
      final createResult = await createUser('tester123@gmail.com', 'tester224', 'worker');
      expect(createResult, isTrue);
      await Future.delayed(const Duration(milliseconds: 100));

      // find id to delete
      final users = await getUsers();
      final Employee user = users.firstWhere((u) => u.name == 'tester224');
      final bool result = await deleteUser(user.uuid);
      expect(result, isTrue);
      await Future.delayed(const Duration(milliseconds: 100));

      // is deleted?
      final usersAfterDelete = await getUsers();
      final bool userWasDeleted = !usersAfterDelete.any((u) => u.name == 'tester224');
      expect(userWasDeleted, isTrue);
      await Supabase.instance.client.auth.signOut();
    });

    test('Delete office manager as office manager', () async {
      await auth.loginUser('test@officemanager.com', 'w8woord123');
      // try to delete office manager (self)
      bool result = await deleteUser('8b65ba2e-ba61-48af-bf44-a0093bdde34e');
      expect(result, isFalse);
      await Future.delayed(const Duration(milliseconds: 100));
      await Supabase.instance.client.auth.signOut();

      // is deleted?
      final login = await auth.loginUser('test@officemanager.com', 'w8woord123');
      expect(login, true);
      await Supabase.instance.client.auth.signOut();
    });
  });
  
  
  
  group('User update test not logged in, as worker, as office manager and as office manager but with office manager role', () {
    test('Update user while not logged in', () async {
      // try to update user
      bool result = await updateUser(uuid: '84048ee0-09bc-4a6a-b3ef-f28c4b392ec2', email: 'test2@example.com', name: 'login-test12', role: 'worker');
      expect(result, isFalse);
      await Supabase.instance.client.auth.signOut();
      await Future.delayed(const Duration(milliseconds: 100));

      await auth.loginUser('test@officemanager.com', 'w8woord123');

      // is updated?
      final users = await getUsers();
      final Employee user = users.firstWhere((u) => u.uuid == '84048ee0-09bc-4a6a-b3ef-f28c4b392ec2');
      expect(user.name == 'login-test12', isFalse);
    });

    test('Update user while logged in as worker', () async {
      await auth.loginUser('test@example.com', 'w8woord123');
      // try to update user
      bool result = await updateUser(uuid: '84048ee0-09bc-4a6a-b3ef-f28c4b392ec2', email: 'test2@example.com', name: 'login-test12', role: 'worker');
      expect(result, isFalse);

      await Supabase.instance.client.auth.signOut();
      await Future.delayed(const Duration(milliseconds: 100));
      
      await auth.loginUser('test@officemanager.com', 'w8woord123');

      final users = await getUsers();
      final Employee user = users.firstWhere((u) => u.uuid == '84048ee0-09bc-4a6a-b3ef-f28c4b392ec2');
      expect(user.name == 'login-test12', isFalse);
    });

    test('Update user while logged in as office manager', () async {
      await auth.loginUser('test@officemanager.com', 'w8woord123');
      // create user to update
      final createResult = await createUser('tester123@gmail.com', 'tester224', 'worker');
      expect(createResult, isTrue);
      await Future.delayed(const Duration(milliseconds: 100));

      // find id to update
      final users = await getUsers();
      final Employee user = users.firstWhere((u) => u.name == 'tester224');
      final bool result = await updateUser(uuid: user.uuid, email: 'test2@example.com', name: 'tester224', role: 'worker');
      expect(result, isTrue);
      await Future.delayed(const Duration(milliseconds: 100));

      // is updated?
      final usersAfterUpdate = await getUsers();
      final bool userWasUpdated = usersAfterUpdate.any((u) => u.name == 'tester224');
      expect(userWasUpdated, isTrue);
      
      await deleteUser(user.uuid);
      await Supabase.instance.client.auth.signOut();
    });

    test('Update user while logged in as office manager but set role to office manager', () async {
      await auth.loginUser('test@officemanager.com', 'w8woord123');
      // create user to update
      final createResult = await createUser('tester123@gmail.com', 'tester224', 'worker');
      expect(createResult, isTrue);
      await Future.delayed(const Duration(milliseconds: 100));

      // find id to update
      final users = await getUsers();
      final Employee user = users.firstWhere((u) => u.name == 'tester224');
      final bool result = await updateUser(uuid: user.uuid, role: 'office_manager');
      expect(result, isFalse);
      await Future.delayed(const Duration(milliseconds: 100));

      // is updated?
      final usersAfterUpdate = await getUsers();
      final bool userWasUpdated = usersAfterUpdate.any((u) => u.name == 'tester2422');
      expect(userWasUpdated, isFalse);
      
      await deleteUser(user.uuid);
      await Supabase.instance.client.auth.signOut();
    });

    test('Update office manager as office manager', () async {
      await auth.loginUser('test@officemanager.com', 'w8woord123');
      // try to update office manager (self)
      bool result = await updateUser(uuid: '8b65ba2e-ba61-48af-bf44-a0093bdde34e', email: 'test2@officemanager.com', name: 'officemanager-test12', role: 'worker');
      expect(result, isFalse);
      await Future.delayed(const Duration(milliseconds: 100));
      await Supabase.instance.client.auth.signOut();

      // is updated?
      final login = await auth.loginUser('test@officemanager.com', 'w8woord123');
      expect(login, true);
      await Supabase.instance.client.auth.signOut();
    });
  });
}