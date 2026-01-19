import 'package:flutter_test/flutter_test.dart';

int _calculateWorkdays(DateTime start, DateTime end) {
  if (start.isAfter(end)) return 0;
  
  int workdays = 0;
  DateTime current = start;
  
  while (!current.isAfter(end)) {
    if (current.weekday < 6) {
      workdays++;
    }
    current = current.add(Duration(days: 1));
  }
  
  return workdays;
}

void main() {
  group('calculateWorkdays', () {
    test('returns correct number of weekdays (Monday to Friday)', () {
      final start = DateTime(2025, 1, 6);  // Monday
      final end   = DateTime(2025, 1, 10); // Friday
      expect(_calculateWorkdays(start, end), 5); // Mon-Fri = 5 days
    });

    test('excludes weekends (Saturday & Sunday)', () {
      final start = DateTime(2025, 1, 3);  // Friday
      final end   = DateTime(2025, 1, 6);  // Monday
      expect(_calculateWorkdays(start, end), 2);
    });

    test('same day (weekday) returns 1', () {
      final day = DateTime(2025, 1, 8); // Wednesday
      expect(_calculateWorkdays(day, day), 1);
    });

    test('same day (weekend) returns 0', () {
      final saturday = DateTime(2025, 1, 4);
      expect(_calculateWorkdays(saturday, saturday), 0);
    });

    test('full week (7 days) returns 5 workdays', () {
      final start = DateTime(2025, 1, 6); // Mon
      final end   = DateTime(2025, 1, 12); // Sun
      expect(_calculateWorkdays(start, end), 5);
    });

    test('start after end returns 0', () {
      final start = DateTime(2025, 1, 10);
      final end   = DateTime(2025, 1, 6);
      expect(_calculateWorkdays(start, end), 0);
    });

    test('handles multi-week range correctly', () {
      final start = DateTime(2025, 1, 1); // Wed
      final end   = DateTime(2025, 1, 31); // Fri
      expect(_calculateWorkdays(start, end), 23);
    });
  });
}