import 'package:flutter/material.dart';
import 'package:geoprof/pages/dashboard.dart';
import 'package:geoprof/pages/login.dart';

class Navbar extends StatefulWidget {
  const Navbar({super.key});

  @override
  State<Navbar> createState() => _NavbarState();
}

class _NavbarState extends State<Navbar> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    switch (index) {
      case 0:
        // TODO: Add direct route for calendar page if available
        // Example: Navigator.push(context, MaterialPageRoute(builder: (context) => CalendarPage()));
        break;
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const Dashboard()),
        );
        break;
      case 3:
        // TODO: Add direct route for mail page if available
        // Example: Navigator.push(context, MaterialPageRoute(builder: (context) => MailPage()));
        break;
      case 4:
        // TODO: Add direct route for notifications page if available
        // Example: Navigator.push(context, MaterialPageRoute(builder: (context) => NotificationsPage()));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width.clamp(280, 320), // Phone-friendly width
      height: 48,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.calendar_today, size: 24),
              color: _selectedIndex == 0 ? const Color(0xFFEE6055) : Colors.white,
              onPressed: () => _onItemTapped(0),
            ),
          ),
          SizedBox(
            width: 40,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.person, size: 24),
              color: _selectedIndex == 1 ? const Color(0xFFEE6055) : Colors.white,
              onPressed: () => _onItemTapped(1),
            ),
          ),
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
          SizedBox(
            width: 40,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.mail, size: 24),
              color: _selectedIndex == 3 ? const Color(0xFFEE6055) : Colors.white,
              onPressed: () => _onItemTapped(3),
            ),
          ),
          SizedBox(
            width: 40,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.notifications, size: 24),
              color: _selectedIndex == 4 ? const Color(0xFFEE6055) : Colors.white,
              onPressed: () => _onItemTapped(4),
            ),
          ),
        ],
      ),
    );
  }
}