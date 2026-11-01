import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:werkkernerp/ui/screens/online/online_login_screen.dart';

import 'online_test_server.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Bestellvorschlag übernehmen, finalisieren, Teillieferung buchen', (tester) async {
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
        permissions: ['articles.read', 'articles.write', 'stock.read', 'purchaseOrders.read', 'purchaseOrders.write'],
      );
      await server.put('/company/modules', {'modules': ['bestellwesen', 'lagerbestand']}, token);
      final supplier = await server.post('/suppliers', {'name': 'Großhandel Nord'}, token);
      final article = await server.post('/articles', {'name': 'Kabel', 'minimumStock': '50', 'defaultSupplierId': supplier['id']}, token);
      articleId = article['id'] as String;
      await server.put('/articles/$articleId/prices/${supplier['id']}', {'purchasePriceCents': 120}, token);
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
    await openTab(tester, 'Bestellungen');

    // Wie offline: „Mindestbestand“ unten, Entwurf je Lieferant anlegen.
    await tester.tap(find.text('Mindestbestand'));
    await tester.pumpAndSettle();
    expect(find.text('Kabel: 50'), findsOneWidget);
    await tester.tap(find.text('Entwurf anlegen'));
    await tester.pumpAndSettle();
    expect(find.text('Entwurf'), findsOneWidget);
    expect(find.text('Summe netto: 60,00 €'), findsOneWidget);

    await tester.tap(find.text('Finalisieren'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finalisieren').last);
    await tester.pumpAndSettle();
    final yy = (DateTime.now().toUtc().year % 100).toString().padLeft(2, '0');
    expect(find.text('B-${yy}001'), findsOneWidget);

    await tester.tap(find.text('Wareneingang erfassen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)).first, '20');
    await tester.tap(find.text('Buchen'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Teilweise erhalten'), findsOneWidget);
    expect(find.textContaining('erhalten: 20'), findsOneWidget);

    final stock = await tester.runAsync(() async {
      final client = server.client()..token = token;
      return (await client.request('GET', '/articles/$articleId') as Map)['stockQuantity'];
    });
    expect(stock, '20');
  });
}
