import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:werkkernerp/ui/screens/online/online_login_screen.dart';
import 'package:werkkernerp/ui/widgets/barcode_scanner.dart';

import 'online_test_server.dart';

/// C5.5-Nachtrag (Kay, 16.11.2026) online: Scan im Auftrag mit Menge und
/// Positionsgruppe, gleiche Gruppe addieren, unbekannter Code ohne Position.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Online-Scan im Auftrag', (tester) async {
    tester.view.physicalSize = const Size(1400, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final codes = <String>[];
    barcodeScanner = (_) async => codes.removeAt(0);
    addTearDown(() => barcodeScanner = (_) async => null);
    final server = OnlineTestServer();
    late String token;
    await tester.runAsync(() async {
      token = await server.seedCompany(
        email: 'kay@example.com',
        companyName: 'Nord-Impuls',
        permissions: ['customers.read', 'customers.write', 'articles.read', 'articles.write', 'invoices.read', 'invoices.write'],
      );
      await server.put('/company/modules', {'modules': ['orders']}, token);
      await server.post('/customers', {'name': 'Baustelle Meyer'}, token);
      await server.post('/articles', {'name': 'NYM-J 3x1,5', 'unit': 'm', 'barcode': '0401', 'salePriceCents': 120, 'active': true}, token);
    });
    await tester.pumpWidget(MaterialApp(
      home: OnlineLoginScreen(clientFactory: (_) => server.client(), offlineStoreFactory: () => null),
    ));
    await tester.enterText(find.byKey(const Key('online-server')), 'erp.example.org');
    await tester.enterText(find.byKey(const Key('online-email')), 'kay@example.com');
    await tester.enterText(find.byKey(const Key('online-password')), 'passwort-12345');
    await tester.tap(find.text('Anmelden'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nord-Impuls'));
    await tester.pumpAndSettle();
    await openTab(tester, 'Aufträge');
    await createDocument(tester, 'Neuer Auftrag', 'Baustelle Meyer');

    Future<void> scan(String code, {String? quantity, String? group, String button = 'Hinzufügen'}) async {
      codes.add(code);
      await tester.tap(find.byTooltip('Barcode scannen'));
      await tester.pumpAndSettle();
      if (quantity == null) return;
      await tester.enterText(find.byKey(const Key('scan-quantity')), quantity);
      if (group != null) await tester.enterText(find.byKey(const Key('scan-group')), group);
      await tester.pumpAndSettle();
      await tester.tap(find.text(button));
      await tester.pumpAndSettle();
    }

    await scan('0401', quantity: '25', group: 'Küche');
    expect(find.textContaining('25 m × 1,20 €'), findsOneWidget);
    await scan('0401', quantity: '5', group: 'Küche', button: 'Zur Position addieren');
    expect(find.textContaining('30 m × 1,20 €'), findsOneWidget);
    await scan('0401', quantity: '10', group: 'Bad');
    expect(find.textContaining('10 m × 1,20 €'), findsOneWidget);
    await scan('9999');
    expect(find.textContaining('Kein Artikel mit Barcode 9999'), findsOneWidget);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Entwurf speichern'));
    await tester.pumpAndSettle();
    final docs = await tester.runAsync(() async {
      final client = server.client()..token = token;
      return client.document((await client.documents()).single.id);
    });
    expect([for (final i in docs!.items) (i.quantity, i.groupLabel)], unorderedEquals([('30', 'Küche'), ('10', 'Bad')]));
  });
}
