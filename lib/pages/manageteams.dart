import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geoprof/components/navbar.dart';
import 'package:geoprof/components/header_bar.dart';
import 'package:geoprof/components/background_container.dart';

final supabase = Supabase.instance.client;

class TeamManagement extends StatelessWidget {
  const TeamManagement({super.key});

  Future<bool> _hasOfficeManagerRole() async {
    final session = supabase.auth.currentSession;
    if (session == null) return false;

    try {
      final data = await supabase
          .from('permissions')
          .select('role')
          .eq('user_uuid', session.user.id)
          .maybeSingle();

      if (data == null) return false;
      final role = (data['role'] as String?)?.toLowerCase() ?? '';
      return role == 'office_manager' || role == 'admin';
    } catch (e) {
      debugPrint('Role check error: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _hasOfficeManagerRole(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.data != true) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
          });
          return const SizedBox.shrink();
        }

        return (defaultTargetPlatform == TargetPlatform.android ||
                defaultTargetPlatform == TargetPlatform.iOS)
            ? const MobileTeamLayout()
            : const DesktopTeamLayout();
      },
    );
  }
}

class AppTeam {
  final String id;
  final String? name;
  final DateTime? createdAt;
  final List<String> userIds;
  final String? managerId;

  AppTeam({
    required this.id,
    this.name,
    this.createdAt,
    this.userIds = const [],
    this.managerId,
  });

  factory AppTeam.fromJson(Map<String, dynamic> json) {
    return AppTeam(
      id: json['id'] as String,
      name: json['name'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      userIds: (json['users'] as List<dynamic>?)?.cast<String>() ?? [],
      managerId: json['manager'] as String?,
    );
  }

  String get displayName => name ?? 'Team ${id.substring(0, 8)}';
}

Future<List<AppTeam>> loadAllTeams() async {
  try {
    final response = await supabase
        .from('teams')
        .select()
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => AppTeam.fromJson(json as Map<String, dynamic>))
        .toList();
  } catch (e) {
    debugPrint('Error loading teams: $e');
    return [];
  }
}

Future<void> showCreateTeamDialog(BuildContext context, VoidCallback refresh) async {
  final nameCtrl = TextEditingController();

  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Nieuw team aanmaken'),
      content: TextField(
        controller: nameCtrl,
        decoration: const InputDecoration(
          labelText: 'Team naam *',
          hintText: 'Bijvoorbeeld: Monteurs regio Oost',
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Annuleren'),
        ),
        ElevatedButton(
          onPressed: () async {
            final name = nameCtrl.text.trim();
            if (name.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Teamnaam is verplicht')),
              );
              return;
            }

            try {
              final response = await supabase.from('teams').insert({
                'name': name,
              }).select().single();
              final newTeam = AppTeam.fromJson(response);
              Navigator.pop(ctx);
              refresh();

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Team "$name" succesvol aangemaakt')),
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Aanmaken mislukt: $e')),
              );
            }
          },
          child: const Text('Aanmaken'),
        ),
      ],
    ),
  );
}

Future<void> _showAddMembersDialog(
  BuildContext context,
  AppTeam team,
  VoidCallback refresh,
) async {
  List<Map<String, dynamic>> availableUsers = [];
  bool loading = true;

  try {
    final res = await supabase
        .from('profiles')  
        .select('id, name, email')  
        .neq('id', supabase.auth.currentUser!.id); 

    availableUsers = List<Map<String, dynamic>>.from(res);

    
    availableUsers = availableUsers.where((u) {
      return !team.userIds.contains(u['id']);
    }).toList();

    loading = false;
  } catch (e) {
    loading = false;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Leden laden mislukt: $e')));
  }


  final selectedIds = <String>{};

  if (!context.mounted) return;

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text('Leden toevoegen aan ${team.displayName}'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400, 
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : availableUsers.isEmpty
                  ? const Center(child: Text('Geen beschikbare gebruikers'))
                  : ListView.builder(
                      itemCount: availableUsers.length,
                      itemBuilder: (context, i) {
                        final user = availableUsers[i];
                        final userId = user['id'] as String;
                        final name = user['full_name'] as String? ?? user['email'] ?? userId.substring(0, 8);

                        return CheckboxListTile(
                          title: Text(name),
                          subtitle: Text(user['email'] ?? '', style: const TextStyle(fontSize: 12)),
                          value: selectedIds.contains(userId),
                          onChanged: (bool? value) {
                            setDialogState(() {
                              if (value == true) {
                                selectedIds.add(userId);
                              } else {
                                selectedIds.remove(userId);
                              }
                            });
                          },
                        );
                      },
                    ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: selectedIds.isEmpty
                ? null
                : () async {
                    try {
                      await supabase.from('teams').update({
                        'users': team.userIds + selectedIds.toList(),
                      }).eq('id', team.id);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${selectedIds.length} leden toegevoegd')),
                      );
                      refresh();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Toevoegen mislukt: $e')),
                      );
                    }
                  },
            child: const Text('Toevoegen'),
          ),
        ],
      ),
    ),
  );
}

