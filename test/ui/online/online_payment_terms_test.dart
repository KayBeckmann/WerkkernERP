import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:werkkernerp/ui/screens/online/online_login_screen.dart';

import 'online_test_server.dart';

/// A2-Nachtrag online: Vorbelegung, Wechsel und Skonto im Beleg-Editor.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Online: 14 Tage vorbelegt, Wechsel auf 30 Tage mit Skonto, gespeichert', (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final server = OnlineTestServer();
    late String token;
    await tester.runAsync(() async {
      token = await server.seedCompany(
        email: 'kay@example.com',
        companyName: 'Nord-Impuls',
        permissions: ['customers.read', 'customers.write', 'invoices.read', 'invoices.write'],
      );
      await server.post('/customers', {'name': 'Baustelle Meyer'}, token);
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
    await openTab(tester, 'Rechnungen');
    await createDocument(tester, 'Neue Rechnung', 'Baustelle Meyer');
    expect(find.widgetWithText(DropdownButtonFormField<String?>, '14 Tage'), findsOneWidget);

    await tester.tap(find.text('Position hinzufügen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('online-item-description')), 'Montage');
    await tester.enterText(find.byKey(const Key('online-item-price')), '100');
    await tester.tap(find.text('Hinzufügen'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('online-document-payment-term')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('30 Tage').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('online-document-skonto')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('online-document-skonto-percent')), '2');
    await tester.enterText(find.byKey(const Key('online-document-skonto-days')), '7');
    await tester.pumpAndSettle();
    expect(find.textContaining('2 % Skonto auf den Nettobetrag (2,00 €), zu zahlen 117,00 €'), findsOneWidget);
    await tester.tap(find.byTooltip('Entwurf speichern'));
    await tester.pumpAndSettle();
    final doc = await tester.runAsync(() async {
      final client = server.client()..token = token;
      return client.document((await client.documents()).single.id);
    });
    expect((doc!.paymentTerm!.label, doc.paymentTerm!.netDays, doc.paymentTerm!.skontoPercent, doc.paymentTerm!.skontoDays),
        ('30 Tage', 30, 2.0, 7));
    expect(doc.dueDate, isNotNull);
  });
}
