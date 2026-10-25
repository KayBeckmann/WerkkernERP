import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:werkkernerp/ui/screens/online/online_login_screen.dart';

import 'online_test_server.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Vorlage anlegen (fällig gestern), „Fällige jetzt erzeugen“ legt den Entwurf an', (tester) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final server = OnlineTestServer();
    late String token;
    await tester.runAsync(() async {
      token = await server.seedCompany(
        email: 'kay@example.com',
        companyName: 'Elektro Kay',
        permissions: ['invoices.read', 'invoices.write', 'customers.read', 'customers.write'],
      );
      await server.put('/company/modules', {'modules': ['recurringInvoices']}, token);
      await server.post('/customers', {'name': 'Hausverwaltung Meyer'}, token);
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
    await tester.tap(find.byIcon(Icons.autorenew).last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Vorlage anlegen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('recurring-label')), 'Wartungsvertrag');
    await tester.tap(find.byKey(const Key('recurring-customer')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hausverwaltung Meyer').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Position hinzufügen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('online-form-description')), 'Wartungspauschale');
    await tester.enterText(find.byKey(const Key('online-form-price')), '99');
    await tester.tap(find.text('Übernehmen'));
    await tester.pumpAndSettle();
    expect(find.text('117,81 €'), findsOneWidget);
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Wartungsvertrag · Hausverwaltung Meyer'), findsOneWidget);

    // Fälligkeit liegt auf heute → sofort erzeugbar.
    await tester.tap(find.text('Fällige jetzt erzeugen'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 fällige(r)'), findsOneWidget);

    final docs = await tester.runAsync(() async {
      final client = server.client()..token = token;
      return client.documents(kind: 'invoice');
    });
    expect(docs!.single.isDraft, isTrue);
  });
}
