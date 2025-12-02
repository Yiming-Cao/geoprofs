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
    return const DesktopLayout();
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
      body: const Center(child: Text('Mobile komt later')),
    );
  }
}

class DesktopLayout extends StatefulWidget {
  const DesktopLayout({super.key});
  @override
  State<DesktopLayout> createState() => _DesktopLayoutState();
}

class _DesktopLayoutState extends State<DesktopLayout> {
  late final Future<Map<String, dynamic>> teamInfoFuture;

  @override
  void initState() {
    super.initState();
    teamInfoFuture = _loadTeamInfo();
  }

  Future<Map<String, dynamic>> _loadTeamInfo() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return {
        'role': 'Niet ingelogd',
        'isManager': false,
        'managers': <Map<String, String>>[],
      };
    }

    final userId = user.id;
    final roleData = await Supabase.instance.client
        .from('permissions')
        .select('role')
        .eq('user_uuid', userId)
        .maybeSingle();

    final String role = roleData?['role'] ?? 'Geen rol gevonden';

    
    final teamData = await Supabase.instance.client
        .from('teams')
        .select('manager')             
        .eq('id', userId)             
        .maybeSingle();

    bool isManager = false;
    List<Map<String, String>> managersList = [];

    if (teamData != null) {
      final List<dynamic> managerUuids = teamData['manager'] ?? [];

      isManager = managerUuids.contains(userId);

      if (managerUuids.isNotEmpty) {
        final managersData = await Supabase.instance.client
            .from('auth.users')
            .select('id, email, raw_user_meta_data')
            .inFilter('id', managerUuids.cast<String>());

        managersList = managersData.map((m) {
          final meta = m['raw_user_meta_data'] as Map<String, dynamic>?;
          final name = meta?['full_name'] ?? meta?['name'] ?? 'Onbekende gebruiker';
          return {
            'name': name as String,
            'email': m['email'] as String,
          };
        }).toList().cast<Map<String, String>>();
      }
    }

    return {
      'role': role,
      'isManager': isManager,
      'managers': managersList,
    };
  }

  Color _colorForRole(String role) {
    switch (role.toLowerCase()) {
      case 'admin': return Colors.red;
      case 'office_manager': return const Color.fromARGB(255, 140, 0, 255);
      case 'manager': return Colors.orange;
      case 'worker': return Colors.green;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Team Page - Desktop')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: teamInfoFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Fout: ${snapshot.error}'));
          }

          final data = snapshot.data!;
          final String role = data['role'];
          bool isManager = data['isManager'];
          List<Map<String, String>> managers = data['managers'];

          final Color roleColor = _colorForRole(role);

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text('Ingelogd als:', style: TextStyle(fontSize: 28)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                    decoration: BoxDecoration(
                      color: roleColor.withOpacity(0.2),
                      border: Border.all(color: roleColor, width: 3),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      role.toUpperCase(),
                      style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: roleColor),
                    ),
                  ),
                  const SizedBox(height: 50),

                  if (isManager)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.orange, width: 3),
                      ),
                      child: const Text('Jij bent manager van dit team', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    ),

                  const SizedBox(height: 40),

                  if (managers.isNotEmpty) ...[
                    const Text('Je manager(s):', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ...managers.map((m) => Card(
                          child: ListTile(
                            leading: CircleAvatar(backgroundColor: Colors.orange.shade200, child: const Icon(Icons.person)),
                            title: Text(m['name']!, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(m['email']!),
                          ),
                        )),
                  ] else if (!isManager)
                    const Text('Je hebt nog geen manager toegewezen', style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}