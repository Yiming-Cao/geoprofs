import 'package:flutter_test/flutter_test.dart';

/// Fake functie die een fout gooit
Future<List<Map<String, dynamic>>> fetchLogsError() async {
  throw Exception('Fout bij laden');
}

void main() {
  test('fetchLogs gooit een exception bij fout', () async {
    expect(
      () async => await fetchLogsError(),
      throwsException,
    );
  });
}
