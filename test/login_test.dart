// test/login_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:geoprof/components/auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final auth = SupabaseAuth();

  // Initialize Supabase once before all tests
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

  // Sign out after each test to avoid session interference
  tearDown(() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      // Ignore errors during sign-out in teardown
    }
  });

  group('Supabase Login Security Tests', () {
    test('Normal login - should succeed', () async {
      final success = await auth.loginUser('test@example.com', 'w8woord123');
      expect(success, true, reason: 'Valid credentials must log in successfully');
    });

    test('Wrong password - should fail', () async {
      final success = await auth.loginUser('test@example.com', 'wrong123');
      expect(success, false, reason: 'Invalid password must be rejected');
    });

    test('Non-existent email - should fail (same behavior as wrong password to prevent enumeration)', () async {
      final success = await auth.loginUser('neverexists_12345@temp.com', 'any_password');
      expect(success, false, reason: 'Non-existent email must not leak existence information');
    });

    test('Empty email - should be rejected', () async {
      final success = await auth.loginUser('', '123456');
      expect(success, false);
    });

    test('Empty password - should be rejected', () async {
      final success = await auth.loginUser('test@example.com', '');
      expect(success, false);
    });

    test('SQL Injection attempt 1 - must be rejected', () async {
      final success = await auth.loginUser("' OR '1'='1", 'anything');
      expect(success, false);
    });

    test('SQL Injection attempt 2 - admin@--.com', () async {
      final success = await auth.loginUser('admin@--.com', 'anything');
      expect(success, false);
    });

    test('XSS payload in email - must be rejected', () async {
      final success = await auth.loginUser(
          "<script>alert('xss')</script>@evil.com", '123456');
      expect(success, false);
    });

    test('Extremely long email (500 chars) - should be rejected or safely handled', () async {
      final longEmail = '${'a' * 480}@toolong.com';
      final success = await auth.loginUser(longEmail, '123456');
      expect(success, false, reason: 'Supabase should reject oversized emails');
    });

    test('Special characters in email - should be handled safely', () async {
      final success = await auth.loginUser('!#\$%&()*+@weird.com', '123456');
      expect(success, false, reason: 'Most special chars are invalid in email local part');
    });

    test('Email with leading/trailing spaces - should still work if .trim() is used', () async {
      final success = await auth.loginUser('  test@example.com  ', 'w8woord123');
      expect(success, true,
          reason: 'If this fails → you forgot .trim() in login flow (common bug!)');
    });

    test('Case-insensitive email - Supabase normalizes to lowercase', () async {
      final success = await auth.loginUser('Test@Example.Com', 'w8woord123');
      expect(success, true, reason: 'Supabase treats emails as case-insensitive');
    });
  });

  // Bonus: Response time test (helps detect rate-limiting / DoS protection)
  test('Login endpoint response time - should be under 2 seconds', () async {
    final stopwatch = Stopwatch()..start();
    await auth.loginUser('fake@email.com', 'wrong');
    stopwatch.stop();
    expect(stopwatch.elapsedMilliseconds, lessThan(2000),
        reason: 'Slow responses can be exploited for DoS or brute-force attacks');
  });
}
