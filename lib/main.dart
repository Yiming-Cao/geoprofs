import 'package:flutter/material.dart';
import 'package:geoprof/components/auth.dart';
import 'package:geoprof/pages/dashboard.dart';
import 'package:geoprof/pages/login.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geoprof/pages/register.dart';
import 'package:geoprof/pages/profile.dart';

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
        '/': (context) => const HomeScreen(),
        '/login': (context) => const LoginPage(),
        '/dashboard': (context) => const Dashboard(),
        '/register': (context) => const RegisterPage(),
        '/profile': (context) => const ProfilePage(),
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
  int _selectedIndex = 0;
  final supabaseAuth = SupabaseAuth();

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 1) {
      Navigator.pushNamed(context, '/login');
    } else if (index == 2) {
      Navigator.pushNamed(context, '/dashboard');
    }
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
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Center(
                        child: Image.asset(
                          "web/icons/geoprofs.png",
                          height: 50,
                        ),
                      ),
                    ),
                    // login button or avatar
                    FutureBuilder(
                      future: Future.value(Supabase.instance.client.auth.currentUser),
                      builder: (context, snapshot) {
                        final user = snapshot.data;
                        if (user == null) {
                          // not logged in, show login button
                          return GestureDetector(
                            onTap: () {
                              Navigator.pushNamed(context, '/login');
                            },
                            child: const Padding(
                              padding: EdgeInsets.only(right: 8.0, top: 8.0),
                              child: Text(
                                'Login',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 18,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          );
                        } else {
                          final avatarUrl = user.userMetadata?['avatar_url'] as String?;
                          final defaultAvatar =
                              'https://jkvmrzfzmvqedynygkms.supabase.co/storage/v1/object/public/assets/images/default_avatar.png';
                          return GestureDetector(
                            onTap: () {
                              Navigator.pushNamed(context, '/profile');
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8.0, top: 4.0),
                              child: CircleAvatar(
                                radius: 20,
                                backgroundImage: NetworkImage(
                                  avatarUrl?.isNotEmpty == true ? avatarUrl! : defaultAvatar,
                                ),
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const Expanded(
              child: Center(),
            ),
          ],
        ),
      ),
      floatingActionButton: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.calendar_today),
              color: _selectedIndex == 0 ? const Color(0xFFEE6055) : Colors.white,
              onPressed: () => _onItemTapped(0),
            ),
            IconButton(
              icon: const Icon(Icons.person),
              color: _selectedIndex == 1 ? const Color(0xFFEE6055) : Colors.white,
              onPressed: () => _onItemTapped(1),
            ),
            Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(
                color: Color(0xFFEE6055),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.home, size: 30),
                color: Colors.white,
                onPressed: () => _onItemTapped(2),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.mail),
              color: _selectedIndex == 3 ? const Color(0xFFEE6055) : Colors.white,
              onPressed: () => _onItemTapped(3),
            ),
            IconButton(
              icon: const Icon(Icons.notifications),
              color: _selectedIndex == 4 ? const Color(0xFFEE6055) : Colors.white,
              onPressed: () => _onItemTapped(4),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}