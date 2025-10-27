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

  // Check if user is logged in
  bool get _isLoggedIn => supabase.auth.currentUser != null;

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
    switch (index) {
      case 0:
        return '/calendar';
      case 1:
        return _isLoggedIn ? '/profile' : '/login'; // MAGIC LINE
      case 2:
        return '/dashboard';
      case 3:
        return '/mail';
      case 4:
        return '/notifications';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width.clamp(280, 320),
      height: 48,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 0 – Calendar
          _buildNavItem(Icons.calendar_today, 0),

          // 1 – Person (Login → Profile)
          _buildNavItem(Icons.person, 1),

          // 2 – Home (red circle)
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

          // 3 – Mail
          _buildNavItem(Icons.mail, 3),

          // 4 – Notifications
          _buildNavItem(Icons.notifications, 4),
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