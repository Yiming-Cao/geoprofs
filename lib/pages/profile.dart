import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:geoprof/components/protected_route.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geoprof/components/navbar.dart';
import 'package:geoprof/components/header_bar.dart';
import 'package:geoprof/components/background_container.dart';
import 'package:image_picker/image_picker.dart';

enum _Section { home, work, leave, messages }

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ProtectedRoute(
      child: (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)
          ? const MobileLayout()
          : const DesktopLayout(),
    );
  }
}

final supabase = Supabase.instance.client;

class MobileLayout extends StatelessWidget {
  const MobileLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Profile Page',
              style: TextStyle(fontSize: 24),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                Navigator.pushNamed(context, '/');
              },
            ),
          ],
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
  String? _avatarUrl;
  final String _defaultAvatar =
      'https://jkvmrzfzmvqedynygkms.supabase.co/storage/v1/object/public/assets/images/default_avatar.png';

  _Section _selectedSection = _Section.home;

  List<Map<String, dynamic>> _tasks = [];
  bool _loadingTasks = false;

  List<Map<String, dynamic>> _leaveRequests = [];
  bool _loadingLeave = false;

  @override
  void initState() {
    super.initState();
    final user = supabase.auth.currentUser;
    _avatarUrl = user?.userMetadata?['avatar_url'] as String?;
    _loadTasks();
    _loadLeaveRequests(); // load leave requests for sidebar test
  }

  // 兼容不同版本的 Postgrest/PostgrestFilterBuilder 的执行方法
  Future<dynamic> _runQuery(dynamic builder) async {
    final b = builder as dynamic;
    // 尝试常见的方法名，顺序容错调用
    try {
      return await b.execute();
    } catch (_) {}
    try {
      return await b.get();
    } catch (_) {}
    try {
      return await b.maybeSingle();
    } catch (_) {}
    try {
      return await b.single();
    } catch (_) {}
    // 如果传入的是 Future/已执行的结果，直接 await 它
    if (b is Future) {
      return await b;
    }
    // 最后降级返回原对象（可能是同步数据）
    return b;
  }

  Future<void> _loadTasks() async {
    setState(() => _loadingTasks = true);
    try {
      final builder = supabase.from('tasks').select();
      final response = await _runQuery(builder);
      List data = [];

      if (response != null && (response.error == null)) {
        final d = response.data ?? response;
        if (d is List) {
          data = List.from(d);
        } else if (d != null) {
          data = [d];
        }
      } else {
        data = [];
      }

      if (data.isNotEmpty) {
        _tasks = data.map<Map<String, dynamic>>((e) {
          final map = Map<String, dynamic>.from(e as Map);
          final rawMembers = map['members'];
          List<Map<String, dynamic>> members = [];
          if (rawMembers is String) {
            try {
              final parsed = jsonDecode(rawMembers);
              if (parsed is List) {
                members = parsed.map<Map<String, dynamic>>((m) => Map<String, dynamic>.from(m as Map)).toList();
              }
            } catch (_) {
              members = [];
            }
          } else if (rawMembers is List) {
            members = rawMembers.map<Map<String, dynamic>>((m) {
              if (m is Map) return Map<String, dynamic>.from(m);
              return {'display_name': m.toString()};
            }).toList();
          }
          map['members'] = members;
          return map;
        }).toList();
      } else {
        final currentName = supabase.auth.currentUser?.userMetadata?['display_name'] ?? 'You';
        _tasks = [
          {
            'id': 1,
            'title': 'Inspect site A',
            'description': 'Check soil samples and equipment.',
            'members': [
              {'display_name': currentName, 'status': 'online', 'days_absent': 0}
            ],
            'completed': false,
          },
          {
            'id': 2,
            'title': 'Prepare report for B',
            'description': 'Compile weekly report with Rens.',
            'members': [
              {'display_name': currentName, 'status': 'online', 'days_absent': 0},
              {'display_name': 'Rens', 'status': 'ziek', 'days_absent': 2}
            ],
            'completed': false,
          },
          {
            'id': 3,
            'title': 'Survey C alone',
            'description': 'Solo survey and photo documentation.',
            'members': [
              {'display_name': currentName, 'status': 'online', 'days_absent': 0}
            ],
            'completed': false,
          },
        ];
      }
    } catch (e, st) {
      debugPrint('Load tasks failed: $e\n$st');
      final currentName = supabase.auth.currentUser?.userMetadata?['display_name'] ?? 'You';
      _tasks = [
        {
          'id': 1,
          'title': 'Inspect site A',
          'description': 'Check soil samples and equipment.',
          'members': [
            {'display_name': currentName, 'status': 'online', 'days_absent': 0}
          ],
          'completed': false,
        },
        {
          'id': 2,
          'title': 'Prepare report for B',
          'description': 'Compile weekly report with Rens.',
          'members': [
            {'display_name': currentName, 'status': 'online', 'days_absent': 0},
            {'display_name': 'Rens', 'status': 'ziek', 'days_absent': 2}
          ],
          'completed': false,
        },
        {
          'id': 3,
          'title': 'Survey C alone',
          'description': 'Solo survey and photo documentation.',
          'members': [
            {'display_name': currentName, 'status': 'online', 'days_absent': 0}
          ],
          'completed': false,
        },
      ];
    } finally {
      setState(() => _loadingTasks = false);
    }
  }

  Future<void> _toggleTaskComplete(Map<String, dynamic> task) async {
    final id = task['id'];
    final newVal = !(task['completed'] == true);
    setState(() {
      final idx = _tasks.indexWhere((t) => t['id'] == id);
      if (idx != -1) _tasks[idx]['completed'] = newVal;
    });

    try {
      final builder = supabase.from('tasks').update({'completed': newVal}).eq('id', id);
      final res = await _runQuery(builder);
      if (res != null && res.error != null) throw res.error!;
    } catch (e, st) {
      debugPrint('Toggle task complete failed: $e\n$st');
      setState(() {
        final idx = _tasks.indexWhere((t) => t['id'] == id);
        if (idx != -1) _tasks[idx]['completed'] = !newVal;
      });
    }
  }

  Future<void> _loadLeaveRequests() async {
    setState(() => _loadingLeave = true);
    try {
      final currentUser = supabase.auth.currentUser;
      final userId = currentUser?.id;

      // Build query for 'verlof' (dashboard writes to this table)
      dynamic builder = supabase.from('verlof').select();

      // If you only want the current user's requests, uncomment the next line.
      if (userId != null) builder = (builder as dynamic).eq('user_id', userId);

      final response = await _runQuery(builder);

      // Robustly extract list of rows from different response shapes
      List rows = [];
      if (response == null) {
        rows = [];
      } else if (response is List) {
        rows = List.from(response);
      } else if (response is Map && response.containsKey('data')) {
        final d = response['data'];
        if (d is List) rows = List.from(d);
        else if (d != null) rows = [d];
      } else if (response is Map && response.containsKey('error')) {
        rows = [];
      } else {
        rows = [response];
      }

      // If no rows from 'verlof', fall back to legacy table 'leave_requests'
      if (rows.isEmpty) {
        final legacy = await _runQuery(supabase.from('leave_requests').select());
        if (legacy is List) rows = List.from(legacy);
        else if (legacy is Map && legacy.containsKey('data')) {
          final d = legacy['data'];
          if (d is List) rows = List.from(d);
          else if (d != null) rows = [d];
        } else if (legacy != null && legacy is! Map) {
          rows = [legacy];
        }
      }

      // Prepare map of user_id -> display_name by querying profiles (if exists)
      final Set<String> otherUserIds = {};
      for (final r in rows) {
        try {
          final map = r as Map;
          final uid = map['user_id']?.toString();
          if (uid != null && uid.isNotEmpty && uid != userId) otherUserIds.add(uid);
        } catch (_) {}
      }

      Map<String, String> nameById = {};
      if (otherUserIds.isNotEmpty) {
        try {
          final idsList = otherUserIds.toList();
          // Attempt to read from 'profiles' table (common convention). Adjust if you have another table.
          final profilesRes = await _runQuery(supabase.from('profiles').select('id,display_name').inFilter('id', idsList));
          List profRows = [];
          if (profilesRes is List) profRows = profilesRes;
          else if (profilesRes is Map && profilesRes.containsKey('data')) {
            final d = profilesRes['data'];
            if (d is List) profRows = d;
          }
          for (final p in profRows) {
            try {
              final pm = Map<String, dynamic>.from(p as Map);
              nameById[pm['id'].toString()] = pm['display_name']?.toString() ?? pm['id'].toString();
            } catch (_) {}
          }
        } catch (e) {
          debugPrint('profiles lookup failed: $e');
        }
      }

      // Map rows into _leaveRequests with normalized fields
      _leaveRequests = rows.map<Map<String, dynamic>>((e) {
        final map = Map<String, dynamic>.from(e as Map);
        // normalize date fields from 'verlof' schema
        map['start_date'] = map['start']?.toString() ?? map['start_date']?.toString() ?? '';
        map['end_date'] = map['end_time']?.toString() ?? map['end_date']?.toString() ?? '';
        map['days'] = map['days_count'] ?? map['days'] ?? map['days']?.toInt();
        // map approved boolean to status
        if (map.containsKey('approved')) {
          final approved = map['approved'];
          map['status'] = approved == true ? 'approved' : 'pending';
        } else {
          map['status'] = map['status'] ?? 'pending';
        }
        // applicant display name: prefer explicit applicant, then profiles lookup, then current user (You) fallback
        final uid = map['user_id']?.toString();
        if (map['applicant'] == null || map['applicant'].toString().isEmpty) {
          if (uid != null) {
            if (uid == userId) {
              map['applicant'] = currentUser?.userMetadata?['display_name'] ?? 'You';
            } else if (nameById.containsKey(uid)) {
              map['applicant'] = nameById[uid];
            } else {
              map['applicant'] = uid; // fallback to uuid if no name found
            }
          } else {
            map['applicant'] = map['applicant'] ?? (currentUser?.userMetadata?['display_name'] ?? 'You');
          }
        }
        return map;
      }).toList();
    } catch (e, st) {
      debugPrint('Load leave requests failed: $e\n$st');
      _leaveRequests = [];
    } finally {
      if (mounted) setState(() => _loadingLeave = false);
    }
  }

  // 在右侧 content 中加入 leave 显示
  Widget _buildRightContent() {
    if (_selectedSection == _Section.work) {
      if (_loadingTasks) {
        return const Center(child: CircularProgressIndicator());
      }
      return Padding(
        padding: const EdgeInsets.all(12.0),
        child: SingleChildScrollView(
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _tasks.map((task) {
              final members = List<Map<String, dynamic>>.from(task['members'] ?? []);
              final completed = task['completed'] == true;
              return SizedBox(
                width: 360,
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(task['title'] ?? 'No title',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            ),
                            Checkbox(
                              value: completed,
                              onChanged: (_) => _toggleTaskComplete(task),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(task['description'] ?? '', style: const TextStyle(color: Colors.black87)),
                        const SizedBox(height: 12),
                        const Text('Members', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Column(
                          children: members.map((m) {
                            final status = (m['status'] ?? '').toString();
                            final days = m['days_absent'] ?? 0;
                            final name = m['display_name'] ?? 'Unknown';
                            Color badgeColor;
                            String badgeText;
                            if (status == 'online') {
                              badgeColor = Colors.green;
                              badgeText = 'Online';
                            } else if (status == 'ziek') {
                              badgeColor = Colors.red;
                              badgeText = 'Ziek ($days d)';
                            } else if (status == 'vakantie') {
                              badgeColor = Colors.orange;
                              badgeText = 'Vakantie';
                            } else if (status == 'personel verlof') {
                              badgeColor = Colors.purple;
                              badgeText = 'Pers. verlof';
                            } else {
                              badgeColor = Colors.grey;
                              badgeText = status;
                            }
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(child: Text(name.isNotEmpty ? name[0] : '?')),
                              title: Text(name),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: badgeColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                                child: Text(badgeText, style: TextStyle(color: badgeColor, fontSize: 12)),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => _toggleTaskComplete(task),
                              child: Text(completed ? 'Mark Incomplete' : 'Confirm Done'),
                            )
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      );
    }

    if (_selectedSection == _Section.leave) {
      if (_loadingLeave) return const Center(child: CircularProgressIndicator());
      if (_leaveRequests.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text('No leave requests found.', style: TextStyle(color: Colors.black54)),
          ),
        );
      }

      return Padding(
        padding: const EdgeInsets.all(12.0),
        child: SingleChildScrollView(
          child: Column(
            children: _leaveRequests.map((r) {
              final start = DateTime.tryParse(r['start_date'] ?? '') ;
              final end = DateTime.tryParse(r['end_date'] ?? '');
              final days = r['days'] ?? (start != null && end != null ? end.difference(start).inDays + 1 : null);
              final status = (r['status'] ?? 'pending').toString();
              Color statusColor = Colors.orange;
              if (status == 'approved') statusColor = Colors.green;
              if (status == 'rejected') statusColor = Colors.red;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text('Leave request by ${r['applicant']}', style: const TextStyle(fontWeight: FontWeight.bold))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                            child: Text(status.toUpperCase(), style: TextStyle(color: statusColor)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('From: ${start != null ? start.toLocal().toString().split(' ')[0] : r['start_date']}'),
                      Text('To:   ${end != null ? end.toLocal().toString().split(' ')[0] : r['end_date']}'),
                      if (days != null) Text('Days: $days'),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // 如果是申请人本人，允许撤回（示例，本地撤回或调用 API）
                          if ((r['applicant'] ?? '') == (supabase.auth.currentUser?.userMetadata?['display_name'] ?? ''))
                            TextButton(
                              onPressed: () async {
                                // 本地更新并尝试从 DB 删除/更新状态
                                setState(() {
                                  _leaveRequests.removeWhere((x) => x['id'] == r['id']);
                                });
                                try {
                                  await _runQuery(supabase.from('leave_requests').delete().eq('id', r['id']));
                                } catch (e) {
                                  debugPrint('Failed to delete leave request: $e');
                                }
                              },
                              child: const Text('Withdraw'),
                            ),
                          TextButton(
                            onPressed: () {
                              // 仅作为查看确认示例
                              showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Leave details'),
                                  content: Text('Applicant: ${r['applicant']}\nFrom: ${r['start_date']}\nTo: ${r['end_date']}\nStatus: $status'),
                                  actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
                                ),
                              );
                            },
                            child: const Text('Details'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      );
    }

    return const Center(child: Text('Profile Page Content Area', style: TextStyle(fontSize: 24)));
  }

  void _onSidebarTap(String label) {
    if (label == 'Work') {
      setState(() {
        _selectedSection = _Section.work;
      });
    } else if (label == 'Home') {
      setState(() {
        _selectedSection = _Section.home;
      });
    } else if (label == 'Messages') {
      setState(() {
        _selectedSection = _Section.messages;
      });
    } else if (label == 'Leave') {
      setState(() {
        _selectedSection = _Section.leave;
      });
      _loadLeaveRequests(); // 切换时刷新
    }
  }

  void _showAccountDialog(BuildContext context, dynamic user) {
    final usernameController = TextEditingController(text: user?.userMetadata?['display_name'] ?? '');
    final emailController = TextEditingController(text: user?.email ?? '');
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    String? localAvatar = _avatarUrl;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          final showConfirm = passwordController.text.isNotEmpty;
          return AlertDialog(
            title: const Text('Account Settings'),
            content: SizedBox(
              width: 350,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundImage: NetworkImage((localAvatar?.isNotEmpty == true) ? localAvatar! : _defaultAvatar),
                    ),
                    TextButton(
                      onPressed: () async {
                        final picker = ImagePicker();
                        final picked = await picker.pickImage(source: ImageSource.gallery);
                        if (picked == null) return;

                        final fileName = 'avatar_${user.id}_${DateTime.now().millisecondsSinceEpoch}.png';
                        final bucket = 'assets';
                        final storagePath = 'images/avatars/$fileName';
                        final supabaseClient = Supabase.instance.client;

                        try {
                          final bytes = await picked.readAsBytes();
                          // uploadBinary may vary by SDK version; if missing, adapt per your supabase_flutter version
                          await supabaseClient.storage.from(bucket).uploadBinary(storagePath, bytes);
                          final publicUrl = supabaseClient.storage.from(bucket).getPublicUrl(storagePath);
                          setStateDialog(() {
                            localAvatar = publicUrl;
                          });
                        } catch (e, st) {
                          debugPrint('Avatar upload error: $e\n$st');
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Avatar upload failed!')));
                        }
                      },
                      child: const Text('Change Avatar'),
                    ),
                    const SizedBox(height: 8),
                    TextField(controller: usernameController, decoration: const InputDecoration(labelText: 'Username')),
                    TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email')),
                    TextField(
                      controller: passwordController,
                      decoration: const InputDecoration(labelText: 'New Password'),
                      obscureText: true,
                      onChanged: (_) => setStateDialog(() {}),
                    ),
                    if (showConfirm)
                      TextField(
                        controller: confirmPasswordController,
                        decoration: const InputDecoration(labelText: 'Confirm Password'),
                        obscureText: true,
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  final supabaseClient = Supabase.instance.client;
                  if (passwordController.text.isNotEmpty && passwordController.text != confirmPasswordController.text) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match!')));
                    return;
                  }

                  try {
                    if (localAvatar != null && localAvatar != user?.userMetadata?['avatar_url']) {
                      await supabaseClient.auth.updateUser(UserAttributes(data: {'avatar_url': localAvatar}));
                      setState(() {
                        _avatarUrl = localAvatar;
                      });
                    }

                    if (usernameController.text.isNotEmpty && usernameController.text != user?.userMetadata?['display_name']) {
                      await supabaseClient.auth.updateUser(UserAttributes(data: {'display_name': usernameController.text}));
                    }

                    if (emailController.text.isNotEmpty && emailController.text != user?.email) {
                      await supabaseClient.auth.updateUser(UserAttributes(email: emailController.text));
                    }

                    if (passwordController.text.isNotEmpty) {
                      await supabaseClient.auth.updateUser(UserAttributes(password: passwordController.text));
                    }
                  } catch (e, st) {
                    debugPrint('Account update error: $e\n$st');
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: ${e.toString()}')));
                    return;
                  }

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account updated!')));
                  setState(() {}); // refresh
                },
                child: const Text('Save'),
              ),
            ],
          );
        });
      },
    );
  }

  String _avatarForDisplay(String? candidate) {
    if (candidate != null && candidate.isNotEmpty) return candidate;
    final user = supabase.auth.currentUser;
    final meta = user?.userMetadata?['avatar_url'] as String?;
    if (meta != null && meta.isNotEmpty) return meta;
    return _defaultAvatar;
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final displayAvatar = _avatarForDisplay(_avatarUrl);
    final displayName = user?.userMetadata?['display_name'] ?? 'User Name';
    final email = user?.email ?? '';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: BackgroundContainer(
        child: Column(
          children: [
            HeaderBar(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  children: [
                    // LEFT COLUMN (sidebar)
                    Column(
                      children: [
                        Container(
                          width: 320,
                          padding: const EdgeInsets.all(16.0),
                          margin: const EdgeInsets.only(bottom: 16.0),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16.0),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(radius: 32, backgroundImage: NetworkImage(displayAvatar)),
                                  const SizedBox(height: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      Text(email, style: const TextStyle(fontSize: 13, color: Colors.grey, fontStyle: FontStyle.italic)),
                                    ],
                                  ),
                                  const SizedBox(width: 8),
                                ],
                              ),
                              const Divider(),
                              _SidebarItem(icon: Icons.home, label: 'Home', onTap: () => _onSidebarTap('Home')),
                              _SidebarItem(icon: Icons.folder, label: 'Work', onTap: () => _onSidebarTap('Work')),
                              _SidebarItem(icon: Icons.message, label: 'Messages', onTap: () => _onSidebarTap('Messages')),
                              _SidebarItem(icon: Icons.beach_access, label: 'Leave', onTap: () => _onSidebarTap('Leave')),
                            ],
                          ),
                        ),
                        Container(
                          width: 320,
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16.0),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Management', style: TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.bold, fontSize: 15)),
                              const SizedBox(height: 8),
                              _SidebarItem(icon: Icons.settings, label: 'Settings', onTap: () => _showAccountDialog(context, user)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 24),
                    // RIGHT: dynamic content
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16.0),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
                        ),
                        // 为右侧内容增加上下固定间距，并让中间区域可扩展/滚动
                        child: Padding(
                          // 这里的 vertical 值决定上下间距，按需调整（与左侧间距保持一致可设为 16/24）
                          padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
                          child: Column(
                            children: [
                              // 如果需要可以在顶部放置标题或控件，当前仅保留扩展区
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: _buildRightContent(),
                                ),
                              ),
                              // 底部固定间距（可删）
                              const SizedBox(height: 0),
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

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _SidebarItem({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 22, color: Colors.black87),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontSize: 15, fontStyle: FontStyle.italic, color: Colors.black87)),
          ],
        ),
      ),
    );
  }
}