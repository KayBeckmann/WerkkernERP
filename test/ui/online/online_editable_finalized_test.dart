import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:werkkernerp/ui/screens/online/online_login_screen.dart';

import 'online_test_server.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Finalisierter Auftrag bleibt bis zur Umwandlung bearbeitbar, danach gesperrt', (tester) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final server = OnlineTestServer();
    late String token;
    late String orderId;
    await tester.runAsync(() async {
      token = await server.seedCompany(
        email: 'kay@example.com',
        companyName: 'Elektro Kay',
        permissions: ['customers.read', 'customers.write', 'invoices.read', 'invoices.write', 'invoices.finalize'],
      );
      await server.put('/company/modules', {'modules': ['orders']}, token);
      final customer = await server.post('/customers', {'name': 'Meyer'}, token);
      final order = await server.post('/documents', {
        'kind': 'order',
        'customerId': customer['id'],
        'items': [
          {'kind': 'text', 'description': 'Elektroinstallation', 'quantity': '1', 'unitPriceCents': 100000, 'vatRatePercent': 19},
        ],
      }, token);
      orderId = order['id'] as String;
      await server.post('/documents/$orderId/finalize', {'version': 1}, token);
    });
    final yy = (DateTime.now().toUtc().year % 100).toString().padLeft(2, '0');

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

    await tester.tap(find.text('A-${yy}001'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Auftrag · finalisiert'), findsOneWidget);
    expect(find.text('Position hinzufügen'), findsOneWidget, reason: 'noch nicht umgewandelt');
    expect(find.text('Finalisieren'), findsNothing);
    expect(find.byTooltip('Entwurf löschen'), findsNothing);

    await tester.enterText(find.widgetWithText(TextField, 'Notizen'), 'Nachtrag Steckdosen');
    await tester.pump();
    expect(find.text('In Rechnung umwandeln'), findsNothing, reason: 'erst speichern, dann umwandeln');
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(find.text('Gespeichert.'), findsOneWidget);
    expect(find.textContaining('A-${yy}001'), findsWidgets, reason: 'Nummer bleibt');

    await tester.tap(find.text('In Rechnung umwandeln'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Rechnung · Entwurf'), findsOneWidget);
    // Die Umwandlung ersetzt den Auftrag im Navigationsstapel.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('A-${yy}001'));
    await tester.pumpAndSettle();
    expect(find.text('Position hinzufügen'), findsNothing, reason: 'nach der Umwandlung gesperrt');
    expect(find.text('Speichern'), findsNothing);

    final saved = await tester.runAsync(() async {
      final client = server.client()..token = token;
      return client.document(orderId);
    });
    expect(saved!.notes, 'Nachtrag Steckdosen');
    expect(saved.editable, isFalse);
  });
}
