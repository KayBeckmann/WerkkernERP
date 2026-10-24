import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:werkkernerp/ui/screens/online/online_login_screen.dart';

import 'online_test_server.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('§ 19 und Rechnungstexte in der Verwaltung; neue Position fest 0 %, Schnappschuss beim Finalisieren',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final server = OnlineTestServer();
    late String token;
    await tester.runAsync(() async {
      token = await server.seedCompany(
        email: 'kay@example.com',
        companyName: 'Elektro Kay',
        permissions: ['customers.read', 'customers.write', 'invoices.read', 'invoices.write', 'invoices.finalize'],
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

    await tester.tap(find.byTooltip('Verwaltung'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Firmendaten'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('online-profile-small-business')));
    await tester.tap(find.text('Rechnung'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('online-profile-intro-invoice')), 'Vielen Dank für Ihren Auftrag.');
    await tester.tap(find.text('Firmendaten speichern'));
    await tester.pumpAndSettle();
    expect(find.text('Firmendaten gespeichert.'), findsOneWidget);
    await tester.pageBack();
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
    expect(find.textContaining('§ 19 UStG'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('online-item-description')), 'Montage');
    await tester.enterText(find.byKey(const Key('online-item-price')), '100');
    await tester.tap(find.text('Übernehmen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(find.text('Gespeichert.'), findsOneWidget, reason: 'Server akzeptiert die 0-%-Position');
    await tester.tap(find.text('Finalisieren'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finalisieren').last);
    await tester.pumpAndSettle();

    final docs = await tester.runAsync(() async {
      final client = server.client()..token = token;
      return client.documents(status: 'finalized');
    });
    final finalized = await tester.runAsync(() async {
      final client = server.client()..token = token;
      return client.document(docs!.single.id);
    });
    expect(finalized!.smallBusinessExemptSnapshot, isTrue);
    expect(finalized.introTextSnapshot, 'Vielen Dank für Ihren Auftrag.');
    expect(finalized.taxCents, 0);
  });
}
