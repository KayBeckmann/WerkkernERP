import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:werkkernerp/ui/screens/online/online_login_screen.dart';

import 'online_test_server.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Offene Posten, Beleg erfassen, EÜR, Bankumsatz zuordnen und bezahlt markieren', (tester) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final server = OnlineTestServer();
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    await tester.runAsync(() async {
      final token = await server.seedCompany(
        email: 'kay@example.com',
        companyName: 'Elektro Kay',
        permissions: ['accounting.read', 'accounting.write', 'invoices.read', 'invoices.write', 'invoices.finalize', 'invoices.payment', 'customers.read', 'customers.write'],
      );
      await server.put('/company/modules', {'modules': ['buchhaltung']}, token);
      final customer = await server.post('/customers', {'name': 'Meyer'}, token);
      final draft = await server.post('/documents', {
        'kind': 'invoice',
        'customerId': customer['id'],
        'items': [
          {'kind': 'text', 'description': 'Installation', 'quantity': '1', 'unitPriceCents': 100000, 'vatRatePercent': 19},
        ],
      }, token);
      await server.post('/documents/${draft['id']}/finalize', {'version': draft['version']}, token);
      await server.post('/bank-transactions/import', {
        'transactions': [
          {'date': today, 'amountCents': 119000, 'purpose': 'Rechnung', 'counterparty': 'Meyer'},
        ],
      }, token);
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
    await tester.tap(find.byIcon(Icons.account_balance_outlined).last);
    await tester.pumpAndSettle();

    // Offene Posten
    expect(find.text('1190,00 €'), findsWidgets);
    expect(find.text('Meyer'), findsOneWidget);

    // Beleg erfassen
    await tester.tap(find.text('Belege'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beleg erfassen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('online-form-description')), 'Kabel Großhandel');
    await tester.enterText(find.byKey(const Key('online-form-amount')), '238');
    await tester.tap(find.byKey(const Key('online-form-categoryId')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Material/Wareneinkauf').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(find.text('Kabel Großhandel'), findsOneWidget);
    expect(find.text('238,00 €'), findsWidgets);

    // EÜR
    await tester.tap(find.text('EÜR'));
    await tester.pumpAndSettle();
    expect(find.text('952,00 €'), findsOneWidget, reason: '1190 € Einnahmen − 238 € Ausgaben');

    // Bank: zuordnen und bezahlt markieren
    await tester.tap(find.text('Bank'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zuordnen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zuordnen').last);
    await tester.pumpAndSettle();
    expect(find.text('Keine Bankumsätze.'), findsOneWidget, reason: 'nur nicht zugeordnete sichtbar');

    await tester.tap(find.text('Offene Posten'));
    await tester.pumpAndSettle();
    await tester.drag(find.text('Offen gesamt'), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(find.text('Keine offenen Rechnungen.'), findsOneWidget);
  });
}