Future<void> _showRemoveMembersDialog(
  BuildContext context,
  AppTeam team,
  VoidCallback refresh,
) async {
  List<Map<String, dynamic>> currentMembers = [];
  bool loading = true;
  String? errorMessage;

  try {
    if (team.userIds.isEmpty) {
      loading = false;
    } else {
      final res = await supabase
          .from('profiles')
          .select('id, name, email')  
          .inFilter('id', team.userIds);

      currentMembers = List<Map<String, dynamic>>.from(res);

      
      loading = false;
    }
  } catch (e) {
    loading = false;
    errorMessage = 'Kon teamleden niet laden: $e';
    debugPrint(errorMessage);
  }

  
  final selectedIdsToRemove = <String>{};

  if (!context.mounted) return;

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text('Leden verwijderen uit ${team.displayName}'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : errorMessage != null
                  ? Center(child: Text(errorMessage, style: const TextStyle(color: Colors.red)))
                  : team.userIds.isEmpty
                      ? const Center(child: Text('Dit team heeft geen leden'))
                      : currentMembers.isEmpty
                          ? const Center(child: Text('Geen profielgegevens beschikbaar'))
                          : ListView.builder(
                              itemCount: currentMembers.length,
                              itemBuilder: (context, i) {
                                final member = currentMembers[i];
                                final userId = member['id'] as String;
                                final name = member['full_name'] as String? ??
                                    member['name'] as String? ??
                                    member['email'] as String? ??
                                    userId.substring(0, 8) + '...';

                                return CheckboxListTile(
                                  title: Text(name),
                                  subtitle: member['email'] != null
                                      ? Text(
                                          member['email'],
                                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                                        )
                                      : null,
                                  secondary: const Icon(Icons.person),
                                  value: selectedIdsToRemove.contains(userId),
                                  onChanged: (bool? value) {
                                    setDialogState(() {
                                      if (value == true) {
                                        selectedIdsToRemove.add(userId);
                                      } else {
                                        selectedIdsToRemove.remove(userId);
                                      }
                                    });
                                  },
                                );
                              },
                            ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuleren'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.delete_forever, color: Colors.white),
            label: const Text('Verwijder geselecteerd'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: selectedIdsToRemove.isEmpty
                ? null
                : () async {
                    try {
                      final remainingIds = team.userIds
                          .where((id) => !selectedIdsToRemove.contains(id))
                          .toList();

                      await supabase.from('teams').update({
                        'users': remainingIds,
                      }).eq('id', team.id);

                      Navigator.pop(ctx);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${selectedIdsToRemove.length} lid(den) verwijderd',
                          ),
                        ),
                      );

                      refresh();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Verwijderen mislukt: $e')),
                      );
                    }
                  },
          ),
        ],
      ),
    ),
  );
}
Future<void> showEditTeamDialog(BuildContext context, AppTeam team, VoidCallback onSuccess) async {
  final nameController = TextEditingController(text: team.name);

  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Team bewerken'),
      content: TextField(
        controller: nameController,
        decoration: const InputDecoration(labelText: 'Team naam'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuleren'),
        ),
        ElevatedButton(
          onPressed: () async {
            final newName = nameController.text.trim();
            if (newName.isEmpty || newName == team.name) {
              Navigator.pop(context);
              return;
            }

            try {
              await supabase.from('teams').update({'name': newName}).eq('id', team.id);
              Navigator.pop(context);
              onSuccess();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Naam bijgewerkt')),
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Fout: $e')),
              );
            }
          },
          child: const Text('Opslaan'),
        ),
      ],
    ),
  );
}

Future<void> confirmDeleteTeam(BuildContext context, AppTeam team, VoidCallback onSuccess) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Team verwijderen?'),
      content: Text('Weet je zeker dat je "${team.displayName}" wilt verwijderen?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Annuleren'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Verwijderen'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  try {
    await supabase.from('teams').delete().eq('id', team.id);
    onSuccess();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Team verwijderd')),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Fout bij verwijderen: $e')),
    );
  }
}

class MobileTeamLayout extends StatefulWidget {
  const MobileTeamLayout({super.key});

  @override
  State<MobileTeamLayout> createState() => _MobileTeamLayoutState();
}

class _MobileTeamLayoutState extends State<MobileTeamLayout> {
  List<AppTeam> _teams = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  Future<void> _loadTeams() async {
    setState(() => _loading = true);
    final teams = await loadAllTeams();
    if (mounted) {
      setState(() {
        _teams = teams;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: BackgroundContainer(
        child: Stack(
          children: [
            Column(
              children: [
                HeaderBar(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadTeams,
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _teams.isEmpty
                            ? const Center(child: Text('Geen teams gevonden'))
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _teams.length,
                                itemBuilder: (context, index) {
                                  final team = _teams[index];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        child: Text(team.displayName[0].toUpperCase()),
                                      ),
                                      title: Text(team.displayName),
                                      subtitle: Text('${team.userIds.length} leden'),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit),
                                            onPressed: () => showEditTeamDialog(context, team, _loadTeams),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.red),
                                            onPressed: () => confirmDeleteTeam(context, team, _loadTeams),
                                          ),
                                        ],
                                      ),
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => TeamDetailPage(team: team),
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
                  ),
                ),
              ],
            ),
            const Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Navbar(),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showCreateTeamDialog(context, _loadTeams),
        child: const Icon(Icons.add),
      ),
    );
  }
}


