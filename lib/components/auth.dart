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
  
  Future<bool> registerUser(String name, String email, String password) async {
    try {
      final AuthResponse res = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {'display_name': name},
      );
      final User? user = res.user;
      if (user != null) {
        debugPrint('Registered successfully: ${user.email}');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error registering user: $e');
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