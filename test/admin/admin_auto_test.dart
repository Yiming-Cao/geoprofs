import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geoprof/pages/admin.dart';

void main() {
  testWidgets('Toont melding als er geen logs zijn', (WidgetTester tester) async {
    // Arrange
    final fetcher = () async => <Map<String, dynamic>>[];

    // Act
    await tester.pumpWidget(
      MaterialApp(
        home: AuditTrailPage(fetchLogs: fetcher),
      ),
    );
    await tester.pumpAndSettle();

    // Assert
    expect(find.textContaining('Geen logs gevonden'), findsOneWidget);
  });

  testWidgets('Toont foutmelding bij error', (WidgetTester tester) async {
    // Arrange
    final fetcher =
        () => Future<List<Map<String, dynamic>>>.error(Exception('Fout bij laden'));

    // Act
    await tester.pumpWidget(
      MaterialApp(
        home: AuditTrailPage(fetchLogs: fetcher),
      ),
    );
    await tester.pumpAndSettle();

    // Assert
    expect(find.textContaining('Fout bij laden'), findsOneWidget);
  });

  testWidgets('Toont loader tijdens laden', (WidgetTester tester) async {
    // Arrange
    final fetcher = () =>
        Future.delayed(const Duration(seconds: 2), () => <Map<String, dynamic>>[]);

    // Act
    await tester.pumpWidget(
      MaterialApp(
        home: AuditTrailPage(fetchLogs: fetcher),
      ),
    );

    // Assert: loader zichtbaar terwijl future loopt
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Afronden
    await tester.pumpAndSettle();
  });
}