class DesktopTeamLayout extends StatefulWidget {
  const DesktopTeamLayout({super.key});

  @override
  State<DesktopTeamLayout> createState() => _DesktopTeamLayoutState();
}

class _DesktopTeamLayoutState extends State<DesktopTeamLayout> {
  List<AppTeam> _teams = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  Future<void> _loadTeams() async {
    setState(() => _loading = true);
    final teams = await loadAllTeams();
    if (mounted) {
      setState(() {
        _teams = teams;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: BackgroundContainer(
        child: Column(
          children: [
            HeaderBar(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 340,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              const Text(
                                'Team beheer',
                                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 40),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.add),
                                label: const Text('Nieuw team'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  minimumSize: const Size(double.infinity, 56),
                                ),
                                onPressed: () => showCreateTeamDialog(context, _loadTeams),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 32),
                    Expanded(
                      child: Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.fromLTRB(32, 32, 32, 16),
                              child: Text(
                                'Teams',
                                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                              ),
                            ),
                            Expanded(
                              child: _loading
                                  ? const Center(child: CircularProgressIndicator())
                                  : _teams.isEmpty
                                      ? const Center(child: Text('Geen teams gevonden'))
                                      : ListView.builder(
                                          padding: const EdgeInsets.symmetric(horizontal: 16),
                                          itemCount: _teams.length,
                                          itemBuilder: (context, index) {
                                            final team = _teams[index];
                                            return Card(
                                              child: ListTile(
                                                leading: CircleAvatar(
                                                  child: Text(team.displayName[0].toUpperCase()),
                                                ),
                                                title: Text(team.displayName),
                                                subtitle: Text('${team.userIds.length} leden • Manager: ${team.managerId?.substring(0, 8) ?? "?"}'),
                                                trailing: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    IconButton(
                                                      icon: const Icon(Icons.edit),
                                                      onPressed: () => showEditTeamDialog(context, team, _loadTeams),
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(Icons.delete, color: Colors.red),
                                                      onPressed: () => confirmDeleteTeam(context, team, _loadTeams),
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(Icons.add),
                                                      onPressed: () => _showAddMembersDialog(context, team, _loadTeams),
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(Icons.remove),
                                                      onPressed: () => _showRemoveMembersDialog(context, team, _loadTeams),
                                          
                    
                                                    ),
                                                  ],
                                                ),
                                                onTap: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) => TeamDetailPage(team: team),
                                                    ),
                                                  );
                                                },
                                              ),
                                            );
                                          },
                                        ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Navbar(),
            ),
          ],
        ),
      ),
    );
  }
}

class TeamDetailPage extends StatefulWidget {
  final AppTeam team;

  const TeamDetailPage({
    super.key,
    required this.team,
  });

  @override
  State<TeamDetailPage> createState() => _TeamDetailPageState();
}

class _TeamDetailPageState extends State<TeamDetailPage> {
  List<Map<String, dynamic>> _members = [];
  bool _loadingMembers = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    if (widget.team.userIds.isEmpty) {
      setState(() => _loadingMembers = false);
      return;
    }

    try {
      final response = await supabase
          .from('profiles')  
          .select('id, name, email')  
          .inFilter('id', widget.team.userIds);

      setState(() {
        _members = List<Map<String, dynamic>>.from(response);
        _loadingMembers = false;
      });
    } catch (e, stack) {
      debugPrint('Fout bij laden leden: $e\n$stack');
      setState(() {
        _error = 'Kon teamleden niet laden: $e';
        _loadingMembers = false;
      });
    }
  }

  String _getName(Map<String, dynamic> profile) {
    
    return profile['full_name'] as String? ??
        profile['name'] as String? ??
        profile['display_name'] as String? ??
        profile['email'] as String? ??
        'Onbekend (${(profile['id'] as String).substring(0, 8)}...)';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.team.name ?? 'Team ${widget.team.id.substring(0, 8)}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.team.name ?? 'Naamloos team',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text('ID: ${widget.team.id}'),
                    if (widget.team.managerId != null)
                      Text('Manager: ${widget.team.managerId!.substring(0, 8)}...'),
                    Text('Aangemaakt: ${widget.team.createdAt?.toString().split(' ').first ?? 'onbekend'}'),
                    Text('Aantal leden: ${widget.team.userIds.length}'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            const Text(
              'Teamleden',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            if (_loadingMembers)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else if (widget.team.userIds.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('Dit team heeft nog geen leden'),
                ),
              )
            else if (_members.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('Geen profielinformatie gevonden voor deze leden'),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _members.length,
                  itemBuilder: (context, index) {
                    final member = _members[index];
                    final name = _getName(member);
                    final email = member['email'] as String?;

                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?'),
                      ),
                      title: Text(name),
                      subtitle: email != null ? Text(email) : null,
                      trailing: Text(
                        (member['id'] as String).substring(0, 8),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}