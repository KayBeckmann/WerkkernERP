import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:werkkernerp/ui/screens/online/online_login_screen.dart';

import 'online_test_server.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> login(WidgetTester tester, OnlineTestServer server) async {
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
  }

  testWidgets('Bestand korrigieren, Unterbestand, Inventur abschließen, Warnung beim Finalisieren', (tester) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final server = OnlineTestServer();
    await tester.runAsync(() async {
      final token = await server.seedCompany(
        email: 'kay@example.com',
        companyName: 'Elektro Kay',
        permissions: ['articles.read', 'articles.write', 'stock.read', 'stock.write', 'invoices.read', 'invoices.write', 'invoices.finalize', 'customers.read', 'customers.write'],
      );
      await server.put('/company/modules', {'modules': ['lagerbestand']}, token);
      final customer = await server.post('/customers', {'name': 'Meyer'}, token);
      final article = await server.post('/articles', {'name': 'Kabel', 'unit': 'm', 'minimumStock': '50'}, token);
      await server.post('/documents', {
        'kind': 'invoice',
        'customerId': customer['id'],
        'items': [
          {'kind': 'article', 'articleId': article['id'], 'description': 'Kabel', 'quantity': '60', 'unitPriceCents': 100, 'vatRatePercent': 19},
        ],
      }, token);
    });
    await login(tester, server);

    // Artikel: Bestand korrigieren
    await tester.tap(find.byIcon(Icons.inventory_2_outlined).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kabel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bestand korrigieren'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('online-form-counted')), '40');
    await tester.enterText(find.byKey(const Key('online-form-reason')), 'Anfangsbestand');
    await tester.tap(find.text('Buchen'));
    await tester.pumpAndSettle();
    expect(find.text('40 m'), findsOneWidget);
    expect(find.textContaining('Inventur/Korrektur · Anfangsbestand'), findsOneWidget);
    tester.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger)).removeCurrentSnackBar();
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Lager: Unterbestand + Inventur
    await tester.tap(find.byIcon(Icons.warehouse_outlined).last);
    await tester.pumpAndSettle();
    expect(find.textContaining('fehlen 10'), findsOneWidget);
    await tester.tap(find.text('Inventur'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inventur starten'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anlegen'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Soll 40 m'), findsOneWidget);
    await tester.tap(find.text('Kabel'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('online-form-counted')), '55,5');
    await tester.tap(find.text('Übernehmen'));
    await tester.pumpAndSettle();
    expect(find.textContaining('gezählt 55,5'), findsOneWidget);
    await tester.tap(find.text('Inventur abschließen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abschließen'));
    await tester.pumpAndSettle();
    expect(find.textContaining('abgeschlossen'), findsWidgets);
    tester.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger)).removeCurrentSnackBar();
    expect(find.text('Inventur abschließen'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bewegungen'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Kabel: +15,5 → 55,5'), findsOneWidget);

    // Dokument mit 60 m: Warnung beim Finalisieren, aber nicht blockierend.
    await tester.tap(find.byIcon(Icons.receipt_long_outlined).last);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Meyer').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finalisieren'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Bestand zu gering: Kabel — benötigt 60, vorhanden 55,5'), findsOneWidget);
    await tester.tap(find.text('Finalisieren').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('finalisiert'), findsWidgets);
  });
}
