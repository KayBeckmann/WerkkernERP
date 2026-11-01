import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:werkkern_client/werkkern_client.dart';
import 'package:werkkernerp/ui/screens/online/online_login_screen.dart';

import 'online_test_server.dart';

const _allPermissions = [
  'customers.read',
  'customers.write',
  'articles.read',
  'invoices.read',
  'invoices.write',
  'invoices.finalize',
  'invoices.payment',
];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> login(WidgetTester tester, OnlineTestServer server, {String email = 'kay@example.com'}) async {
    await tester.pumpWidget(MaterialApp(key: UniqueKey(), home: OnlineLoginScreen(clientFactory: (_) => server.client(), offlineStoreFactory: () => null)));
    await tester.enterText(find.byKey(const Key('online-server')), 'erp.example.org');
    await tester.enterText(find.byKey(const Key('online-email')), email);
    await tester.enterText(find.byKey(const Key('online-password')), 'passwort-12345');
    await tester.tap(find.text('Anmelden'));
    await tester.pumpAndSettle();
  }

  testWidgets('Anmeldung → Firmenwahl → Kunde anlegen → Dokument mit Position → speichern → finalisieren',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 2000);
    addTearDown(tester.view.resetPhysicalSize);
    final server = OnlineTestServer();
    await tester.runAsync(() => server.seedCompany(email: 'kay@example.com', companyName: 'Elektro Kay', permissions: _allPermissions));

    await login(tester, server);
    expect(find.text('Elektro Kay'), findsOneWidget);
    await tester.tap(find.text('Elektro Kay'));
    await tester.pumpAndSettle();
    await openTab(tester, 'Rechnungen');
    expect(find.text('Elektro Kay — Rechnungen'), findsOneWidget);
    expect(find.textContaining('keine lokale Kopie'), findsOneWidget);

    // Kunde anlegen
    await tester.tap(find.text('Kunden'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kunde anlegen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('online-customer-name')), 'Müller GmbH');
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(find.text('Müller GmbH'), findsOneWidget);

    // Dokument anlegen: Kunde wie offline per Suchdialog wählen.
    await openTab(tester, 'Rechnungen');
    await tester.tap(find.text('Neue Rechnung'));
    await tester.pumpAndSettle();
    expect(find.text('Kunde wählen'), findsOneWidget);
    await tester.tap(find.text('Müller GmbH').last);
    await tester.pumpAndSettle();
    expect(find.text('Rechnung (Entwurf) — Müller GmbH'), findsOneWidget);

    // Position hinzufügen (Stunden 1,5 × 60 € @ 19 %)
    await tester.tap(find.text('Position hinzufügen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stunden'));
    await tester.enterText(find.byKey(const Key('online-item-description')), 'Montage');
    await tester.enterText(find.byKey(const Key('online-item-quantity')), '1,5');
    await tester.enterText(find.byKey(const Key('online-item-price')), '60,00');
    await tester.tap(find.text('Hinzufügen'));
    await tester.pumpAndSettle();
    // Lokal mit demselben Rechenkern wie der Server: 90,00 + 17,10 = 107,10.
    expect(find.text('107,10 €'), findsOneWidget, reason: 'Zeilenbetrag der Position');
    expect(find.text('Gesamt: 107,10 €'), findsOneWidget);
    expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.save_outlined)).onPressed, isNotNull);
    expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.check_circle_outline)).onPressed, isNull,
        reason: 'erst speichern, dann finalisieren');

    await tester.tap(find.byTooltip('Entwurf speichern'));
    await tester.pumpAndSettle();
    expect(find.text('Entwurf gespeichert.'), findsOneWidget);

    await tester.tap(find.byTooltip('Finalisieren'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finalisieren').last);
    await tester.pumpAndSettle();
    final year = (DateTime.now().toUtc().year % 100).toString().padLeft(2, '0');
    expect(find.text('Rechnung R-${year}001 — Müller GmbH'), findsOneWidget);
    expect(find.text('Position hinzufügen'), findsNothing, reason: 'finalisiert = unveränderlich');
  });

  testWidgets('Konflikt: anderes Gerät speichert zwischendurch → 409-Dialog, nichts überschrieben', (tester) async {
    tester.view.physicalSize = const Size(1000, 2000);
    addTearDown(tester.view.resetPhysicalSize);
    final server = OnlineTestServer();
    late String docId;
    final adminToken = await tester.runAsync(() async {
      final token = await server.seedCompany(email: 'kay@example.com', companyName: 'Elektro Kay', permissions: _allPermissions);
      final customer = await server.post('/customers', {'name': 'Kunde'}, token);
      docId = (await server.post('/documents', {'customerId': customer['id']}, token))['id'] as String;
      return token;
    });

    await login(tester, server);
    await tester.tap(find.text('Elektro Kay'));
    await tester.pumpAndSettle();
    await openTab(tester, 'Rechnungen');
    await tester.tap(find.text('Kunde'));
    await tester.pumpAndSettle();

    // "Zweites Gerät" speichert Version 1 -> Server-Version ist jetzt 2.
    await tester.runAsync(() => server.put('/documents/$docId', {'version': 1, 'notes': 'vom Tablet'}, adminToken!));

    await tester.tap(find.text('Position hinzufügen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('online-item-description')), 'Anfahrt');
    await tester.enterText(find.byKey(const Key('online-item-price')), '30');
    await tester.tap(find.text('Hinzufügen'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Entwurf speichern'));
    await tester.pumpAndSettle();

    expect(find.text('Zwischenzeitlich geändert'), findsOneWidget);
    await tester.tap(find.text('Neu laden'));
    await tester.pumpAndSettle();
    expect(find.text('Anfahrt'), findsNothing, reason: 'lokale Änderung bewusst verworfen');
    expect(find.widgetWithText(TextField, 'vom Tablet'), findsOneWidget);
  });

  testWidgets('Ohne Rechte keine Tabs/Aktionen; falsches Passwort und nicht erreichbarer Server verständlich',
      (tester) async {
    final server = OnlineTestServer();
    await tester.runAsync(() => server.seedCompany(email: 'monteur@example.com', companyName: 'Firma ohne Rechte'));

    await login(tester, server, email: 'monteur@example.com');
    await tester.tap(find.text('Firma ohne Rechte'));
    await tester.pumpAndSettle();
    // Der Ersteller ist Admin: nur „Einstellungen“ (Rechte vergeben), keine Fachbereiche.
    expect(find.textContaining('noch keine Rechte zugewiesen'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.textContaining('Rechnungen'), findsNothing);

    await tester.pumpWidget(MaterialApp(key: UniqueKey(), home: OnlineLoginScreen(clientFactory: (_) => server.client(), offlineStoreFactory: () => null)));
    await tester.enterText(find.byKey(const Key('online-server')), 'erp.example.org');
    await tester.enterText(find.byKey(const Key('online-email')), 'monteur@example.com');
    await tester.enterText(find.byKey(const Key('online-password')), 'falsch');
    await tester.tap(find.text('Anmelden'));
    await tester.pumpAndSettle();
    expect(find.text('E-Mail oder Passwort falsch.'), findsOneWidget);

    final offline = WerkkernApiClient(
      baseUrl: Uri.parse('http://localhost'),
      httpClient: MockClient((_) async => throw http.ClientException('connection refused')),
    );
    await tester.pumpWidget(MaterialApp(key: UniqueKey(), home: OnlineLoginScreen(clientFactory: (_) => offline, offlineStoreFactory: () => null)));
    await tester.enterText(find.byKey(const Key('online-server')), 'erp.example.org');
    await tester.enterText(find.byKey(const Key('online-email')), 'monteur@example.com');
    await tester.enterText(find.byKey(const Key('online-password')), 'passwort-12345');
    await tester.tap(find.text('Anmelden'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Server nicht erreichbar'), findsOneWidget);
  });

  testWidgets('Finalisiertes Angebot in Auftrag umwandeln; Rechnung als bezahlt markieren', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final server = OnlineTestServer();
    await tester.runAsync(() async {
      final token = await server.seedCompany(email: 'kay@example.com', companyName: 'Elektro Kay', permissions: _allPermissions);
      await server.put('/company/modules', {'modules': ['quotes', 'orders']}, token);
      final customer = await server.post('/customers', {'name': 'Kunde'}, token);
      for (final kind in ['quote', 'invoice']) {
        final draft = await server.post('/documents', {
          'kind': kind,
          'customerId': customer['id'],
          'items': [
            {'kind': 'text', 'description': 'Leistung', 'quantity': '1', 'unitPriceCents': 10000, 'vatRatePercent': 19},
          ],
        }, token);
        await server.post('/documents/${draft['id']}/finalize', {'version': 1}, token);
      }
    });
    final year = (DateTime.now().toUtc().year % 100).toString().padLeft(2, '0');

    await login(tester, server);
    await tester.tap(find.text('Elektro Kay'));
    await tester.pumpAndSettle();
    await openTab(tester, 'Angebote');

    await tester.tap(find.textContaining('An-${year}001'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Umwandeln'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('In Auftrag umwandeln'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Auftrag (Entwurf)'), findsOneWidget);
    expect(find.text('Leistung'), findsOneWidget, reason: 'Positionen übernommen');
    // Breit: der Entwurf erscheint rechts neben der Liste (wie offline).
    await openTab(tester, 'Rechnungen');

    await tester.tap(find.textContaining('R-${year}001'));
    await tester.pumpAndSettle();
    expect(find.text('Offen (kein Fälligkeitsdatum gesetzt)'), findsOneWidget);
    await tester.tap(find.text('Als bezahlt markieren'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Bezahlt am'), findsOneWidget);
    expect(find.text('Als offen markieren'), findsOneWidget);
  });

  testWidgets('Passwort ändern und Abmelden über das Menü', (tester) async {
    final server = OnlineTestServer();
    await tester.runAsync(() => server.seedCompany(email: 'kay@example.com', companyName: 'Elektro Kay', permissions: _allPermissions));
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(navigatorKey: navigator, home: const Scaffold(body: Text('Startseite'))));
    navigator.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => OnlineLoginScreen(clientFactory: (_) => server.client(), offlineStoreFactory: () => null),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('online-server')), 'erp.example.org');
    await tester.enterText(find.byKey(const Key('online-email')), 'kay@example.com');
    await tester.enterText(find.byKey(const Key('online-password')), 'passwort-12345');
    await tester.tap(find.text('Anmelden'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elektro Kay'));
    await tester.pumpAndSettle();
    await openTab(tester, 'Rechnungen');

    await tester.tap(find.byTooltip('Weitere Aktionen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Passwort ändern'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('online-password-current')), 'passwort-12345');
    await tester.enterText(find.byKey(const Key('online-password-new')), 'neues-passwort-1');
    await tester.enterText(find.byKey(const Key('online-password-repeat')), 'anders-passwort');
    await tester.tap(find.text('Ändern'));
    await tester.pumpAndSettle();
    expect(find.text('Die Wiederholung stimmt nicht überein.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('online-password-repeat')), 'neues-passwort-1');
    await tester.tap(find.text('Ändern'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Passwort geändert'), findsOneWidget);
    final relogin = await tester.runAsync(() => server.client().login('kay@example.com', 'neues-passwort-1'));
    expect(relogin!.memberships, hasLength(1));

    await tester.tap(find.byTooltip('Weitere Aktionen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abmelden'));
    await tester.pumpAndSettle();
    expect(find.text('Startseite'), findsOneWidget);
  });
}
