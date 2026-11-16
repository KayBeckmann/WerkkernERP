import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:werkkernerp/ui/screens/online/online_login_screen.dart';

import 'online_test_server.dart';

/// C5.4-Nachtrag (Kay, 16.11.2026) online: Lagerort und Platz anlegen,
/// umlagern, Entnahme mit Platzvorschlag, Inventur nach Lagerort.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Lagerorte online: anlegen, umlagern, Entnahme-Vorschlag, Inventur Platz für Platz', (tester) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final server = OnlineTestServer();
    late String token;
    late String articleId;
    await tester.runAsync(() async {
      token = await server.seedCompany(
        email: 'kay@example.com',
        companyName: 'Elektro Kay',
        permissions: ['articles.read', 'articles.write', 'stock.read', 'stock.write', 'invoices.read', 'invoices.write', 'invoices.finalize', 'customers.read', 'customers.write'],
      );
      await server.put('/company/modules', {'modules': ['lagerbestand']}, token);
      final customer = await server.post('/customers', {'name': 'Meyer'}, token);
      final article = await server.post('/articles', {'name': 'Kabel', 'unit': 'm'}, token);
      articleId = article['id'] as String;
      await server.post('/articles/$articleId/stock-correction', {'countedQuantity': '5', 'reason': 'Anfangsbestand'}, token);
      await server.post('/documents', {
        'kind': 'invoice',
        'customerId': customer['id'],
        'items': [
          {'kind': 'article', 'articleId': articleId, 'description': 'Kabel', 'quantity': '2', 'unitPriceCents': 100, 'vatRatePercent': 19},
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

    // Lagerort und Platz anlegen.
    await openTab(tester, 'Inventur');
    await tester.tap(find.byTooltip('Lagerorte & Plätze'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lagerort anlegen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('online-form-name')), 'Lager');
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Platz anlegen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('online-form-row')), '1');
    await tester.enterText(find.byKey(const Key('online-form-compartment')), '2');
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(find.text('Reihe 1 / Fach 2'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Artikel: Altbestand „nicht zugeordnet“ umlagern.
    await openTab(tester, 'Artikel');
    await tester.tap(find.text('Kabel'));
    await tester.pumpAndSettle();
    expect(find.text('Platz noch nicht zugeordnet: 5'), findsOneWidget);
    await tester.tap(find.byKey(const Key('online-article-transfer')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('online-form-quantity')), '5');
    await tester.tap(find.widgetWithText(FilledButton, 'Umlagern'));
    await tester.pumpAndSettle();
    expect(find.text('Lager · Reihe 1 / Fach 2: 5'), findsOneWidget);
    tester.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger).last).removeCurrentSnackBar();
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Rechnung finalisieren: Entnahme-Dialog mit vorgeschlagenem Platz.
    await openTab(tester, 'Rechnungen');
    await tester.tap(find.textContaining('Meyer').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Finalisieren'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finalisieren').last);
    await tester.pumpAndSettle();
    expect(find.text('Entnahme aus Lagerplatz'), findsOneWidget);
    expect(find.text('Lager · Reihe 1 / Fach 2 (5)'), findsOneWidget);
    await tester.tap(find.text('Weiter'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Finalisiert am'), findsOneWidget);
    final stock = await tester.runAsync(() => server.get('/articles/$articleId/bin-stock', token));
    expect([for (final s in (stock!['stocks'] as List).cast<Map>()) (s['label'], s['quantity'])], [('Lager · Reihe 1 / Fach 2', '3')]);

    // Inventur nach Lagerort: Platz für Platz.
    await openTab(tester, 'Inventur');
    await tester.tap(find.text('Neue Inventur'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('online-form-location')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lagerort Lager (Platz für Platz)').last);
    await tester.pumpAndSettle();
    expect(find.text('Alle aktiven Artikel aufnehmen'), findsNothing);
    await tester.tap(find.text('Anlegen'));
    await tester.pumpAndSettle();
    expect(find.text('Reihe 1 / Fach 2'), findsOneWidget);
    expect(find.text('Soll: 3 m'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('online-inventory-counted-Kabel-Lager · Reihe 1 / Fach 2')), '4');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inventur abschließen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abschließen'));
    await tester.pumpAndSettle();
    final after = await tester.runAsync(() => server.get('/articles/$articleId/bin-stock', token));
    expect([for (final s in (after!['stocks'] as List).cast<Map>()) s['quantity']], ['4']);
  });
}
