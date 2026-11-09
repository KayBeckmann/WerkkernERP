import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:werkkernerp/ui/screens/online/online_login_screen.dart';
import 'package:werkkernerp/ui/widgets/customer_contacts.dart';

import 'online_test_server.dart';

/// Kay 2026-11-09 online: Kontaktpersonen in Kundenansicht und Formular,
/// Anrufen, Kontaktperson am Angebot, Empfänger-Hinweis beim Versand.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Kontaktpersonen ansehen, anrufen, ergänzen und einem Angebot zuweisen', (tester) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final calls = <Uri>[];
    phoneLauncher = (uri) async {
      calls.add(uri);
      return true;
    };
    addTearDown(() => phoneLauncher = (uri) async => false);

    final server = OnlineTestServer();
    late String token;
    late String customerId;
      await tester.runAsync(() async {
      token = await server.seedCompany(
        email: 'kay@example.com',
        companyName: 'Elektro Kay',
        permissions: ['invoices.read', 'invoices.write', 'invoices.finalize', 'customers.read', 'customers.write'],
      );
      await server.put('/company/modules', {'modules': ['smtp', 'quotes']}, token);
      await server.put('/mail/settings', {'host': 'smtp.example.org', 'fromAddress': 'rechnung@elektro.example'}, token);
      final customer = await server.post('/customers', {
        'name': 'Remondis',
        'email': 'info@remondis.example',
        'invoiceEmail': 'rechnung@remondis.example',
        'contacts': [
          {'name': 'Vincent', 'role': 'Betriebstechniker', 'phone': '0171 111'},
          {'name': 'Annika', 'role': 'Buchhaltung', 'email': 'annika@remondis.example'},
        ],
      }, token);
      customerId = customer['id'] as String;
      await server.post('/documents', {
        'kind': 'quote',
        'customerId': customerId,
        'items': [
          {'kind': 'text', 'description': 'Wartung', 'quantity': '1', 'unitPriceCents': 10000, 'vatRatePercent': 19},
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

    // Kundenansicht: Kontaktpersonen, Anruf.
    await openTab(tester, 'Kunden');
    await tester.tap(find.text('Remondis'));
    await tester.pumpAndSettle();
    expect(find.text('Annika (Buchhaltung)'), findsOneWidget);
    await tester.tap(find.byTooltip('Vincent anrufen'));
    await tester.pumpAndSettle();
    expect(calls.single.toString(), 'tel:0171111');

    // Kontaktperson ergänzen.
    await tester.tap(find.byTooltip('Bearbeiten'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Kontaktperson hinzufügen'));
    await tester.tap(find.text('Kontaktperson hinzufügen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Name der Kontaktperson *'), 'Jonas');
    await tester.enterText(find.widgetWithText(TextField, 'Funktion'), 'Lager');
    await tester.tap(find.text('Übernehmen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    // Anzeige kommt aus der Serverantwort — also gespeichert.
    expect(find.text('Jonas (Lager)'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Angebot: Kontaktperson Annika zuweisen und speichern.
    await openTab(tester, 'Angebote');
    await tester.tap(find.textContaining('Remondis').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('online-document-contact-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annika (Buchhaltung)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Entwurf speichern'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Finalisieren'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Finalisieren'));
    await tester.pumpAndSettle();

    // Versandhinweis aus dem Serverstand nennt die Kontaktperson (Angebot
    // ohne Rechnungs-E-Mail).
    await tester.tap(find.byTooltip('Per E-Mail senden'));
    await tester.pumpAndSettle();
    expect(find.text('Leer = annika@remondis.example (Kontaktperson Annika)'), findsOneWidget);
  });
}
