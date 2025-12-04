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
      debugPrint('OfficeManager check: user role = $role');
      // allow both office_manager and admin users to access this dashboard
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

Future<List<Employee>> loadEmployees() async { 
  try { 
    final response = await supabase.functions.invoke('super-processor'); 
    final data = response.data as Map<String, dynamic>?; 
    if (data == null || data['users'] == null) { 
      debugPrint('loadEmployees: no users returned'); return []; 
    } final List<dynamic> rawUsers = data['users']; 
    debugPrint('loadEmployees: fetched ${rawUsers.length} users'); 
    final employees = rawUsers.map((u) { 
      final map = Map<String, dynamic>.from(u); 
      return Employee( uuid: map['id']?.toString() ?? '', name: map['user_metadata']?['display_name']?.toString() ?? '', role: map['role']?.toString() ?? '', ); 
    }).toList(); return employees; 
  } catch (e, st) { 
    debugPrint('loadEmployees ERROR: $e\n$st'); return []; 
  }
}




Future<void> changeUserRole(String userUuid, String newRole) async {
  final response = await supabase.functions.invoke(
    'super-api',  
    body: {
      'user_id': userUuid,
      'role': newRole,
    },
  );

  if (response.data['error'] != null) {
    throw response.data['error']!;
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

  

  // Desktop dialog handler intentionally implemented in Desktop state class

  // _showChangeRoleDialogDesktop has been moved to the Desktop state class

  Future<void> _showChangeRoleDialog(Employee e) async {
    final roles = ['worker', 'manager'];
    String selected = e.role;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Change role for ${e.name}'),
        content: StatefulBuilder(builder: (ctx2, setState) {
          return DropdownButtonFormField<String>(
            value: selected,
            items: roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
            onChanged: (v) => setState(() => selected = v ?? selected),
            decoration: const InputDecoration(labelText: 'Role'),
          );
        }),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (selected == e.role) return;
              try {
                // Try update first
                final upd = await supabase.from('permissions').update({'role': selected}).eq('user_uuid', e.uuid);
                // If update returned empty or no match, insert
                if (upd == null || (upd is List && upd.isEmpty) || (upd is Map && upd.containsKey('error') && upd['error'] != null)) {
                  await supabase.from('permissions').insert({'user_uuid': e.uuid, 'role': selected});
                }
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Role updated: $selected')));
                await _refresh();
              } catch (err) {
                debugPrint('Change role failed: $err');
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update role: $err')));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteUser(Employee e) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${e.name}?'),
        content: const Text('This will permanently delete the user. Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // call your edge function to delete user
      final resp = await supabase.functions.invoke('delete-user', body: {'user_id': e.uuid});

      if (resp.data == null || resp.data['error'] != null) {
        final err = resp.data?['error'] ?? 'Unknown error';
        throw err;
      }

      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deleted ${e.name}')));
      await _refresh();
    } catch (err) {
      debugPrint('Delete user failed: $err');
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete user: $err')));
    }
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

        // (desktop change-role dialog removed from here; implemented in Desktop state class)
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

  // _showChangeRoleDialogDesktop removed from mobile state — implemented in Desktop state

  // desktop-role-dialog was accidentally defined here, moved into Desktop state

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
                                  trailing: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(e.uuid.substring(0, 8), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ElevatedButton(
                                            onPressed: () => _showChangeRoleDialog(e),
                                            child: const Text('Change role'),
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), textStyle: const TextStyle(fontSize: 12)),
                                          ),
                                          const SizedBox(width: 6),
                                          IconButton(
                                            onPressed: () => _confirmDeleteUser(e),
                                            icon: const Icon(Icons.delete_forever, color: Colors.red),
                                            tooltip: 'Delete user',
                                            constraints: const BoxConstraints(minHeight: 32, minWidth: 32),
                                            padding: EdgeInsets.zero,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
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

  Future<void> _showChangeRoleDialogDesktop(Employee e) async {
    final roles = ['worker', 'manager'];
    String selected = e.role;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Change role for ${e.name}'),
        content: StatefulBuilder(
          builder: (ctx2, setStateDialog) {
            return DropdownButtonFormField<String>(
              value: selected,
              items: roles
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (v) => setStateDialog(() => selected = v ?? selected),
              decoration: const InputDecoration(labelText: 'Role'),
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (selected == e.role) return;

              try {
                await changeUserRole(e.uuid, selected); 

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Role updated to: $selected')),
                );
                _refresh();
              } catch (err) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed: $err')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteUserDesktop(Employee e) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${e.name}?'),
        content: const Text('This will permanently delete the user. Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final resp = await supabase.functions.invoke('dynamic-worker', body: {'user_id': e.uuid});
      if (resp.data == null || resp.data['error'] != null) {
        final err = resp.data?['error'] ?? 'Unknown error';
        throw err;
      }

      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deleted ${e.name}')));
      _refresh();
    } catch (err) {
      debugPrint('Delete user failed (desktop): $err');
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $err')));
    }
  }

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
                  'quick-api',
                  body: {'email': email, 'name': name, 'role': 'worker'},
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
        child: Stack(                               
          children: [
            // main content
            Column(
              children: [
                HeaderBar(),

                // body area
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // left side: action card
                        SizedBox(
                          width: 340,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                children: [
                                  const Text(
                                    'Employee manager',
                                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 40),
                                  ElevatedButton.icon(
                                    onPressed: _showInviteDialog,
                                    icon: const Icon(Icons.person_add, size: 32),
                                    label: const Text(
                                      'Add new employee',
                                      style: TextStyle(fontSize: 20),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      padding: const EdgeInsets.symmetric(vertical: 20),
                                      minimumSize: const Size(double.infinity, 64),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 32),

                        // right side: employee list
                        Expanded(
                          child: Card(
                            elevation: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                
                                const Padding(
                                  padding: EdgeInsets.fromLTRB(32, 32, 32, 16),
                                  child: Text(
                                    'Employee list',
                                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                                  ),
                                ),

                                // list area
                                Expanded(
                                  child: _loading
                                      ? const Center(child: CircularProgressIndicator())
                                      : _employees.isEmpty
                                          ? const Center(
                                              child: Text(
                                                'No employees found',
                                                style: TextStyle(fontSize: 20),
                                              ),
                                            )
                                          : ListView.separated(
                                              padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                                              itemCount: _employees.length,
                                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                                              itemBuilder: (_, i) {
                                                final e = _employees[i];
                                                return Card(
                                                  child: ListTile(
                                                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                                    leading: CircleAvatar(
                                                      radius: 28,
                                                      child: Text(
                                                        e.name.isNotEmpty ? e.name[0].toUpperCase() : '?',
                                                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                                      ),
                                                    ),
                                                    title: Text(
                                                      e.name,
                                                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                                                    ),
                                                    subtitle: Text(
                                                      e.role,
                                                      style: const TextStyle(fontSize: 16),
                                                    ),
                                                    trailing: Column(
                                                      mainAxisSize: MainAxisSize.min,
                                                      crossAxisAlignment: CrossAxisAlignment.end,
                                                      children: [
                                                        Text(
                                                          e.uuid.substring(0, 8),
                                                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                                                        ),
                                                        const SizedBox(height: 0),
                                                        Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            ElevatedButton(
                                                              onPressed: () => _showChangeRoleDialogDesktop(e),
                                                              child: const Text('Change role'),
                                                              style: ElevatedButton.styleFrom(
                                                                backgroundColor: Colors.blueGrey,
                                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                                textStyle: const TextStyle(fontSize: 12),
                                                                                                                                        
                                                              ),
                                                            ),
                                                            SizedBox(width: 8),
                                                            IconButton(
                                                              onPressed: () async => await _confirmDeleteUserDesktop(e),
                                                              icon: const Icon(Icons.delete_forever, color: Colors.red),
                                                              tooltip: 'Delete user',
                                                              constraints: const BoxConstraints(minHeight: 32, minWidth: 32),
                                                              padding: EdgeInsets.zero,
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
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
              ],
            ),

            
            const Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: 24),
                child: Navbar(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
