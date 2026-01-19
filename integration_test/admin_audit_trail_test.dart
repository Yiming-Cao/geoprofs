import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:geoprof/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Admin kan Audit Trail openen en logs zien',
    (WidgetTester tester) async {
      // ===== START APP =====
      app.main();
      await tester.pumpAndSettle();

      // ===== ADMIN PAGINA GELADEN =====
      expect(find.byKey(const Key('admin_page')), findsOneWidget);

      // ===== KLIK AUDIT TRAIL =====
      final auditTrailButton = find.byKey(const Key('audit_trail_button'));
      expect(auditTrailButton, findsOneWidget);

      await tester.tap(auditTrailButton);
      await tester.pumpAndSettle();

      // ===== AUDIT TRAIL PAGINA =====
      expect(find.byKey(const Key('audit_trail_page')), findsOneWidget);

      // ===== LOGS TABEL ZICHTBAAR =====
      expect(find.byKey(const Key('audit_trail_table')), findsOneWidget);
    },
  );
}
