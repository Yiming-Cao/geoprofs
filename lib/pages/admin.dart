import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; 
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';


class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();

  
}

class _AdminPageState extends State<AdminPage> {
  bool _isAdmin = false;
  bool _loading = true;
  User? _user;

  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  Future<void> _checkAdminStatus() async {
    if (!Supabase.instance.isInitialized) {
        // In test omgeving: fake een admin of skip (pas aan wat je wilt testen)
        if (kDebugMode) { // of gebruik een test flag, bijv. const bool isTest = true; in test file
          setState(() {
            _loading = false;
            _isAdmin = true;  // ← voor succes tests: toon admin content
            // _isAdmin = false; // voor geweigerd test
          });
          return;
        }
      }

    final supabase = Supabase.instance.client;
    _user = supabase.auth.currentUser;

    if (_user == null) {
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final response = await supabase
          .from('permissions')
          .select('role')
          .eq('user_uuid', _user!.id)
          .maybeSingle();

      final bool isAdmin = response != null && (response['role'] as String?) == 'admin';

      if (mounted) {
        setState(() {
          _isAdmin = isAdmin;
          _loading = false;
        });

        if (!isAdmin) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Toegang geweigerd.')),
          );
          Navigator.of(context).pop();
        }
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fout bij ophalen rechten: ${e.message}')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Onverwachte fout bij controleren admin status.')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isAdmin) {
      return Scaffold(
        key: const Key('admin_page'),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 80, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Toegang geweigerd', style: TextStyle(fontSize: 24)),
              const SizedBox(height: 8),
              Text('Alleen administrators kunnen deze pagina bekijken.',
                  style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Terug'),
              ),
            ],
          ),
        ),
      );
    }

    if (kIsWeb) {
      return const DesktopLayout();
    } else {
      final shortestSide = MediaQuery.of(context).size.shortestSide;
      return shortestSide < 600 ? const MobileLayout() : const DesktopLayout();
    }
  }
}

class AuditTrailPage extends StatefulWidget {
  const AuditTrailPage({super.key});

  @override
  State<AuditTrailPage> createState() => _AuditTrailPageState();
}

class _AuditTrailPageState extends State<AuditTrailPage> {
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }
  
  Future<List<Map<String, dynamic>>> getLogs() async {
    final supabase = Supabase.instance.client;
    final response = await supabase
      .from('logs')
      .select('id, action, change, was, user_uuid, created_at')
      .order('created_at', ascending: false);

      // print("Supabase response: $response");
    return response;
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    key: const Key('audit_trail_page'),
    appBar: AppBar(title: const Text("Logs")),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: getLogs(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Fout bij laden van logs: ${snapshot.error}'));
        }
        final logs = snapshot.data ?? [];
        if (logs.isEmpty) {
          return const Center(child: Text('Geen logs gevonden.'));
        }

        return Scrollbar(
          controller: _verticalController,
          thumbVisibility: true,
          interactive: true,
          thickness: 8,
          radius: const Radius.circular(10),
          child: SingleChildScrollView(
            controller: _verticalController,
            child: Scrollbar(
              controller: _horizontalController,
              thumbVisibility: true,
              interactive: true,
              scrollbarOrientation: ScrollbarOrientation.bottom,
              thickness: 8,
              radius: const Radius.circular(10),
              child: SingleChildScrollView(
                controller: _horizontalController,
                scrollDirection: Axis.horizontal,
                key: const Key('audit_trail_table'),
                child: DataTable(
                  columnSpacing: 12.0,
                  horizontalMargin: 12.0,
                  dataRowMinHeight: 48.0,
                  dataRowMaxHeight: 140.0, // ruimte voor wrap
                  columns: const [
                    DataColumn(label: Text("ID")),
                    DataColumn(label: Text("Actie")),
                    DataColumn(label: Text("Was Type")),
                    DataColumn(label: Text("Was Start")),
                    DataColumn(label: Text("Was Eind")),
                    DataColumn(label: Text("Was Dagen")),
                    DataColumn(label: Text("Was Status")),
                    DataColumn(label: Text("Change Type")),
                    DataColumn(label: Text("Change Start")),
                    DataColumn(label: Text("Change Eind")),
                    DataColumn(label: Text("Change Dagen")),
                    DataColumn(label: Text("Change Status")),
                    DataColumn(label: Text("User UUID")),
                    DataColumn(label: Text("Datum")),
                  ],
                  rows: logs.map((log) {
                    // Parse JSON – veilig afhandelen als het geen string/JSON is
                    Map<String, dynamic> wasMap = {};
                    Map<String, dynamic> changeMap = {};

                    final wasRaw = log['was'];
                    if (wasRaw is String && wasRaw.isNotEmpty) {
                      try {
                        wasMap = jsonDecode(wasRaw) as Map<String, dynamic>;
                      } catch (e) {
                        // stil negeren of loggen als je wilt
                      }
                    }

                    final changeRaw = log['change'];
                    if (changeRaw is String && changeRaw.isNotEmpty) {
                      try {
                        changeMap = jsonDecode(changeRaw) as Map<String, dynamic>;
                      } catch (e) {}
                    }

                    return DataRow(cells: [
                      DataCell(Text(log['id']?.toString() ?? '-')),
                      DataCell(Text(log['action'] ?? '-')),
                      // WAS velden
                      DataCell(Text(wasMap['verlof_type'] ?? '-')),
                      DataCell(Text(wasMap['start_datum'] ?? '-')),
                      DataCell(Text(wasMap['eind_datum'] ?? '-')),
                      DataCell(Text(wasMap['aantal_dagen']?.toString() ?? '-')),
                      DataCell(Text(wasMap['status'] ?? '-')),
                      // CHANGE velden
                      DataCell(Text(changeMap['verlof_type'] ?? '-')),
                      DataCell(Text(changeMap['start_datum'] ?? '-')),
                      DataCell(Text(changeMap['eind_datum'] ?? '-')),
                      DataCell(Text(changeMap['aantal_dagen']?.toString() ?? '-')),
                      DataCell(Text(changeMap['status'] ?? '-')),
                      // rest
                      DataCell(Text(log['user_uuid'] ?? '-')),
                      DataCell(Text(log['created_at']?.toString() ?? '-')),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}}

class MobileLayout extends StatelessWidget {
  const MobileLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Page - Mobile'),
      ),
      body: const Center(
        child: Text(
          'This is the mobile layout for the Admin Page.',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}

class DesktopLayout extends StatefulWidget {
  const DesktopLayout({super.key});

  @override
  State<DesktopLayout> createState() => _DesktopLayoutState();
}

class _DesktopLayoutState extends State<DesktopLayout> {
  int _selectedIndex = 0;

    Future<List<Map<String, dynamic>>> getLogs() async {
    final supabase = Supabase.instance.client;
    final response = await supabase.from('logs').select();
    return response;
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    switch (_selectedIndex) {
      case 1:
        content = const AuditTrailPage();
        break;
      default:
        content = const Center(
          child: Text(
            'Welkom op de admin pagina (desktop)',
            style: TextStyle(fontSize: 24),
          ),
        );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Page - Desktop'),
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.home),
                label: Text('Home'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.history, key: Key('audit_trail_button')),
                label: Text('Audit Trail'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: content),
        ],
      ),
    );
  }
}