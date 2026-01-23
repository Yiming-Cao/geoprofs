import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:geoprof/components/protected_route.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geoprof/components/navbar.dart';
import 'package:geoprof/components/header_bar.dart';
import 'package:geoprof/components/background_container.dart';
import 'package:image_picker/image_picker.dart';

enum _Section { home, team, leave, messages }

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

// ====================== MOBILE LAYOUT (同步 Desktop 功能) ======================
class MobileLayout extends StatefulWidget {
  const MobileLayout({super.key});

  @override
  State<MobileLayout> createState() => _MobileLayoutState();
}

class _MobileLayoutState extends State<MobileLayout> {
  String? _avatarUrl;
  final String _defaultAvatar =
      'https://jkvmrzfzmvqedynygkms.supabase.co/storage/v1/object/public/assets/images/default_avatar.png';

  _Section _selectedSection = _Section.home;

  List<Map<String, dynamic>> _leaveRequests = [];
  bool _loadingLeave = false;
  bool _loadingRole = true;
  String _userRole = 'worker';
  
  String? _userDepartment;
  bool _loadingDepartmentLeave = false;
  List<Map<String, dynamic>> _departmentLeaveSchedule = [];
  String? _userTeamId;

  @override
  void initState() {
    super.initState();
    final user = supabase.auth.currentUser;
    _avatarUrl = user?.userMetadata?['avatar_url'] as String?;
    _loadLeaveRequests();
    _loadUserRole();
    _loadUserTeam();
  }

