import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:werkkernerp/ui/screens/online/online_login_screen.dart';

import 'online_test_server.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Gruppe, Lieferant, Artikel mit EK anlegen → 130 € kalkuliert, Position übernimmt den Preis', (tester) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final server = OnlineTestServer();
    await tester.runAsync(() async {
      final token = await server.seedCompany(
        email: 'kay@example.com',
        companyName: 'Elektro Kay',
        permissions: ['articles.read', 'articles.write', 'customers.read', 'customers.write', 'invoices.read', 'invoices.write'],
      );
      await server.post('/customers', {'name': 'Meyer'}, token);
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
    await tester.tap(find.byIcon(Icons.inventory_2_outlined).last);
    await tester.pumpAndSettle();

    Future<void> fill(String key, String value) => tester.enterText(find.byKey(Key('online-form-$key')), value);

    // Gruppe
    await tester.tap(find.text('Gruppen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gruppe anlegen'));
    await tester.pumpAndSettle();
    await fill('name', 'Kabel');
    await fill('markup', '30');
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(find.text('Aufschlag 30,0 %'), findsOneWidget);

    // Lieferant
    await tester.tap(find.text('Lieferanten'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lieferant anlegen'));
    await tester.pumpAndSettle();
    await fill('name', 'Großhandel Nord');
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(find.text('Großhandel Nord'), findsOneWidget);

    // Artikel mit Gruppe + Standardlieferant
    await tester.tap(find.text('Artikel').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Artikel anlegen'));
    await tester.pumpAndSettle();
    await fill('name', 'NYM 3x1,5');
    await fill('unit', 'm');
    await tester.tap(find.byKey(const Key('online-form-articleGroupId')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Kabel (+30').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('online-form-defaultSupplierId')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Großhandel Nord').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(find.textContaining('kein Preis'), findsOneWidget, reason: 'ohne EK kein Preis');

    // Einkaufspreis im Detail
    await tester.tap(find.text('NYM 3x1,5'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Einkaufspreis hinzufügen'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('online-form-supplierId')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Großhandel Nord').last);
    await tester.pumpAndSettle();
    await fill('price', '100');
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(find.text('Standardlieferant'), findsOneWidget);
    expect(find.text('130,00 € netto'), findsWidgets);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.textContaining('130,00 € netto / m'), findsOneWidget);

    // Neue Rechnung: Artikel-Position übernimmt den kalkulierten Preis.
    await tester.tap(find.byIcon(Icons.receipt_long_outlined).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Neues Dokument'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('online-new-document-customer')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Meyer').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anlegen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Position hinzufügen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Artikel').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Artikel aus Stamm (optional)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('NYM 3x1,5').last);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '130,00'), findsOneWidget);
  });
}
