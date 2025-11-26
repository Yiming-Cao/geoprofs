import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:supabase_flutter/supabase_flutter.dart';

class TeamPage extends StatelessWidget {
  const TeamPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      return const MobileLayout();
    }
    return const DesktopLayout(); // const mag hier weer, want we gebruiken geen late vars meer op widget-niveau
  }
}

class MobileLayout extends StatefulWidget {
  const MobileLayout({super.key});

  @override
  State<MobileLayout> createState() => _MobileLayoutState();
}

class _MobileLayoutState extends State<MobileLayout> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Team Page - Mobile')),
      body: const Center(
        child: Text(
          'Mobile layout for the Team Page.',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}

// Desktop layout
class DesktopLayout extends StatefulWidget {
  const DesktopLayout({super.key});

  @override
  State<DesktopLayout> createState() => _DesktopLayoutState();
}

class _DesktopLayoutState extends State<DesktopLayout> {
  late Future<String?> userRoleFuture;

  @override
  void initState() {
    super.initState();
    userRoleFuture = _getUserRole(); // nu een private methode
  }

  // Private methode (beter dan losse functie in de class)
  Future<String?> _getUserRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return 'Niet ingelogd';

    try {
      final response = await Supabase.instance.client
          .from('permissions')           // jouw tabel
          .select('role')                // kolom met de rol
          .eq('user_uuid', user.id)             // let op: id (uuid) van de user
          .maybeSingle();                // veiliger dan .single()

      return response?['role'] as String? ?? 'Geen rol gevonden';
    } catch (e) {
      // Bij geen rij of error → fallback
      return 'Fout bij ophalen rol $e';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Team Page - Desktop')),
      body: FutureBuilder<String?>(
        future: userRoleFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final role = snapshot.data ?? 'Onbekend';

          // Leuke rol-badge in kleur
          Color roleColor = Colors.grey;
          if (role.toLowerCase() == 'admin') roleColor = Colors.red;
          if (role.toLowerCase() == 'office_manager') roleColor = const Color.fromARGB(255, 140, 0, 255);
          if (role.toLowerCase() == 'manager') roleColor = Colors.orange;
          if (role.toLowerCase() == 'worker') roleColor = Colors.green;

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Ingelogd als:',
                  style: TextStyle(fontSize: 24),
                ),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: roleColor.withOpacity(0.2),
                    border: Border.all(color: roleColor, width: 2),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    role.toUpperCase(),
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: roleColor,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}