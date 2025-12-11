import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Navbar extends StatefulWidget {
  const Navbar({super.key});

  @override
  State<Navbar> createState() => _NavbarState();
}

class _NavbarState extends State<Navbar> {
  int _selectedIndex = -1;
  final supabase = Supabase.instance.client;

  bool _isLoggedIn = false;
  bool _isAdmin = false;
  bool _isOfficeManager = false;

  @override
  void initState() {
    super.initState();
    _checkAuthAndRole();
    
    // Luister naar login/logout veranderingen
    supabase.auth.onAuthStateChange.listen((_) {
      _checkAuthAndRole();
    });
  }

  Future<void> _checkAuthAndRole() async {
    final user = supabase.auth.currentUser;

    setState(() {
      _isLoggedIn = user != null;
    });

    if (user == null) {
      setState(() => _isAdmin = false);
      setState(() {
        _isOfficeManager = false;
      });
      return;
    }

    try {
      final response = await supabase
          .from('permissions')
          .select('role')
          .eq('user_uuid', user.id)
          .maybeSingle();

      final bool isAdmin = response != null && (response['role'] as String?) == 'admin';
      final bool isOfficeManager = response != null && (response['role'] as String?) == 'office_manager';

      if (mounted) {
        setState(() => _isAdmin = isAdmin);
        setState(() => _isOfficeManager = isOfficeManager);
      }
    } catch (e) {
      // Als er iets misgaat → geen admin rechten tonen
      if (mounted) {
        setState(() => _isAdmin = false);
        setState(() => _isOfficeManager = false);
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    final route = _getRouteForIndex(index);
    if (route != null) {
      Navigator.pushNamed(context, route);
    }
  }

  String? _getRouteForIndex(int index) {
    return switch (index) {
      0 => '/verlof',
      1 => _isLoggedIn ? '/profile' : '/login',
      2 => '/',
      3 => '/mail',
      4 => '/notifications',
      5 => '/admin',
      6 => '/officemanager',
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width.clamp(280, 340),
      height: 48,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(Icons.calendar_today, 0),
          _buildNavItem(Icons.person, 1),

          // Home knop (rood)
          SizedBox(
            width: 40,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFFEE6055),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.home, size: 24),
                color: Colors.white,
                onPressed: () => _onItemTapped(2),
              ),
            ),
          ),

          _buildNavItem(Icons.mail, 3),
          _buildNavItem(Icons.notifications, 4),

          // ADMIN ICOON → ALLEEN VOOR ADMINS (zelfde check als admin.dart)
          if (_isAdmin)
            _buildNavItem(Icons.admin_panel_settings, 5),
          // Office Manager 图标 → 仅限办公室经理
          if (_isOfficeManager)
            _buildNavItem(Icons.business, 6),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index) {
    return SizedBox(
      width: 40,
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 24),
        color: _selectedIndex == index ? const Color(0xFFEE6055) : Colors.white,
        onPressed: () => _onItemTapped(index),
      ),
    );
  }
}