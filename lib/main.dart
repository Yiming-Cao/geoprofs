import 'package:flutter/material.dart';
import 'package:geoprof/pages/dashboard.dart';
import 'package:geoprof/pages/homepage.dart';
import 'package:geoprof/pages/login.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geoprof/pages/register.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://jkvmrzfzmvqedynygkms.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imprdm1yemZ6bXZxZWR5bnlna21zIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTgwMjQyNDEsImV4cCI6MjA3MzYwMDI0MX0.APsSFMSpz1lDBrLWMFOC05_ic1eODAdCdceoh4SBPHY',
  );
  runApp(const MyApp());
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
        '/': (context) => const Homepage(),
        '/login': (context) => const LoginPage(),
        '/dashboard': (context) => const Dashboard(),
        '/register': (context) => const RegisterPage(),
      },
    );
  }
}