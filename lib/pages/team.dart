import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class Team {
  final String id;
  final DateTime createdAt;
  final List<String> users;
  final String manager;

  const Team({
    required this.id,
    required this.createdAt,
    required this.users,
    required this.manager,
  });

  factory Team.fromJson(Map<String, dynamic> json) {
    List<String> usersList = [];

    final raw = json['users'];

    if (raw is List) {
      usersList = raw.cast<String>();
    } else if (raw is String) {
      try {
        final parsed = List<dynamic>.from(
          raw.trim().startsWith('[')
              ? (List<dynamic>.from(jsonDecode(raw)))
              : raw.split(',').map((s) => s.trim().replaceAll('"', '').replaceAll("'", "")),
        );
        usersList = parsed.cast<String>();
      } catch (_) {
        debugPrint('Kon users niet parsen: $raw');
      }
    }

    final managerId = json['manager'] as String?;
    if (managerId != null && !usersList.contains(managerId)) {
      usersList.add(managerId);
    }

    debugPrint('Team.fromJson → id: ${json['id']}, users: $usersList, manager: $managerId');

    return Team(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      users: usersList,
      manager: managerId ?? '',
    );
  }
}

class TeamDisplayData {
  final String role;
  final List<Team> myTeams;
  final List<Team> managedTeams;
  final List<Team>? allTeams;
  final String? currentUserId;

  const TeamDisplayData({
    required this.role,
    required this.myTeams,
    required this.managedTeams,
    this.allTeams,
    this.currentUserId,
  });

  factory TeamDisplayData.notLoggedIn() {
    return const TeamDisplayData(
      role: 'Niet ingelogd',
      myTeams: [],
      managedTeams: [],
      currentUserId: null,
    );
  }
}

class TeamPage extends StatelessWidget {
  const TeamPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    return isMobile ? const MobileLayout() : const DesktopLayout();
  }
}

class MobileLayout extends StatelessWidget {
  const MobileLayout({super.key});
  @override Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Team – Mobiel')),
        body: const Center(child: Text('Mobiel komt later')),
      );
}

class DesktopLayout extends StatefulWidget {
  const DesktopLayout({super.key});
  @override State<DesktopLayout> createState() => _DesktopLayoutState();
}

class _DesktopLayoutState extends State<DesktopLayout> {
  late Future<TeamDisplayData> teamInfoFuture;

  @override
  void initState() {
    super.initState();
    teamInfoFuture = _loadTeamInfo();
  }

  Future<TeamDisplayData> _loadTeamInfo() async {
    final user = supabase.auth.currentUser;
    if (user == null) return TeamDisplayData.notLoggedIn();

    final String userId = user.id;
    debugPrint('Ingelogde user UUID: $userId');

    final roleData = await supabase
        .from('permissions')
        .select('role')
        .eq('user_uuid', userId)
        .maybeSingle();
    final String role = roleData?['role'] as String? ?? 'Werknemer';

    final response = await supabase.from('teams').select();
    final List<Team> allTeams =
        (response as List).map((json) => Team.fromJson(json)).toList();

    final myTeams = allTeams.where((t) => t.users.contains(userId)).toList();
    final managedTeams = allTeams.where((t) => t.manager == userId).toList();

    debugPrint('myTeams: ${myTeams.length} | managedTeams: ${managedTeams.length}');

    return TeamDisplayData(
      role: role,
      myTeams: myTeams,
      managedTeams: managedTeams,
      allTeams: role.toLowerCase().contains('office_manager') ? allTeams : null,
      currentUserId: userId,
    );
  }

  Future<List<Map<String, dynamic>>> _fetchTeamMembers(List<String> userIds) async {
    if (userIds.isEmpty) return [];

    try {
      final response = await supabase
          .from('user_profiles')
          .select('id, email, name')
          .inFilter('id', userIds);

      final List<Map<String, dynamic>> results = (response as List)
          .cast<Map<String, dynamic>>();

      final Map<String, Map<String, dynamic>> map = {
        for (var r in results) r['id'] as String: r
      };

      for (final id in userIds) {
        map.putIfAbsent(id, () => {'id': id, 'name': 'Onbekend', 'email': 'Geen e-mail'});
      }

      return userIds.map((id) => map[id]!).toList();
    } catch (e) {
      debugPrint('Fout bij ophalen profielen: $e');
      return userIds
          .map((id) => {'id': id, 'name': 'Fout bij laden', 'email': ''})
          .toList();
    }
  }

  Color _colorForRole(String role) {
    final r = role.toLowerCase();
    if (r.contains('office_manager') || r.contains('admin'))
      return Colors.deepPurple;
    if (r.contains('manager')) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mijn Team'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() => teamInfoFuture = _loadTeamInfo()),
          )
        ],
      ),
      body: FutureBuilder<TeamDisplayData>(
        future: teamInfoFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Fout: ${snapshot.error}'));
          }
          final data = snapshot.data ?? TeamDisplayData.notLoggedIn();
          final roleColor = _colorForRole(data.role);

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
                      data.role.toUpperCase(),
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: roleColor),
                    ),
                  ),
                  const SizedBox(height: 50),
                  if (data.managedTeams.isNotEmpty) ...[
                    const Text('Jij bent manager van:', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    ...data.managedTeams.map((team) => _buildTeamCard(team, true)),
                  ]
                  else if (data.myTeams.isNotEmpty) ...[
                    const Text('Jij bent teamlid in:', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    ...data.myTeams.map((team) => _buildTeamCard(team, team.manager == data.currentUserId)),
                  ]
                  else ...[
                    const Text('Je zit nog niet in een team', style: TextStyle(fontSize: 20, color: Colors.grey)),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTeamCard(Team team, bool isManager) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 6,
      child: ExpansionTile(
        leading: Icon(Icons.group, color: isManager ? Colors.orange : Colors.blue, size: 40),
        title: Text(
          isManager
              ? 'Jouw team (${team.users.length} leden)'
              : '${team.users.length} teamleden',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isManager ? 'Jij bent de manager' : 'Manager: ${team.manager.substring(0, 8)}...'),
            const SizedBox(height: 4),
            Text('Team ID: ${team.id.substring(0, team.id.length > 100 ? 100 : team.id.length)}'),
          ],
        ),
        children: [
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _fetchTeamMembers(team.users),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator());
              }

              final members = snapshot.data ?? [];

              return Column(
                children: members.map((m) {
                  final isCurrentUser = m['id'] == supabase.auth.currentUser?.id;
                  final bool isManager = team.manager == m['id'];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isCurrentUser ? Colors.orange : Colors.grey,
                      child: Text((m['name'] as String?)?.substring(0, 1).toUpperCase() ?? '?'),
                    ),
                    title: Text(
                      m['name']?.toString() ?? 'Onbekend',
                      style: TextStyle(fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal),
                    ),
                    subtitle: Text(
                      '${m['email']?.toString() ?? 'Geen e-mail'}\n'
                      '${isManager ? 'Manager' : 'Werknemer'}'
                    ),
                    trailing: isCurrentUser ? const Text('JIJ', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)) : null,
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}