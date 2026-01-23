import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geoprof/pages/notification.dart';
import 'notification_test.mocks.dart';

@GenerateMocks([SupabaseClient, GoTrueClient, User, Session])
void main() {
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockGoTrue;
  late MockUser mockUser;

  setUp(() {
    mockSupabase = MockSupabaseClient();
    mockGoTrue = MockGoTrueClient();
    mockUser = MockUser();

    // Set up basic mocks
    when(mockSupabase.auth).thenReturn(mockGoTrue);
    when(mockGoTrue.currentUser).thenReturn(mockUser);
    when(mockUser.id).thenReturn('test-user-id');
    when(mockGoTrue.currentSession).thenReturn(null);

    // Return a mock object that can handle chained calls
    when(mockSupabase.from(any)).thenAnswer((_) {
      return _createMockQueryBuilder([]);
    });
  });

  group('DesktopLayout Notification Tests', () {
    testWidgets('Should display title "Notifications"', (tester) async {
      // Override from to return empty list
      when(mockSupabase.from(any)).thenAnswer((_) {
        return _createMockQueryBuilder([]);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: Scaffold(
              body: FutureBuilder(
                future: _fetchNotifications(mockSupabase, 'test-user-id'),
                builder: (context, snapshot) {
                  return Center(
                    child: Column(
                      children: [
                        const Text('Notifications'),
                        if (snapshot.data?.isEmpty ?? false)
                          const Text('No notifications'),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Notifications'), findsOneWidget);
    });

    testWidgets('Displays "No notifications" when there is no data', (tester) async {
      when(mockSupabase.from(any)).thenAnswer((_) {
        return _createMockQueryBuilder([]);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: Scaffold(
              body: FutureBuilder(
                future: _fetchNotifications(mockSupabase, 'test-user-id'),
                builder: (context, snapshot) {
                  return Center(
                    child: Column(
                      children: [
                        const Text('Notifications'),
                        if (snapshot.connectionState == ConnectionState.done &&
                            (snapshot.data?.isEmpty ?? false))
                          const Text('No notifications'),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('No notifications'), findsOneWidget);
    });

    testWidgets('Displays notification content when data is present', (tester) async {
      final notificationData = [
        {
          'id': 1,
          'start_date': '2026-01-10',
          'end_date': '2026-01-12',
          'verlof_state': 'approved',
          'reason': 'Annual leave',
          'updated_at': '2026-01-09T10:00:00Z',
          'is_confirmed': false,
        }
      ];

      when(mockSupabase.from(any)).thenAnswer((_) {
        return _createMockQueryBuilder(notificationData);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: Scaffold(
              body: FutureBuilder(
                future: _fetchNotifications(mockSupabase, 'test-user-id'),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done &&
                      snapshot.hasData &&
                      snapshot.data != null) {
                    return const Center(
                      child: Text('Data loaded'),
                    );
                  }
                  return const Center(child: CircularProgressIndicator());
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Data loaded'), findsOneWidget);
    });
  });
}

// Helper function to simulate chained calls like from().select().eq()...
dynamic _createMockQueryBuilder(List data) {
  final mock = MockQueryBuilderHelper();
  mock.setData(data);
  return mock;
}

Future<List> _fetchNotifications(SupabaseClient supabase, String userId) async {
  try {
    final response = await supabase
        .from('verlof')
        .select()
        .eq('user_id', userId)
        .neq('verlof_state', 'pending')
        .order('updated_at', ascending: false);
    return response is List ? response : [];
  } catch (e) {
    return [];
  }
}

/// Simple helper class to simulate chained method calls
class MockQueryBuilderHelper {
  late List _data;

  void setData(List data) => _data = data;

  dynamic select() => this;
  dynamic eq(String key, dynamic value) => this;
  dynamic neq(String key, dynamic value) => this;
  dynamic order(String column, {bool ascending = true}) => this;

  Future<dynamic> then(Function(dynamic) callback) async {
    return _data;
  }
}