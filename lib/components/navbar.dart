import 'package:flutter/material.dart';

class Navbar extends StatefulWidget {
  const Navbar({super.key});

  @override
  State<Navbar> createState() => _NavbarState();
}

class _NavbarState extends State<Navbar> {
  int _selectedIndex = -1;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 0) {
      Navigator.pushNamed(context, '/calendar');
    } else if (index == 1) {
      Navigator.pushNamed(context, '/login');
    } else if (index == 2) {
      Navigator.pushNamed(context, '/dashboard');
    } else if (index == 3) {
      Navigator.pushNamed(context, '/mail');
    } else if (index == 4) {
      Navigator.pushNamed(context, '/notifications');
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
          // ---- 0 – Calendar (never highlighted) ----

          SizedBox(
            width: 40,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.calendar_today, size: 24),
              color: _selectedIndex == 0
                  ? const Color(0xFFEE6055)
                  : Colors.white,
              onPressed: () => _onItemTapped(0),
            ),
          ),

          // ---- 1 – Person ----
          SizedBox(
            width: 40,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.person, size: 24),
              color: _selectedIndex == 1
                  ? const Color(0xFFEE6055)
                  : Colors.white,
              onPressed: () => _onItemTapped(1),
            ),
          ),

          // ---- 2 – Home (red circle) ----
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

          // ---- 3 – Mail ----
          SizedBox(
            width: 40,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.mail, size: 24),
              color: _selectedIndex == 3
                  ? const Color(0xFFEE6055)
                  : Colors.white,
              onPressed: () => _onItemTapped(3),
            ),
          ),

          // ---- 4 – Notifications ----
          SizedBox(
            width: 40,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.notifications, size: 24),
              color: _selectedIndex == 4
                  ? const Color(0xFFEE6055)
                  : Colors.white,
              onPressed: () => _onItemTapped(4),
            ),
          ),
        ],
      ),
    );
  }
}