import 'package:flutter/material.dart';
import 'package:geoprof/components/navbar.dart';
import 'package:geoprof/components/header_bar.dart';
import 'package:geoprof/components/background_container.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isAdmin = false;
  bool _checkingAdmin = true;

  @override
  void initState() {
    super.initState();
    _checkIsAdmin();
  }

  Future<void> _checkIsAdmin() async {
    setState(() => _checkingAdmin = true);
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) {
        _isAdmin = false;
      } else {
        // try to read the permissions row for this user
        dynamic res;
        try {
          // try maybeSingle (common in SDKs)
          res = await supabase.from('permissions').select('role').eq('user_uuid', user.id).maybeSingle();
        } catch (_) {
          // fallback to select then take first item
          final list = await supabase.from('permissions').select('role').eq('user_uuid', user.id).limit(1);
          if (list is List && list.isNotEmpty) res = list.first;
        }
        if (res != null && res is Map && (res['role']?.toString().toLowerCase() == 'admin')) {
          _isAdmin = true;
        } else {
          _isAdmin = false;
        }
      }
    } catch (e) {
      debugPrint('Check admin failed: $e');
      _isAdmin = false;
    } finally {
      if (mounted) {
        setState(() => _checkingAdmin = false);
      }
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: Column(
                children: [
                  const SizedBox(height: 16.0),
                  Card(
                    elevation: 4.0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Text(
                            'Welcome to GeoProfs! With this app you can easily plan your days off',
                            style: TextStyle(
                              fontSize: 20.0,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          // Admin button area
                          if (_checkingAdmin)
                            const SizedBox(height: 24, width: 24, child: CircularProgressIndicator())
                          else if (_isAdmin)
                            ElevatedButton.icon(
                              icon: const Icon(Icons.admin_panel_settings),
                              label: const Text('Admin Panel'),
                              onPressed: () => Navigator.pushNamed(context, '/admin'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Expanded(
              child: Center(),
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