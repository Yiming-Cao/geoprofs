import 'package:flutter/material.dart';
import 'package:geoprof/pages/dashboard.dart';
import 'package:geoprof/pages/login.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:geoprof/pages/register.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://jkvmrzfzmvqedynygkms.supabase.co',  // Supabase URL
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imprdm1yemZ6bXZxZWR5bnlna21zIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTgwMjQyNDEsImV4cCI6MjA3MzYwMDI0MX0.APsSFMSpz1lDBrLWMFOC05_ic1eODAdCdceoh4SBPHY',             // Supabase anon key
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GeoProfs',
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/dashboard': (context) => const Dashboard(),
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,  
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFEE6055),
              Color(0xFFFFFFFF),
            ],
            stops: [0.25, 1.0],
          ),
        ),
        child: Column(
          children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Image.asset(
                    "web/icons/geoprofs.png",
                    height: 50,
                  ),
                ),
              ),
            ),

            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text('You have pushed the button ${_counter > 100 ? 'too' : 'this'} many times:'),
                    Text(
                      '$_counter',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/dashboard');
                      },
                      child: const Text("Go to dashboard"),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/login');
                      },
                      child: const Text("Go to login"),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}