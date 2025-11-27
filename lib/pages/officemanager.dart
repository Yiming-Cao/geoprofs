// lib/pages/office_manager_dashboard.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geoprof/components/navbar.dart';
import 'package:geoprof/components/header_bar.dart';
import 'package:geoprof/components/background_container.dart';

final supabase = Supabase.instance.client;

class OfficeManagerDashboard extends StatelessWidget {
  const OfficeManagerDashboard({super.key});

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
      return role == 'office_manager';
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
            ? const MobileLayout()
            : const DesktopLayout();
      },
    );
  }
}

class Employee {
  final String uuid;
  final String name;
  final String role;

  Employee({
    required this.uuid,
    required this.name,
    required this.role,
  });
}

// Load employees - fully in English
Future<List<Employee>> loadEmployees() async {
  try {
    final response = await supabase
        .from('permissions')
        .select('user_uuid, role, users:users!users_id_fkey(name)')
        .order('updated_at', ascending: false);

    return (response as List).map((row) {
      final uuid = row['user_uuid'] as String;
      final role = (row['role'] as String?)?.toLowerCase() ?? 'worker';
      final userInfo = row['users'] as Map<String, dynamic>?;
      final name = (userInfo?['name'] as String?) ?? 'No name set';

      return Employee(uuid: uuid, name: name, role: role);
    }).toList();
  } catch (e) {
    debugPrint('Failed to load employees: $e');
    return [];
  }
}

// ====================== MOBILE LAYOUT ======================
class MobileLayout extends StatefulWidget {
  const MobileLayout({super.key});

  @override
  State<MobileLayout> createState() => _MobileLayoutState();
}

class _MobileLayoutState extends State<MobileLayout> {
  List<Employee> _employees = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final list = await loadEmployees();
    setState(() {
      _employees = list;
      _loading = false;
    });
  }

  void _showInviteDialog() {
    final emailCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final deptCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Employee'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email *')),
              const SizedBox(height: 12),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name *')),
              const SizedBox(height: 12),
              TextField(controller: deptCtrl, decoration: const InputDecoration(labelText: 'Role (optional)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              final email = emailCtrl.text.trim();
              final name = nameCtrl.text.trim();
              final dept = deptCtrl.text.trim();
              if (email.isEmpty || name.isEmpty) return;

              try {
                final resp = await supabase.auth.signUp(email: email, password: 'temp123456');

                if (resp.user != null) {
                  // permissions
                  await supabase.from('permissions').insert({
                    'user_uuid': resp.user!.id,
                    'role': 'worker',
                  });

                  // auth.users  meta_data
                  await supabase.auth.updateUser(UserAttributes(
                    data: {
                      'full_name': name,
                      'department': dept,
                    },
                  ));

                  if (ctx.mounted) Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Add Sucsses$email')));
                  _refresh();
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add Failed, email may already exist')));
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
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
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('Employee manager', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                            const Spacer(),
                            ElevatedButton.icon(
                              onPressed: _showInviteDialog,
                              icon: const Icon(Icons.person_add),
                              label: const Text('Add Employee'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        if (_loading) const Center(child: CircularProgressIndicator()),
                        if (!_loading && _employees.isEmpty) const Center(child: Text('No employees found.', style: TextStyle(fontSize: 18))),
                        if (!_loading && _employees.isNotEmpty)
                          ..._employees.map((e) => Card(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                child: ListTile(
                                  leading: CircleAvatar(child: Text(e.name.isNotEmpty ? e.name[0] : '?')),
                                  title: Text(e.name),
                                  subtitle: Text(e.role),
                                  trailing: Text(e.uuid.substring(0, 8),
                                      style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                ),
                              )),
                        const SizedBox(height: 80),
                      ],
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
    );
  }
}

// ====================== DESKTOP LAYOUT ======================
class DesktopLayout extends StatefulWidget {
  const DesktopLayout({super.key});

  @override
  State<DesktopLayout> createState() => _DesktopLayoutState();
}

class _DesktopLayoutState extends State<DesktopLayout> {
  List<Employee> _employees = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final list = await loadEmployees();
    setState(() {
      _employees = list;
      _loading = false;
    });
  }

  // Fixed _showInviteDialog - correct function invoke with body parameter
  void _showInviteDialog() {
    final emailCtrl = TextEditingController();
    final nameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Employee'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Email *'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name *'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              final email = emailCtrl.text.trim();
              final name = nameCtrl.text.trim();

              if (email.isEmpty || name.isEmpty || !email.contains('@')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid email and name')),
                );
                return;
              }

              try {
                final response = await supabase.functions.invoke(
                  'add-employee',
                  body: {'email': email, 'name': name},
                  headers: {
                    'Content-Type': 'application/json',
                  },
                );

                if (response.data == null || response.data['error'] != null) {
                  throw response.data?['error'] ?? 'Unknown error';
                }

                if (ctx.mounted) Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Employee added: $name')),
                );
                _refresh();
              } catch (e) {
                debugPrint('Add employee failed: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed: $e')),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
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
                  children: [
                    SizedBox(
                      width: 340,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              const Text('Employee manager', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 40),
                              ElevatedButton.icon(
                                onPressed: _showInviteDialog,
                                icon: const Icon(Icons.person_add, size: 32),
                                label: const Text('Add new employee', style: TextStyle(fontSize: 20)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  padding: const EdgeInsets.symmetric(vertical: 20),
                                  minimumSize: const Size(double.infinity, 60),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 32),
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Employee list', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 20),
                              if (_loading) const Center(child: CircularProgressIndicator()),
                              if (!_loading && _employees.isEmpty) const Center(child: Text('No employee', style: TextStyle(fontSize: 20))),
                              if (!_loading && _employees.isNotEmpty)
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: _employees.length,
                                    itemBuilder: (_, i) {
                                      final e = _employees[i];
                                      return Card(
                                        margin: const EdgeInsets.symmetric(vertical: 8),
                                        child: ListTile(
                                          leading: CircleAvatar(radius: 28, child: Text(e.name.isNotEmpty ? e.name[0] : '?', style: const TextStyle(fontSize: 20))),
                                          title: Text(e.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                                          subtitle: Text(e.role, style: const TextStyle(fontSize: 16)),
                                          trailing: Text(e.uuid.substring(0, 8), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Padding(padding: EdgeInsets.only(bottom: 24), child: Navbar()),
          ],
        ),
      ),
    );
  }
}