import 'package:flutter/material.dart';
import 'package:geoprof/pages/officemanager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geoprof/pages/admin.dart';
import 'package:geoprof/pages/home.dart';
import 'package:geoprof/pages/login.dart';
import 'package:geoprof/pages/profile.dart';
import 'package:geoprof/pages/verlof.dart';
import 'package:geoprof/pages/notification.dart';

Future<void> main() async {
  
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Supabase.initialize(
      url: 'https://jkvmrzfzmvqedynygkms.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imprdm1yemZ6bXZxZWR5bnlna21zIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTgwMjQyNDEsImV4cCI6MjA3MzYwMDI0MX0.APsSFMSpz1lDBrLWMFOC05_ic1eODAdCdceoh4SBPHY',
      
    );
    runApp(const MyApp());
  } catch (e) {
    debugPrint('Supabase initialization failed: $e');
    runApp(const ErrorApp(error: 'Failed to initialize Supabase. Please try again.'));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GeoProfs',
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const HomePage(),
        '/login': (context) => const LoginPage(),
        '/admin': (context) => const AdminPage(),
        '/profile': (context) => const ProfilePage(),
        '/verlof': (context) => const VerlofPage(),
        '/notifications': (context) => const NotificationPage(),
        '/officemanager':(context) => const OfficeManagerDashboard(),
      },
    );
  }
}

class ErrorApp extends StatelessWidget {
  final String error;
  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GeoProfs - Error',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Text(
            error,
            style: const TextStyle(color: Colors.red, fontSize: 18.0),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}