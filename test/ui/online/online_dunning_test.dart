import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:werkkernerp/ui/screens/online/online_login_screen.dart';

import 'online_test_server.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Überfällige Rechnung mit Gebühr, Mahnung erstellen öffnet das Mahnschreiben', (tester) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final server = OnlineTestServer();
    final due = DateTime.now().toUtc().subtract(const Duration(days: 20));
    final dueText = '${due.year}-${due.month.toString().padLeft(2, '0')}-${due.day.toString().padLeft(2, '0')}';
    await tester.runAsync(() async {
      final token = await server.seedCompany(
        email: 'kay@example.com',
        companyName: 'Elektro Kay',
        permissions: ['dunning.read', 'dunning.write', 'invoices.read', 'invoices.write', 'invoices.finalize', 'invoices.payment', 'customers.read', 'customers.write'],
      );
      await server.put('/company/modules', {'modules': ['dunning']}, token);
      await server.put('/dunning/settings', {'feeLevel2Cents': 500}, token);
      final customer = await server.post('/customers', {'name': 'Meyer'}, token);
      final draft = await server.post('/documents', {
        'kind': 'invoice',
        'customerId': customer['id'],
        'items': [
          {'kind': 'text', 'description': 'Installation', 'quantity': '1', 'unitPriceCents': 10000, 'vatRatePercent': 0},
        ],
      }, token);
      final finalized = await server.post('/documents/${draft['id']}/finalize', {'version': draft['version']}, token);
      await server.put('/documents/${finalized['id']}/due-date', {'dueDate': dueText}, token);
    });

    await tester.pumpWidget(MaterialApp(
      home: OnlineLoginScreen(clientFactory: (_) => server.client(), offlineStoreFactory: () => null),
    ));
    await tester.enterText(find.byKey(const Key('online-server')), 'erp.example.org');
    await tester.enterText(find.byKey(const Key('online-email')), 'kay@example.com');
    await tester.enterText(find.byKey(const Key('online-password')), 'passwort-12345');
    await tester.tap(find.text('Anmelden'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elektro Kay'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.notification_important_outlined).last);
    await tester.pumpAndSettle();

    expect(find.textContaining('2. Mahnstufe'), findsOneWidget, reason: '20 Tage ≥ 14 (Vorgabe)');
    expect(find.text('105,00 €'), findsOneWidget);
    await tester.tap(find.textContaining('Meyer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2. Mahnung erstellen'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(PdfPreview), findsOneWidget);
    expect(find.textContaining('2. Mahnung'), findsWidgets);
  });
}
