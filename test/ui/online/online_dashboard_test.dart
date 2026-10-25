import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:werkkernerp/ui/screens/online/online_login_screen.dart';

import 'online_test_server.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Übersicht als Einstieg: Kacheln nach Rechten, ausblenden je Nutzer', (tester) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final server = OnlineTestServer();
    await tester.runAsync(() async {
      final token = await server.seedCompany(
        email: 'kay@example.com',
        companyName: 'Elektro Kay',
        permissions: ['invoices.read', 'invoices.write', 'invoices.finalize', 'invoices.payment', 'customers.read', 'customers.write'],
      );
      final customer = await server.post('/customers', {'name': 'Meyer'}, token);
      final draft = await server.post('/documents', {
        'kind': 'invoice',
        'customerId': customer['id'],
        'items': [
          {'kind': 'text', 'description': 'x', 'quantity': '1', 'unitPriceCents': 10000, 'vatRatePercent': 19},
        ],
      }, token);
      await server.post('/documents/${draft['id']}/finalize', {'version': draft['version']}, token);
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

    expect(find.byKey(const Key('dashboard-openInvoices')), findsOneWidget);
    expect(find.byKey(const Key('dashboard-revenue')), findsOneWidget);
    expect(find.text('119,00 €'), findsWidgets);

    await tester.tap(find.text('Anpassen'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('online-form-revenue')));
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dashboard-revenue')), findsNothing);
    expect(find.byKey(const Key('dashboard-openInvoices')), findsOneWidget);
  });
}
