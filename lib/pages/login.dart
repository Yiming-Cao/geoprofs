import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:supabase_flutter/supabase_flutter.dart';


class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

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
                'Login Page',
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

  Future<String> _getImageUrl() async {
    final response = await Supabase.instance.client.storage
        .from('Image')
        .createSignedUrl('welcome.png', 60); // URL valid for 60 seconds
    return response;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<String>(
        future: _getImageUrl(),
        builder: (context, snapshot) {
          Widget imageWidget;
          if (snapshot.connectionState == ConnectionState.waiting) {
            imageWidget = const SizedBox(
              width: 400,
              height: 400,
              child: Center(child: CircularProgressIndicator()),
            );
          } else if (snapshot.hasError || !snapshot.hasData) {
            imageWidget = const SizedBox(
              width: 400,
              height: 400,
              child: Center(child: Icon(Icons.broken_image, size: 64)),
            );
          } else {
            imageWidget = ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.network(
                snapshot.data!,
                width: 400,
                height: 400,
                fit: BoxFit.cover,
              ),
            );
          }

          return Row(
            children: [
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: imageWidget,
                ),
              ),
              Expanded(
                flex: 3,
                child: Center(
                  child: SizedBox(
                    width: 400,
                    child: Card(
                      elevation: 0,
                      color: Colors.transparent,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Login',
                              style: TextStyle(
                                fontFamily: 'DancingScript',
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 32),
                            const Text(
                              'Email',
                              style: TextStyle(
                                fontFamily: 'DancingScript',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              decoration: InputDecoration(
                                prefixIcon: Icon(Icons.email_outlined),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Password',
                              style: TextStyle(
                                fontFamily: 'DancingScript',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              obscureText: true,
                              decoration: InputDecoration(
                                prefixIcon: Icon(Icons.lock_outline),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {},
                                child: const Text(
                                  'Forgot Password?',
                                  style: TextStyle(color: Colors.redAccent),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                ),
                                onPressed: () {},
                                child: const Text(
                                  'Login',
                                  style: TextStyle(fontSize: 20),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Center(
                              child: TextButton(
                                onPressed: () {},
                                child: const Text(
                                  "Don't have an account yet? Sign up here",
                                  style: TextStyle(color: Colors.redAccent),
                                ),
                              ),
                            ),
                          ]
                        ),
                      ),
                    ),
                  ),
                ),   
              ),
            ],
          );
        },
      ),
    );
  }
}

        