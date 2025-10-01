import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Toegevoegd voor kIsWeb

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Detecteer web met kIsWeb, anders gebruik MediaQuery voor layout
    if (kIsWeb) {
      return const DesktopLayout();
    } else {
      final shortestSide = MediaQuery.of(context).size.shortestSide;
      if (shortestSide < 600) {
        return const MobileLayout();
      } else {
        return const DesktopLayout();
      }
    }
  }
}

class AuditTrailPage extends StatelessWidget {
  const AuditTrailPage({super.key});

  @override
  Widget build(BuildContext context) {
    // voorbeeld data 

    return Scaffold(
      
    );
  }
}

class MobileLayout extends StatelessWidget {
  const MobileLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Page - Mobile'),
      ),
      body: const Center(
        child: Text(
          'This is the mobile layout for the Admin Page.',
          style: TextStyle(fontSize: 18),
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
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    Widget content;
    switch (_selectedIndex) {
      case 1:
        content = const AuditTrailPage();
        break;
      default:
        content = const Center(
          child: Text(
            'Welkom op de admin pagina (desktop)',
            style: TextStyle(fontSize: 24),
          ),
        );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Page - Desktop'),
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.home),
                label: Text('Home'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.history),
                label: Text('Audit Trail'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: content),
        ],
      ),
    );
  }
}