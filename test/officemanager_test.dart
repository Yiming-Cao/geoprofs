import 'package:flutter_test/flutter_test.dart';

import 'package:geoprof/pages/officemanager.dart';

void main() {
  testWidgets('User create test', (WidgetTester tester) async {
    var officeManagerPage = OfficeManagerDashboard();

    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}
