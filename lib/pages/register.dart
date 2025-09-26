import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.android || 
    defaultTargetPlatform == TargetPlatform.iOS) {
      return const MobileLayout();
    } else {
      return const DesktopLayout();
    }
  }
}

class MobileLayout extends StatelessWidget {
  const MobileLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Register Page',
                style: TextStyle(fontSize: 24),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/');
                },
                child: const Text('Back to Home'),
              ),
            ],
          ),
        ),
    );
  }
}

class DesktopLayout extends StatelessWidget {
  const DesktopLayout({super.key});

  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Register Page',
                style: TextStyle(fontSize: 24),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/');
                },
                child: const Text('Back to Home'),
              ),
            ],
          ),
        ),
    );
  }
}