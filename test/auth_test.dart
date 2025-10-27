import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:geoprof/components/auth.dart';

void main() {
  setUpAll(() async {
    await Supabase.initialize(
      url: 'https://jkvmrzfzmvqedynygkms.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imprdm1yemZ6bXZxZWR5bnlna21zIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTgwMjQyNDEsImV4cCI6MjA3MzYwMDI0MX0.APsSFMSpz1lDBrLWMFOC05_ic1eODAdCdceoh4SBPHY',
    );
  });

  late SupabaseAuth auth = SupabaseAuth();

  test('Login with incorrect login information', () async {
    const testEmail = 'test_user@example.com';
    const testPassword = 'wrongpassword';
    final result = await auth.loginUser(testEmail, testPassword);

    expect(result, false);
    expect(Supabase.instance.client.auth.currentSession, isNull);
  });

  test('Login with correct login information', () async {
    const testEmail = '1207837@student.roc-nijmegen.nl';
    const testPassword = '1414ok!';
    final result = await auth.loginUser(testEmail, testPassword);

    expect(result, true);
    final user = Supabase.instance.client.auth.currentUser;
    debugPrint('Logged in user: ${user?.email}');
    expect(user?.email, testEmail);
  });

  test('Check session after login', () async {
    await auth.loginUser('1207837@student.roc-nijmegen.nl', '1414ok!');

    final expiresIn = Supabase.instance.client.auth.currentSession?.expiresIn;
    debugPrint('Session expires in: $expiresIn');
    expect(expiresIn, isNotNull);
  });

  test('Logout', () async {
    await auth.loginUser('1207837@student.roc-nijmegen.nl', '1414ok!');

    auth.logoutUser();
    final session = Supabase.instance.client.auth.currentSession;
    expect(session, isNull);
  });
}