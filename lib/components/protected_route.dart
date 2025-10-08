import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProtectedRoute extends StatelessWidget {
  final Widget child;
  const ProtectedRoute({super.key, required this.child});

  @override
  Widget build(BuildContext context) {

    final expiresIn = Supabase.instance.client.auth.currentSession?.expiresIn;
    if (expiresIn == null || expiresIn <= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushNamed(context, '/login');
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return child;
  }
}