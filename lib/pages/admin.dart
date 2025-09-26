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
    // return Scaffold(
    //   appBar: AppBar(
    //     title: const Text('Admin Page'),
    //   ), 
    //   body: Center(
    //     child: Column(
    //       mainAxisAlignment: MainAxisAlignment.center,
    //       children: [
    //         const Text(
    //           'Welkom op de admin pagina',
    //           style: TextStyle(fontSize: 24),
    //         ),
    //         const SizedBox(height: 32),
    //         ElevatedButton(
    //           onPressed: () {
    //             Navigator.of(context).push(
    //               MaterialPageRoute(
    //                 builder: (context) => const AuditTrailPage(),
    //               ),
    //             );
    //           },
    //           child: const Text('Bekijk Audit Trail'),
    //         ),
    //       ],
    //     ),
    //   ),
    // );
  }
}

class AuditTrailPage extends StatelessWidget {
  const AuditTrailPage({super.key});

  @override
  Widget build(BuildContext context) {
    // voorbeeld data 
    final List<Map<String, String>> auditTrail = [
      {'user': 'admin', 'action': 'Ingelogd', 'timestamp': '2024-06-10 09:00'},
      {'user': 'user1', 'action': 'Data gewijzigd', 'timestamp': '2024-06-10 09:05'},
      {'user': 'admin', 'action': 'Gebruiker toegevoegd', 'timestamp': '2024-06-10 09:10'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Trail'),
      ),
      body: ListView.builder(
        itemCount: auditTrail.length,
        itemBuilder: (context, index) {
          final entry = auditTrail[index];
          return ListTile(
            leading: const Icon(Icons.history),
            title: Text('${entry['user']} - ${entry['action']}'),
            subtitle: Text(entry['timestamp'] ?? ''),
          );
        },
      ),
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

class DesktopLayout extends StatelessWidget {
  const DesktopLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Page - Desktop'),
      ),
      body: const Center(
        child: Text(
          'This is the desktop layout for the Admin Page.',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}