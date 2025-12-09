import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAuth {

  final supabase = Supabase.instance.client;
  
  Future<bool> loginUser(String email, String password) async {
    try {
      final AuthResponse res = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final User? user = res.user;
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

  void logoutUser() async {
    try {
      await supabase.auth.signOut();
      debugPrint('Logged out');
    } catch (e) {
      debugPrint('Error logging out: $e');
    }
  }
}