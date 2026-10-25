import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:werkkern_client/werkkern_client.dart';
import 'package:werkkernerp/ui/screens/online/online_login_screen.dart';

import 'online_test_server.dart';

/// B2 in der App: Dokument offline verfügbar machen, im Funkloch
/// bearbeiten, nach Rückkehr abgleichen; ohne Verbindung starten.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Markieren → Funkloch → offline bearbeiten → Abgleich; Start ohne Verbindung', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final server = OnlineTestServer();
    final vault = InMemoryOfflineVault();
    late String token;
    late String docId;
    await tester.runAsync(() async {
      token = await server.seedCompany(
        email: 'kay@example.com',
        companyName: 'Elektro Kay',
        permissions: ['customers.read', 'customers.write', 'invoices.read', 'invoices.write', 'invoices.finalize'],
      );
      final customer = await server.post('/customers', {'name': 'Baustelle Meyer'}, token);
      docId = (await server.post('/documents', {
        'customerId': customer['id'],
        'items': [
          {'kind': 'hours', 'description': 'Montage', 'quantity': '1', 'unitPriceCents': 6000, 'vatRatePercent': 19},
        ],
      }, token))['id'] as String;
    });

    Widget loginScreen() => MaterialApp(
          key: UniqueKey(),
          home: OnlineLoginScreen(clientFactory: (_) => server.client(), offlineStoreFactory: () => OfflineStore(vault)),
        );

    await tester.pumpWidget(loginScreen());
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('online-server')), 'erp.example.org');
    await tester.enterText(find.byKey(const Key('online-email')), 'kay@example.com');
    await tester.enterText(find.byKey(const Key('online-password')), 'passwort-12345');
    await tester.tap(find.text('Anmelden'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elektro Kay'));
    await tester.pumpAndSettle();
    await openTab(tester, 'Dokumente');
    expect(find.textContaining('nur ausdrücklich offline markierte'), findsOneWidget);

    // Dokument offline verfügbar machen.
    await tester.tap(find.text('Rechnung (Entwurf)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Offline verfügbar machen'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Nicht mehr offline verfügbar'), findsOneWidget);

    // Funkloch: Änderung landet in der Outbox.
    server.offline = true;
    await tester.tap(find.text('Position hinzufügen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('online-item-description')), 'Material vor Ort');
    await tester.enterText(find.byKey(const Key('online-item-price')), '25');
    await tester.tap(find.text('Übernehmen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(find.text('Offline-Änderung, noch nicht übertragen'), findsOneWidget);
    expect(find.text('Offline-Kopie'), findsOneWidget);
    expect(find.text('Material vor Ort'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Finalisieren')).onPressed, isNull,
        reason: 'Finalisieren braucht den Server');
    // Liste im Funkloch: nur markierte Dokumente.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byTooltip('1 Offline-Änderung(en) abgleichen'), findsOneWidget);

    // Zurück online: abgleichen.
    server.offline = false;
    await tester.tap(find.byTooltip('1 Offline-Änderung(en) abgleichen'));
    await tester.pumpAndSettle();
    // Vorige Meldung ("Offline gespeichert") läuft noch aus.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 Offline-Änderung(en) übertragen'), findsOneWidget);
    final synced = await tester.runAsync(() async {
      final client = server.client()..token = token;
      return client.document(docId);
    });
    expect(synced!.items.map((i) => i.description), ['Montage', 'Material vor Ort']);

    // Neustart ohne Verbindung: Bestand direkt aus dem Login öffnen.
    server.offline = true;
    await tester.pumpWidget(loginScreen());
    await tester.pumpAndSettle();
    expect(find.text('Offline-Bestand: Elektro Kay'), findsOneWidget);
    await tester.tap(find.text('Ohne Verbindung öffnen'));
    await tester.pumpAndSettle();
    expect(find.text('Elektro Kay · offline'), findsOneWidget);
    expect(find.textContaining('Baustelle Meyer'), findsOneWidget);
  });
}
