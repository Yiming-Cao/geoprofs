import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geoprof/components/header_bar.dart';
import 'package:geoprof/components/navbar.dart';
import 'package:geoprof/components/background_container.dart';
import 'package:geoprof/components/protected_route.dart';

class NotificationPage extends StatelessWidget {
  const NotificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ProtectedRoute(
      child: (Theme.of(context).platform == TargetPlatform.android || Theme.of(context).platform == TargetPlatform.iOS)
          ? const MobileLayout()
          : const DesktopLayout(),
    );
  }
}

class MobileLayout extends StatelessWidget {
  const MobileLayout({super.key});

  @override
  Widget build(BuildContext context) {
    // For now, reuse a simple scaffold similar to Desktop but adapted to mobile
    return const Scaffold(body: Center(child: Text('Notifications (mobile) - coming soon')));
  }
}

class DesktopLayout extends StatefulWidget {
  const DesktopLayout({super.key});

  @override
  State<DesktopLayout> createState() => _DesktopLayoutState();
}

class _DesktopLayoutState extends State<DesktopLayout> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

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

  Future<void> _fetchNotifications() async {
    setState(() => _loading = true);
    final user = supabase.auth.currentUser;
    final userId = user?.id;
    if (userId == null) {
      setState(() {
        _notifications = [];
        _loading = false;
      });
      return;
    }

    try {
      dynamic builder = supabase.from('verlof').select();
      builder = (builder as dynamic).eq('user_id', userId).neq('status', 'pending').order('updated_at', const {'ascending': false});

      final response = await _runQuery(builder);
      List rows = [];
      if (response == null) rows = [];
      else if (response is List) rows = List.from(response);
      else if (response is Map && response.containsKey('data')) {
        final d = response['data'];
        if (d is List) rows = List.from(d);
      } else rows = [response];

      setState(() {
        _notifications = rows.map<Map<String, dynamic>>((r) {
          final m = Map<String, dynamic>.from(r as Map);
          return {
            'id': m['id'],
            'start_date': m['start_date'] ?? m['start'] ?? '',
            'end_date': m['end_date'] ?? m['end_time'] ?? '',
            'status': m['status'] ?? '',
            'reason': m['reason'] ?? '',
            'updated_at': m['updated_at'] ?? m['updated_at'],
          };
        }).toList();
      });
    } catch (e) {
      debugPrint('Fetch notifications failed: $e');
      setState(() => _notifications = []);
    } finally {
      if (mounted) setState(() => _loading = false);
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
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(top: 4, left: 16, right: 16, bottom: 100),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
                        ),
                        child: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      ),

                      if (_loading)
                        const Center(child: CircularProgressIndicator())
                      else if (_notifications.isEmpty)
                        const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No notifications', style: TextStyle(color: Colors.black54))))
                      else
                        Column(
                          children: _notifications.map((n) {
                            final status = (n['status'] ?? '').toString();
                            final start = n['start_date']?.toString() ?? '';
                            final end = n['end_date']?.toString() ?? '';
                            final title = 'Your leave request from $start to $end was ${status.toUpperCase()}';
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    if ((n['reason'] ?? '').toString().isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(n['reason'].toString()),
                                    ],
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton(onPressed: () {}, child: const Text('Details')),
                                      ],
                                    )
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                      const SizedBox(height: 80),
                    ]),
                  ),
                ),
              ],
            ),

            // Floating navbar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  child: const Navbar(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
