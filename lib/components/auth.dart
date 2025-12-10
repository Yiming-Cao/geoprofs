// lib/components/auth.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAuth {
  // Remove the direct initialization here
  // final supabase = Supabase.instance.client;   ← This line caused the crash in tests

  // Use a lazy getter instead — safe even if initialize() hasn't finished yet
  SupabaseClient get _client => Supabase.instance.client;

  Future<bool> loginUser(String email, String password) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      final user = response.user;
      if (user != null) {
        debugPrint('Login successful: ${user.email}');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error logging in: $e');
      return false;
    }
  }

  Future<void> logoutUser() async {
    try {
      await _client.auth.signOut();
      debugPrint('Logged out successfully');
    } catch (e) {
      debugPrint('Error logging out: $e');
    }
  }

  // Optional helpers you might find useful later
  User? get currentUser => _client.auth.currentUser;
  Session? get currentSession => _client.auth.currentSession;
}