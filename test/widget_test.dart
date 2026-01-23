// test/widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:geoprof/main.dart';

void main() {
  setUpAll(() async {
    WidgetsFlutterBinding.ensureInitialized();

    SharedPreferences.setMockInitialValues({});

    await Supabase.initialize(
      url: 'https://fake.supabase.co',
      anonKey: 'fake',
      debug: false,
    );
  });

  testWidgets('App start zonder crash – smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Directionality), findsAtLeastNWidgets(1));
    expect(find.byType(Scaffold), findsAtLeastNWidgets(1));
  });
}
