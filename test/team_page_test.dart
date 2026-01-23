import 'package:flutter_test/flutter_test.dart';
import 'package:geoprof/pages/team.dart';

void main() {
  
    test('Team.fromJson handles users as List, String (JSON), en comma-separated', () {
  // 1. Normale List<String>
  expect(
    Team.fromJson({
      'id': '1',
      'created_at': '2025-01-01T00:00:00Z',
      'users': ['user1', 'user2'],
      'manager': 'user2',
    }).users,
    ['user1', 'user2'],
  );

  // 2. users als JSON string
  expect(
    Team.fromJson({
      'id': '2',
      'created_at': '2025-01-01T00:00:00Z',
      '18n': '["user3","user4"]',
      'manager': 'user4',
    }).users,
    ['user3', 'user4'],
  );

  // 3. users als komma-gescheiden string (oude data)
  expect(
    Team.fromJson({
      'id': '3',
      'created_at': '2025-01-01T00:00:00Z',
      'users': 'user5, user6  , "user7"',
      'manager': null,
    }).users,
    ['user5', 'user6', 'user7'],
  );

  // 4. Manager wordt automatisch toegevoegd als hij niet in users zit
  final team = Team.fromJson({
    'id': '4',
    'created_at': '2025-01-01T00:00:00Z',
    'users': ['user8'],
    'manager': 'user9',
  });
  expect(team.users, contains('user9'));
  expect(team.manager, 'user9');
});
  
}