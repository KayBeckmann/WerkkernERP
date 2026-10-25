import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:werkkernerp/ui/screens/online/online_login_screen.dart';

import 'online_test_server.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('SMTP in der Verwaltung einrichten, finalisierte Rechnung per E-Mail an den Kunden senden', (tester) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final server = OnlineTestServer();
    await tester.runAsync(() async {
      final token = await server.seedCompany(
        email: 'kay@example.com',
        companyName: 'Elektro Kay',
        permissions: ['invoices.read', 'invoices.write', 'invoices.finalize', 'customers.read', 'customers.write'],
      );
      await server.put('/company/modules', {'modules': ['smtp']}, token);
      final customer = await server.post('/customers', {'name': 'Meyer', 'email': 'meyer@example.com'}, token);
      final draft = await server.post('/documents', {
        'kind': 'invoice',
        'customerId': customer['id'],
        'items': [
          {'kind': 'text', 'description': 'Installation', 'quantity': '1', 'unitPriceCents': 10000, 'vatRatePercent': 19},
        ],
      }, token);
      await server.post('/documents/${draft['id']}/finalize', {'version': draft['version']}, token);
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

    // Verwaltung → E-Mail
    await tester.tap(find.byTooltip('Verwaltung'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('E-Mail'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('online-mail-host')), 'smtp.example.org');
    await tester.enterText(find.byKey(const Key('online-mail-password')), 'geheim-123');
    await tester.enterText(find.byKey(const Key('online-mail-from')), 'rechnung@elektro.example');
    await tester.tap(find.text('E-Mail-Einstellungen speichern'));
    await tester.pumpAndSettle();
    expect(find.text('gespeichert — leer lassen, um es zu behalten'), findsOneWidget);
    tester.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger)).removeCurrentSnackBar();
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Dokument senden
    await tester.tap(find.textContaining('Meyer').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Per E-Mail senden'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Senden'));
      // PDF-Erzeugung läuft echt asynchron (Schriften, Layout).
      for (var i = 0; i < 50 && server.mailTransport.sent.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();
    expect(find.text('Versendet an meyer@example.com.'), findsOneWidget);
    final sent = server.mailTransport.sent.single;
    expect(sent.password, 'geheim-123');
    expect(sent.mail.subject, startsWith('Elektro Kay: R-'));
    expect(sent.mail.attachments.single.bytes.sublist(0, 5), '%PDF-'.codeUnits);
  });
}
