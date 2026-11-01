import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:werkkernerp/ui/screens/online/online_login_screen.dart';

import 'online_test_server.dart';

/// Stammdaten/Lager online wie offline: Mindestbestand rot, Artikel über
/// die Titelleiste deaktivieren, Bestellung einer Rechnung zuordnen,
/// Rückfrage bei nicht erreichter Mindestbestellmenge, Inventur mit
/// Mehrfachauswahl.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Mindestbestand, Deaktivieren, Zuordnung, Mindestbestellmenge, Inventur-Mehrfachauswahl', (tester) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final server = OnlineTestServer();
    final yy = (DateTime.now().toUtc().year % 100).toString().padLeft(2, '0');
    await tester.runAsync(() async {
      final token = await server.seedCompany(
        email: 'kay@example.com',
        companyName: 'Elektro Kay',
        permissions: [
          'customers.read', 'customers.write', 'articles.read', 'articles.write', 'invoices.read', 'invoices.write',
          'invoices.finalize', 'stock.read', 'stock.write', 'purchaseOrders.read', 'purchaseOrders.write',
        ],
      );
      await server.put('/company/modules', {'modules': ['lagerbestand', 'bestellwesen']}, token);
      final supplier = await server.post('/suppliers', {'name': 'Großhandel Nord', 'minimumOrderQuantity': '100'}, token);
      final cable = await server.post('/articles', {'name': 'Kabel', 'minimumStock': '10', 'defaultSupplierId': supplier['id']}, token);
      await server.put('/articles/${cable['id']}/prices/${supplier['id']}', {'purchasePriceCents': 100}, token);
      await server.post('/articles', {'name': 'Dose'}, token);
      await server.post('/articles', {'name': 'Leuchte'}, token);
      final customer = await server.post('/customers', {'name': 'Meyer'}, token);
      final draft = await server.post('/documents', {
        'kind': 'invoice',
        'customerId': customer['id'],
        'items': [
          {'kind': 'text', 'description': 'Leistung', 'quantity': '1', 'unitPriceCents': 100, 'vatRatePercent': 19},
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

    // Artikel unter Mindestbestand rot markiert.
    await openTab(tester, 'Artikel');
    expect(find.textContaining('Bestand: 0 (unter Mindestbestand!)'), findsOneWidget);

    // Deaktivieren über die Titelleiste.
    await tester.tap(find.text('Leuchte'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Deaktivieren'));
    await tester.pumpAndSettle();
    expect(find.text('Leuchte (deaktiviert)'), findsOneWidget);
    expect(find.byTooltip('Aktivieren'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Leuchte'), findsNothing, reason: 'deaktivierte Artikel nicht in der Liste (wie offline)');

    // Mindestbestand-Meldung: 10 < 100 → Rückfrage, dann Entwurf.
    await openTab(tester, 'Bestellungen');
    await tester.tap(find.text('Mindestbestand'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entwurf anlegen'));
    await tester.pumpAndSettle();
    expect(find.text('Mindestbestellmenge nicht erreicht'), findsOneWidget);
    await tester.tap(find.text('Trotzdem anlegen'));
    await tester.pumpAndSettle();
    expect(find.text('Keine Zuordnung (Lagerbestellung)'), findsOneWidget);

    // Zuordnung zur finalisierten Rechnung.
    await tester.tap(find.text('Zuordnung bearbeiten'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('online-form-sourceOrderId')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('R-${yy}001 · Meyer').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(find.text('Dokument: R-${yy}001'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Inventur: Artikel per Mehrfachauswahl („Alle auswählen“).
    await openTab(tester, 'Inventur');
    await tester.tap(find.text('Neue Inventur'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('online-form-all')));
    await tester.tap(find.text('Anlegen'));
    await tester.pumpAndSettle();
    expect(find.text('Noch keine Artikel in dieser Inventur.'), findsOneWidget);
    await tester.tap(find.text('Artikel hinzufügen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alle auswählen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hinzufügen'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Soll: '), findsNWidgets(2), reason: 'Kabel und Dose (aktive Artikel)');
  });
}
