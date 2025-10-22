import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Toegevoegd voor kIsWeb
import 'package:supabase_flutter/supabase_flutter.dart';


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
  
  Future<List<Map<String, dynamic>>> getLogs() async {
    final supabase = Supabase.instance.client;
    final response = await supabase
      .from('logs')
      .select()
      .order('created_at', ascending: false);

      // print("Supabase response: $response");
    return response;
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(title: const Text("Logs")),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: getLogs(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Fout bij laden van logs: ${snapshot.error}'));
        }
        final logs = snapshot.data ?? [];
        if (logs.isEmpty) {
          return const Center(child: Text('Geen logs gevonden.'));
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal, // tabel kan horizontaal scrollen
          child: DataTable(
          columns: const [
            DataColumn(label: Text("Actie")),
            DataColumn(label: Text("Verandering")),
            DataColumn(label: Text("Was")),
            DataColumn(label: Text("User email")),
            DataColumn(label: Text("Datum")),
          ],
          rows: logs.map((log) {
            return DataRow(cells: [
              DataCell(Text(log['action'] ?? '')),
              DataCell(Text(log['change'] ?? '')),
              DataCell(Text(log['was'] ?? '')),
              DataCell(Text(log['user_email'] ?? '')),
              DataCell(Text(log['created_at']?.toString() ?? '')),
            ]);
          }).toList(),
          ),
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

class DesktopLayout extends StatefulWidget {
  const DesktopLayout({super.key});

  @override
  State<DesktopLayout> createState() => _DesktopLayoutState();
}

class _DesktopLayoutState extends State<DesktopLayout> {
  int _selectedIndex = 0;

    Future<List<Map<String, dynamic>>> getLogs() async {
    final supabase = Supabase.instance.client;
    final response = await supabase.from('logs').select();
    return response;
  }

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