  Future<void> _loadUserRole() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loadingRole = false);
      return;
    }

    try {
      final response = await supabase
          .from('permissions')
          .select('role')
          .eq('id', user.id)
          .single();

      if (mounted) setState(() {
        _userRole = (response['role'] as String?)?.toLowerCase() ?? 'worker';
        _loadingRole = false;
      });
    } catch (e) {
      debugPrint('Kon rol niet ophalen: $e');
      if (mounted) setState(() {
        _userRole = 'worker';
        _loadingRole = false;
      });
    }
  }

  Future<void> _loadUserTeam() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      // Try to find team where user is manager
      var teamRes = await _runQuery(
        supabase
            .from('teams')
            .select('id,name')
            .eq('manager_id', user.id),
      );

      List teamList = [];
      if (teamRes is List) {
        teamList = teamRes;
      } else if (teamRes is Map && teamRes.containsKey('data')) {
        teamList = (teamRes['data'] ?? []) as List;
      }

      // If user is a manager with a team
      if (teamList.isNotEmpty) {
        final team = teamList.first as Map;
        if (mounted) {
          setState(() {
            _userTeamId = team['id'].toString();
            _userDepartment = team['name']?.toString();
          });
        }
      } else {
        // Try to find team where user is a member via team_members field
        var allTeams = await _runQuery(
          supabase.from('teams').select('id,name,team_members'),
        );

        List allTeamsList = [];
        if (allTeams is List) {
          allTeamsList = allTeams;
        } else if (allTeams is Map && allTeams.containsKey('data')) {
          allTeamsList = (allTeams['data'] ?? []) as List;
        }

        // Find team containing current user
        for (var t in allTeamsList) {
          final team = t as Map;
          final members = team['team_members'];
          List<String> memberIds = [];
          
          if (members is List) {
            memberIds = members.map((m) => m.toString()).toList();
          } else if (members is String) {
            try {
              final parsed = jsonDecode(members);
              if (parsed is List) {
                memberIds = parsed.map((m) => m.toString()).toList();
              }
            } catch (_) {}
          }
          
          if (memberIds.contains(user.id)) {
            if (mounted) {
              setState(() {
                _userTeamId = team['id'].toString();
                _userDepartment = team['name']?.toString();
              });
            }
            break;
          }
        }
      }

      if (_userTeamId != null && _userDepartment != null && _userDepartment!.isNotEmpty) {
        await _loadDepartmentLeaveSchedule();
      }
    } catch (e) {
      debugPrint('Kon team niet ophalen: $e');
    }
  }

  Future<void> _loadDepartmentLeaveSchedule() async {
    if (_userTeamId == null || _userTeamId!.isEmpty) return;

    setState(() => _loadingDepartmentLeave = true);
    try {
      // 1. Get team and its members
      final teamRes = await _runQuery(
        supabase
            .from('teams')
            .select('id,name,team_members,manager_id')
            .eq('id', _userTeamId!),
      );

      Map teamData = teamRes is Map ? teamRes : {};
      List<String> departmentUserIds = [];
      
      // Extract team members from team_members field
      final members = teamData['team_members'];
      if (members is List) {
        departmentUserIds = members.map((m) => m.toString()).toList();
      } else if (members is String) {
        try {
          final parsed = jsonDecode(members);
          if (parsed is List) {
            departmentUserIds = parsed.map((m) => m.toString()).toList();
          }
        } catch (_) {}
      }
      
      // Add manager_id if present
      final managerId = teamData['manager_id']?.toString();
      if (managerId != null && !departmentUserIds.contains(managerId)) {
        departmentUserIds.add(managerId);
      }

      if (departmentUserIds.isEmpty) {
        setState(() {
          _departmentLeaveSchedule = [];
          _loadingDepartmentLeave = false;
        });
        return;
      }

      // 2. Get profiles for these members
      final profilesRes = await _runQuery(
        supabase
            .from('profiles')
            .select('id,display_name')
            .inFilter('id', departmentUserIds),
      );

      List<String> teamMemberIds = [];
      if (profilesRes is List) {
        teamMemberIds = (profilesRes as List)
            .map((p) => (p as Map)['id'].toString())
            .toList();
      } else if (profilesRes is Map && profilesRes.containsKey('data')) {
        teamMemberIds = ((profilesRes['data'] ?? []) as List)
            .map((p) => (p as Map)['id'].toString())
            .toList();
      }

      if (teamMemberIds.isEmpty) {
        setState(() {
          _departmentLeaveSchedule = [];
          _loadingDepartmentLeave = false;
        });
        return;
      }

      // 3. Get all leave requests for team members
      final leaveRes = await _runQuery(
        supabase
            .from('verlof')
            .select()
            .inFilter('user_id', teamMemberIds),
      );

      List<Map<String, dynamic>> leaveRequests = [];
      if (leaveRes is List) {
        leaveRequests = (leaveRes as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } else if (leaveRes is Map && leaveRes.containsKey('data')) {
        leaveRequests = ((leaveRes['data'] ?? []) as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }

      // 3. Build name map from profiles
      Map<String, String> userNames = {};
      if (profilesRes is List) {
        for (var p in profilesRes) {
          final pm = p as Map;
          userNames[pm['id'].toString()] = pm['display_name']?.toString() ?? pm['id'].toString();
        }
      } else if (profilesRes is Map && profilesRes.containsKey('data')) {
        for (var p in (profilesRes['data'] ?? []) as List) {
          final pm = p as Map;
          userNames[pm['id'].toString()] = pm['display_name']?.toString() ?? pm['id'].toString();
        }
      }

      // 4. Normalize leave data
      _departmentLeaveSchedule = leaveRequests.map((leave) {
        final uid = leave['user_id']?.toString() ?? '';
        leave['start_date'] = leave['start']?.toString() ?? leave['start_date']?.toString() ?? '';
        leave['end_date'] = leave['end_time']?.toString() ?? leave['end_date']?.toString() ?? '';
        leave['days'] = leave['days_count'] ?? leave['days'] ?? 0;
        leave['applicant'] = userNames[uid] ?? uid;
        
        if (leave.containsKey('approved')) {
          leave['status'] = leave['approved'] == true ? 'approved' : 'pending';
        } else {
          leave['status'] = leave['status'] ?? 'pending';
        }
        
        return leave;
      }).toList();

      // Sort by start date
      _departmentLeaveSchedule.sort((a, b) {
        final dateA = DateTime.tryParse(a['start_date'] ?? '');
        final dateB = DateTime.tryParse(b['start_date'] ?? '');
        if (dateA == null || dateB == null) return 0;
        return dateA.compareTo(dateB);
      });

      if (mounted) {
        setState(() => _loadingDepartmentLeave = false);
      }
    } catch (e, st) {
      debugPrint('Load department leave schedule failed: $e\n$st');
      if (mounted) {
        setState(() {
          _departmentLeaveSchedule = [];
          _loadingDepartmentLeave = false;
        });
      }
    }
  }

  // === 兼容不同版本的 Supabase 查询 ===
  Future<dynamic> _runQuery(dynamic builder) async {
    final b = builder as dynamic;
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
    if (b is Future) return await b;
    return b;
  }

  // === 加载请假请求 ===
  Future<void> _loadLeaveRequests() async {
    setState(() => _loadingLeave = true);
    try {
      final currentUser = supabase.auth.currentUser;
      final userId = currentUser?.id;

      dynamic builder = supabase.from('verlof').select();
      if (userId != null) builder = (builder as dynamic).eq('user_id', userId);

      final response = await _runQuery(builder);
      List rows = [];
      if (response == null) {
        rows = [];
      } else if (response is List) {
        rows = List.from(response);
      } else if (response is Map && response.containsKey('data')) {
        final d = response['data'];
        if (d is List) rows = List.from(d);
        else if (d != null) rows = [d];
      } else {
        rows = [response];
      }

      if (rows.isEmpty) {
        final legacy = await _runQuery(supabase.from('leave_requests').select());
        if (legacy is List) rows = List.from(legacy);
        else if (legacy is Map && legacy.containsKey('data')) {
          final d = legacy['data'];
          if (d is List) rows = List.from(d);
          else if (d != null) rows = [d];
        }
      }

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

      _leaveRequests = rows.map<Map<String, dynamic>>((e) {
        final map = Map<String, dynamic>.from(e as Map);
        map['start_date'] = map['start']?.toString() ?? map['start_date']?.toString() ?? '';
        map['end_date'] = map['end_time']?.toString() ?? map['end_date']?.toString() ?? '';
        map['days'] = map['days_count'] ?? map['days'] ?? map['days']?.toInt();
        if (map.containsKey('approved')) {
          final approved = map['approved'];
          map['status'] = approved == true ? 'approved' : 'pending';
        } else {
          map['status'] = map['status'] ?? 'pending';
        }
        final uid = map['user_id']?.toString();
        if (map['applicant'] == null || map['applicant'].toString().isEmpty) {
          if (uid != null) {
            if (uid == userId) {
              map['applicant'] = currentUser?.userMetadata?['display_name'] ?? 'You';
            } else if (nameById.containsKey(uid)) {
              map['applicant'] = nameById[uid];
            } else {
              map['applicant'] = uid;
            }
          } else {
            map['applicant'] = map['applicant'] ?? (currentUser?.userMetadata?['display_name'] ?? 'You');
          }
        }
        return map;
      }).toList();
    } catch (e, st) {
      debugPrint('Load leave failed: $e\n$st');
      _leaveRequests = [];
    } finally {
      if (mounted) setState(() => _loadingLeave = false);
    }
  }

  // === 侧边栏点击 ===
  void _onSidebarTap(String label) {
    if (label == 'Team') {
      setState(() => _selectedSection = _Section.team);
    } else if (label == 'Home') {
      setState(() => _selectedSection = _Section.home);
    } else if (label == 'Messages') {
      setState(() => _selectedSection = _Section.messages);
    } else if (label == 'Leave') {
      setState(() => _selectedSection = _Section.leave);
      _loadLeaveRequests();
    }
  }

  // === 账户设置弹窗 ===
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

                        try {
                          final bytes = await picked.readAsBytes();
                          await supabase.storage.from(bucket).uploadBinary(storagePath, bytes);
                          final publicUrl = supabase.storage.from(bucket).getPublicUrl(storagePath);
                          setStateDialog(() => localAvatar = publicUrl);
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
                  if (passwordController.text.isNotEmpty && passwordController.text != confirmPasswordController.text) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match!')));
                    return;
                  }

                  try {
                    if (localAvatar != null && localAvatar != user?.userMetadata?['avatar_url']) {
                      await supabase.auth.updateUser(UserAttributes(data: {'avatar_url': localAvatar}));
                      setState(() => _avatarUrl = localAvatar);
                    }
                    if (usernameController.text.isNotEmpty && usernameController.text != user?.userMetadata?['display_name']) {
                      await supabase.auth.updateUser(UserAttributes(data: {'display_name': usernameController.text}));
                    }
                    if (emailController.text.isNotEmpty && emailController.text != user?.email) {
                      await supabase.auth.updateUser(UserAttributes(email: emailController.text));
                    }
                    if (passwordController.text.isNotEmpty) {
                      await supabase.auth.updateUser(UserAttributes(password: passwordController.text));
                    }
                  } catch (e, st) {
                    debugPrint('Account update error: $e\n$st');
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: ${e.toString()}')));
                    return;
                  }

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account updated!')));
                  setState(() {});
                },
                child: const Text('Save'),
              ),
            ],
          );
        });
      },
    );
  }

  // === 内容区域 ===
  Widget _buildContent() {
    if (_selectedSection == _Section.team) {
      if (_loadingDepartmentLeave) return const Center(child: CircularProgressIndicator());
      if (_departmentLeaveSchedule.isEmpty) {
        return const Center(
          child: Text(
            'Geen afdelingsverlofschema beschikbaar.',
            style: TextStyle(color: Colors.black54),
          ),
        );
      }
      return SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Verlofschema: $_userDepartment',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Column(
              children: _departmentLeaveSchedule.map((leave) {
                final start = DateTime.tryParse(leave['start_date'] ?? '');
                final end = DateTime.tryParse(leave['end_date'] ?? '');
                final days = leave['days'] ?? (start != null && end != null ? end.difference(start).inDays + 1 : 0);
                final status = (leave['status'] ?? 'pending').toString();
                final applicant = leave['applicant'] ?? 'Onbekend';

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
                            Expanded(
                              child: Text(
                                applicant,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Van: ${start != null ? start.toLocal().toString().split(' ')[0] : leave['start_date']}',
                                    style: const TextStyle(color: Colors.black87),
                                  ),
                                  Text(
                                    'Tot: ${end != null ? end.toLocal().toString().split(' ')[0] : leave['end_date']}',
                                    style: const TextStyle(color: Colors.black87),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$days dag${days != 1 ? 'en' : ''}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      );
    }

    if (_selectedSection == _Section.leave) {
      if (_loadingLeave) return const Center(child: CircularProgressIndicator());
      if (_leaveRequests.isEmpty) {
        return const Center(child: Text('No leave requests found.', style: TextStyle(color: Colors.black54)));
      }
      return SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: _leaveRequests.map((r) {
            final start = DateTime.tryParse(r['start_date'] ?? '');
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
                        if ((r['applicant'] ?? '') == (supabase.auth.currentUser?.userMetadata?['display_name'] ?? ''))
                          TextButton(
                            onPressed: () async {
                              setState(() => _leaveRequests.removeWhere((x) => x['id'] == r['id']));
                              try {
                                await _runQuery(supabase.from('leave_requests').delete().eq('id', r['id']));
                              } catch (e) {
                                debugPrint('Delete failed: $e');
                              }
                            },
                            child: const Text('Withdraw'),
                          ),
                        TextButton(
                          onPressed: () {
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
      );
    }

    return const Center(child: Text('Profile Page Content Area', style: TextStyle(fontSize: 24)));
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final displayAvatar = _avatarUrl?.isNotEmpty == true ? _avatarUrl! : _defaultAvatar;
    final displayName = user?.userMetadata?['display_name'] ?? 'User Name';
    final email = user?.email ?? '';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: BackgroundContainer(
        child: Stack(  // 使用 Stack 实现分层
          children: [
            // ==================== 滚动内容层 ====================
            Column(
              children: [
                HeaderBar(),

                // 可滚动的主内容
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(top: 4, left: 16, right: 16, bottom: 100), // 预留 Navbar 空间
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 用户信息卡片
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(radius: 32, backgroundImage: NetworkImage(displayAvatar)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    Text(email, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                                    if (!_loadingRole)
                                      Text(
                                        _userRole.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: _userRole == 'admin' 
                                              ? Colors.red 
                                              : _userRole == 'office_manager' 
                                                  ? Colors.purple 
                                                  : Colors.blueGrey,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.settings),
                                onPressed: () => _showAccountDialog(context, user),
                              ),
                            ],
                          ),
                        ),

                        // 侧边栏按钮组
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
                          ),
                          child: Column(
                            children: [
                              _SidebarItem(icon: Icons.home, label: 'Home', onTap: () => _onSidebarTap('Home')),
                              _SidebarItem(icon: Icons.folder, label: 'Team', onTap: () => _onSidebarTap('Team')),
                              _SidebarItem(icon: Icons.message, label: 'Messages', onTap: () => _onSidebarTap('Messages')),
                              _SidebarItem(icon: Icons.beach_access, label: 'Leave', onTap: () => _onSidebarTap('Leave')),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // 动态内容区域
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
                          ),
                          child: _buildContent(),
                        ),

                        // 底部填充（确保最后内容不被遮挡）
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // ==================== 浮动 Navbar 层（最上层） ====================
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  margin: EdgeInsets.only(bottom: 16),
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  child: Navbar(),
                ),
              ),
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

  List<Map<String, dynamic>> _leaveRequests = [];
  bool _loadingLeave = false;

  bool _loadingRole = true;
  String _userRole = 'worker';

  String? _userDepartment;
  bool _loadingDepartmentLeave = false;
  List<Map<String, dynamic>> _departmentLeaveSchedule = [];
  String? _userTeamId;

  @override
  void initState() {
    super.initState();
    final user = supabase.auth.currentUser;
    _avatarUrl = user?.userMetadata?['avatar_url'] as String?;
    _loadLeaveRequests(); 
    _loadUserRole();
    _loadUserTeam();
  }

  Future<void> _loadUserRole() async {
  final user = supabase.auth.currentUser;
  if (user == null) {
    if (mounted) setState(() => _loadingRole = false);
    return;
  }

  try {
    final response = await supabase
        .from('permissions')
        .select('role')
        .eq('user_uuid', user.id)
        .single();

    if (mounted) setState(() {
      _userRole = (response['role'] as String?)?.toLowerCase() ?? 'worker';
      _loadingRole = false;
    });
  } catch (e) {
    debugPrint('Kon rol niet ophalen: $e');
    if (mounted) setState(() {
      _userRole = 'worker';
      _loadingRole = false;
    });
  }
}

Future<void> _loadUserTeam() async {
  final user = supabase.auth.currentUser;
  if (user == null) return;

  try {
    debugPrint('Loading user team for user: ${user.id}');

    // 1. Try to find team where user is manager
    var teamRes = await _runQuery(
      supabase
          .from('teams')
          .select('id,name,users,manager')
          .eq('manager', user.id),
    );

    debugPrint('Manager teamRes: $teamRes');

    List teamList = [];
    if (teamRes is List) {
      teamList = teamRes;
    } else if (teamRes is Map && teamRes.containsKey('data')) {
      teamList = (teamRes['data'] ?? []) as List;
    } else if (teamRes is Map) {
      teamList = [teamRes];  // 单个对象
    }

    if (teamList.isNotEmpty) {
      final team = teamList.first as Map;
      if (mounted) {
        setState(() {
          _userTeamId = team['id'].toString();
          _userDepartment = team['name']?.toString() ?? 'Unnamed Team';
        });
        debugPrint('Found manager team: $_userTeamId');
      }
    } else {
      // 2. Try to find team where user is a member
      var allTeams = await _runQuery(
        supabase.from('teams').select('id,name,users'),
      );

      debugPrint('All teamsRes: $allTeams');

      List allTeamsList = [];
      if (allTeams is List) {
        allTeamsList = allTeams;
      } else if (allTeams is Map && allTeams.containsKey('data')) {
        allTeamsList = (allTeams['data'] ?? []) as List;
      } else if (allTeams is Map) {
        allTeamsList = [allTeams];
      }

      // Find team containing current user
      for (var t in allTeamsList) {
        final team = t as Map;
        final members = team['users'];
        List<String> memberIds = [];

        if (members is List) {
          memberIds = members.map((m) => m.toString()).toList();
        } else if (members is String) {
          try {
            final parsed = jsonDecode(members);
            if (parsed is List) {
              memberIds = parsed.map((m) => m.toString()).toList();
            }
          } catch (_) {}
        }

        if (memberIds.contains(user.id)) {
          if (mounted) {
            setState(() {
              _userTeamId = team['id'].toString();
              _userDepartment = team['name']?.toString() ?? 'Unnamed Team';
            });
            debugPrint('Found member team: $_userTeamId');
          }
          break;
        }
      }
    }

    debugPrint('Final _userTeamId: $_userTeamId');

    if (_userTeamId != null && _userDepartment != null && _userDepartment!.isNotEmpty) {
      await _loadDepartmentLeaveSchedule();
    } else {
      debugPrint('No team found for user, skip department leave load');
    }
  } catch (e) {
    debugPrint('Kon team niet ophalen: $e');
  }
}
  bool _departmentLoadingInProgress = false;

  Future<void> _loadDepartmentLeaveSchedule() async {
  if (_userTeamId == null || _userTeamId!.isEmpty) {
    debugPrint('No team ID, skip loading department leave');
    return;
  }

  if (_departmentLoadingInProgress) {
    debugPrint('Department loading in progress, skip duplicate call');
    return;
  }

  _departmentLoadingInProgress = true;
  if (mounted) setState(() => _loadingDepartmentLeave = true);

  debugPrint('Starting department leave load for team: $_userTeamId');

  try {
    // 1. Get team and its members
    final teamRes = await _runQuery(
      supabase
          .from('teams')
          .select('id,name,users,manager')
          .eq('id', _userTeamId!),
    );

    debugPrint('teamRes: $teamRes');

    Map teamData = {};
    if (teamRes is Map) {
      teamData = teamRes;
    } else if (teamRes is List && teamRes.isNotEmpty) {
      teamData = teamRes.first as Map;
    }

    List<String> departmentUserIds = [];

    final members = teamData['users'];
    if (members is List) {
      departmentUserIds = members.map((m) => m.toString()).toList();
    } else if (members is String) {
      try {
        final parsed = jsonDecode(members);
        if (parsed is List) {
          departmentUserIds = parsed.map((m) => m.toString()).toList();
        }
      } catch (e) {
        debugPrint('Parse users failed: $e');
      }
    }

    final managerId = teamData['manager']?.toString();
    if (managerId != null && !departmentUserIds.contains(managerId)) {
      departmentUserIds.add(managerId);
    }

    debugPrint('departmentUserIds: $departmentUserIds');

    if (departmentUserIds.isEmpty) {
      debugPrint('No users in team, set empty schedule');
      if (mounted) setState(() {
        _departmentLeaveSchedule = [];
        _loadingDepartmentLeave = false;
      });
      _departmentLoadingInProgress = false;
      return;
    }

    // 2. Get profiles for these members
    final profilesRes = await _runQuery(
      supabase
          .from('profiles')
          .select('id,name')
          .inFilter('id', departmentUserIds),
    );

    debugPrint('profilesRes: $profilesRes');

    List<String> teamMemberIds = [];
    List<Map<String, dynamic>> profilesList = [];

    if (profilesRes is List) {
      profilesList = profilesRes.cast<Map<String, dynamic>>();
    } else if (profilesRes is Map<String, dynamic>) {
      profilesList = [profilesRes];
    } else if (profilesRes is Map && profilesRes.containsKey('data')) {
      final data = profilesRes['data'];
      if (data is List) {
        profilesList = data.cast<Map<String, dynamic>>();
      } else if (data is Map<String, dynamic>) {
        profilesList = [data];
      }
    }

    teamMemberIds = profilesList
        .map((p) => p['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty && id.length == 36)  // 过滤无效 uuid
        .toList();

    debugPrint('teamMemberIds: $teamMemberIds');

    Map<String, String> userNames = {};

    for (var p in profilesList) {
      final pm = p as Map<String, dynamic>;
      final uid = pm['id'] as String? ?? '';
      final name = pm['name'] as String? ?? uid.substring(0, 8) + '...';
      if (uid.isNotEmpty) {
        userNames[uid] = name;
      }
    }
    if (teamMemberIds.isEmpty) {
      debugPrint('No valid profiles found, but continue with departmentUserIds as fallback');
      // 临时 fallback：用 departmentUserIds（即使没 profile 名字，也能查 verlof）
      teamMemberIds = departmentUserIds;
      for (var uid in departmentUserIds) {
        userNames[uid] = uid.substring(0, 8) + '...';
      }
    }

    // 3. Get all leave requests for team members
    final leaveRes = await _runQuery(
      supabase
          .from('verlof')
          .select()
          .inFilter('user_id', teamMemberIds)
          .order('start', ascending: true),
    );

    debugPrint('leaveRes: $leaveRes');

    List<Map<String, dynamic>> leaveRequests = [];
    List leaveList = [];

    if (leaveRes is List) {
      leaveList = leaveRes;
    } else if (leaveRes is Map && leaveRes.containsKey('data')) {
      leaveList = (leaveRes['data'] ?? []) as List;
    } else if (leaveRes != null) {
      leaveList = [leaveRes];
    }

    leaveRequests = leaveList
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    debugPrint('Parsed leaveRequests count: ${leaveRequests.length}');

    // 4. Build name map from profiles
    for (var p in profilesList) {
      final pm = Map<String, dynamic>.from(p);
      userNames[pm['id'].toString()] = pm['name']?.toString() ?? pm['id'].toString().substring(0, 8) + '...';
    }

    // 5. Normalize leave data
    _departmentLeaveSchedule = leaveRequests.map((leave) {
      final uid = leave['user_id']?.toString() ?? '';

      leave['start_date'] = leave['start']?.toString() ?? '';
      leave['end_date'] = leave['end_time']?.toString() ?? '';

      leave['days'] = leave['days_count'] ?? 0;

      leave['applicant'] = userNames[uid] ?? uid;

      final verlofState = leave['verlof_state']?.toString() ?? 'pending';
      leave['status'] = verlofState;

      leave['verlof_type'] = leave['verlof_type'] ?? 'onbekend';

      return leave;
    }).toList();

    // Sort by start date
    _departmentLeaveSchedule.sort((a, b) {
      final dateA = DateTime.tryParse(a['start_date'] ?? '');
      final dateB = DateTime.tryParse(b['start_date'] ?? '');
      if (dateA == null || dateB == null) return 0;
      return dateA.compareTo(dateB);
    });

    debugPrint('Final department schedule count: ${_departmentLeaveSchedule.length}');
  } catch (e, st) {
    debugPrint('Load department leave schedule failed: $e\n$st');
  } finally {
    _departmentLoadingInProgress = false;
    if (mounted) setState(() => _loadingDepartmentLeave = false);
  }
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

  List<DataRow> _buildEmployeeRows() {
  // 先按 applicant 分组（同一个员工的多条请假合并）
  Map<String, List<Map<String, dynamic>>> grouped = {};
  for (var leave in _departmentLeaveSchedule) {
    final applicant = leave['applicant'] ?? 'Onbekend';
    grouped.putIfAbsent(applicant, () => []);
    grouped[applicant]!.add(leave);
  }

  List<DataRow> rows = [];

  grouped.forEach((name, leaves) {
    // 剩余天数（从数据库或计算，这里先用固定，后面从 leave_balance 表取）
    int vakantie = 25;  // 假设
    int persoonlijk = 5;
    int ziek = 3;

    // 每天的状态标记
    List<String> statusCells = List.filled(7, '·');  // 默认上班

    for (var leave in leaves) {
      final start = DateTime.tryParse(leave['start_date'] ?? '');
      final end = DateTime.tryParse(leave['end_date'] ?? '');
      if (start == null || end == null) continue;

      final status = leave['status']?.toLowerCase() ?? 'pending';
      String mark = 'v';  // 默认 v
      if (status == 'sick' || status == 'ziek') mark = 'z';
      if (status == 'persoonlijk') mark = 'p';

      // 简单假设当前周（你需要根据当前周日期计算）
      // 这里先用固定周一到周日演示，实际需根据当前显示周匹配日期
      for (int i = 0; i < 7; i++) {
        // 假设周一为 start 的那天，实际需计算
        statusCells[i] = mark;
      }
    }

    rows.add(DataRow(cells: [
      DataCell(Text(name)),
      DataCell(Text('$vakantie')),
      DataCell(Text('$persoonlijk')),
      DataCell(Text('$ziek')),
      ...statusCells.map((s) {
        Color bg = Colors.transparent;
        Color textColor = Colors.black;
        if (s == 'z') {
          bg = Colors.red.withOpacity(0.3);
          textColor = Colors.red;
        } else if (s == 'v') {
          bg = Colors.green.withOpacity(0.3);
        } else if (s == 'p') {
          bg = Colors.blue.withOpacity(0.3);
        } else if (s == 'w') {
          bg = Colors.grey;
        }

        return DataCell(
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
            child: Center(child: Text(s, style: TextStyle(color: textColor))),
          ),
        );
      }),
    ]));
  });

  return rows;
}

  // 在右侧 content 中加入 leave 显示
  Widget _buildRightContent() {
    if (_selectedSection == _Section.team) {
      if (_loadingDepartmentLeave) {
        return const Center(child: CircularProgressIndicator());
      }
      if (_departmentLeaveSchedule.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'Geen afdelingsverlofschema beschikbaar.',
              style: TextStyle(color: Colors.black54),
            ),
          ),
        );
      }

      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                  'Verlofschema: $_userDepartment',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      IconButton(icon: const Icon(Icons.chevron_left), onPressed: () {}),  // 后面实现翻周
                      const Text('Week 3 • 16-22 jan 2026'), 
                      IconButton(icon: const Icon(Icons.chevron_right), onPressed: () {}), // 动态日期
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 20,
                  headingRowColor: WidgetStateProperty.all(Colors.grey[200]),
                  columns: const [
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Vakantie')),
                    DataColumn(label: Text('Persoonlijk')),
                    DataColumn(label: Text('Ziek')),
                    DataColumn(label: Text('Mo')),
                    DataColumn(label: Text('Tu')),
                    DataColumn(label: Text('Wo')),
                    DataColumn(label: Text('Th')),
                    DataColumn(label: Text('Fr')),
                    DataColumn(label: Text('Sa')),
                    DataColumn(label: Text('Su')),
                  ],
                  rows: _buildEmployeeRows(),  // 下面定义
                ),
              ),
            ],
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
    if (label == 'Team') {
      setState(() {
        _selectedSection = _Section.team;
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
                                        if (!_loadingRole)
                                              Text(
                                                _userRole.toUpperCase(),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: _userRole == 'admin' 
                                                      ? Colors.red 
                                                      : _userRole == 'office_manager' 
                                                          ? Colors.purple 
                                                          : Colors.blueGrey,
                                                ),
                                              ),
                                    ],
                                  ),
                                  const SizedBox(width: 8),
                                ],
                              ),
                              const Divider(),
                              _SidebarItem(icon: Icons.home, label: 'Home', onTap: () => _onSidebarTap('Home')),
                              _SidebarItem(icon: Icons.folder, label: 'Team', onTap: () => _onSidebarTap('Team')),
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