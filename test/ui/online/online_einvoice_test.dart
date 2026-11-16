import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:werkkernerp/ui/screens/online/online_login_screen.dart';

import 'online_test_server.dart';

/// C15.4 E-Rechnung online: Warnung vor dem Finalisieren bei fehlenden
/// Angaben, Prüfung nach dem Finalisieren, Versand mit XRechnung-XML.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Warnung vor dem Finalisieren, Prüfung grün, Mail mit PDF und XRechnung-XML', (tester) async {
    tester.view.physicalSize = const Size(1400, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final server = OnlineTestServer();
    late String token;
    late String customerId;
    await tester.runAsync(() async {
      token = await server.seedCompany(
        email: 'kay@example.com',
        companyName: 'Elektro Kay',
        permissions: ['customers.read', 'customers.write', 'invoices.read', 'invoices.write', 'invoices.finalize'],
      );
      await server.put('/company/modules', {'modules': ['eInvoice', 'smtp']}, token);
      await server.put('/mail/settings', {'host': 'smtp.example.org', 'fromAddress': 'rechnung@elektro.example'}, token);
      await server.put('/company/profile', {
        'address': 'Musterstraße 1, 23966 Wismar',
        'taxNumber': '079/123/45678',
        'iban': 'DE02120300000000202051',
        'email': 'info@elektro.example',
        'phone': '03841 1',
      }, token);
      // Leitweg-ID fehlt zunächst — XRechnung meldet das vor dem Finalisieren.
      customerId = (await server.post('/customers', {
        'name': 'Stadt Wismar',
        'address': 'Am Markt 1, 23966 Wismar',
        'email': 'rechnung@wismar.example',
        'eInvoiceFormat': 'xrechnung',
      }, token))['id'] as String;
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
    await openTab(tester, 'Rechnungen');
    await createDocument(tester, 'Neue Rechnung', 'Stadt Wismar');
    await tester.tap(find.text('Position hinzufügen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('online-item-description')), 'Montage');
    await tester.enterText(find.byKey(const Key('online-item-price')), '100');
    await tester.tap(find.text('Hinzufügen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Zahlungsbedingungen'), '14 Tage netto');
    await tester.tap(find.byTooltip('Entwurf speichern'));
    await tester.pumpAndSettle();

    // Finalisieren → bestätigen → E-Rechnungswarnung → abbrechen.
    await tester.tap(find.byTooltip('Finalisieren'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finalisieren').last);
    await tester.pumpAndSettle();
    expect(find.text('E-Rechnung unvollständig'), findsOneWidget);
    expect(find.textContaining('Leitweg-ID'), findsOneWidget);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Finalisieren'), findsOneWidget, reason: 'noch Entwurf');

    // Leitweg-ID nachtragen, dann ohne Warnung finalisieren.
    await tester.runAsync(() => server.put('/customers/$customerId', {
          'name': 'Stadt Wismar',
          'address': 'Am Markt 1, 23966 Wismar',
          'email': 'rechnung@wismar.example',
          'leitwegId': '04011000-1234512345-06',
        }, token));
    await tester.tap(find.byTooltip('Finalisieren'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finalisieren').last);
    await tester.pumpAndSettle();
    expect(find.text('E-Rechnung unvollständig'), findsNothing);
    expect(find.text('Finalisiert.'), findsOneWidget);

    await tester.tap(find.byTooltip('E-Rechnung'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('E-Rechnung prüfen'));
    await tester.pumpAndSettle();
    expect(find.text('Format: XRechnung (XML)'), findsOneWidget);
    expect(find.textContaining('Alle Pflichtangaben vorhanden'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Per E-Mail senden'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Senden'));
    await tester.pumpAndSettle();
    final mail = server.mailTransport.sent.single.mail;
    expect(mail.to, 'rechnung@wismar.example');
    expect([for (final a in mail.attachments) a.contentType], ['application/pdf', 'application/xml']);
    expect(String.fromCharCodes(mail.attachments.last.bytes), contains('urn:xeinkauf.de:kosit:xrechnung_3.0'));
  });
}
