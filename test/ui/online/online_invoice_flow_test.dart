import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:werkkernerp/ui/screens/online/online_login_screen.dart';

import 'online_test_server.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Abschlagsrechnung, Schlussrechnung mit Abzug und Restbetrag, Gutschrift', (tester) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final server = OnlineTestServer();
    await tester.runAsync(() async {
      final token = await server.seedCompany(
        email: 'kay@example.com',
        companyName: 'Elektro Kay',
        permissions: ['customers.read', 'customers.write', 'invoices.read', 'invoices.write', 'invoices.finalize'],
      );
      await server.put('/company/modules', {'modules': ['orders', 'advancePaymentInvoices', 'creditNotes']}, token);
      final customer = await server.post('/customers', {'name': 'Meyer'}, token);
      final order = await server.post('/documents', {
        'kind': 'order',
        'customerId': customer['id'],
        'items': [
          {'kind': 'text', 'description': 'Elektroinstallation', 'quantity': '1', 'unitPriceCents': 100000, 'vatRatePercent': 19},
        ],
      }, token);
      await server.post('/documents/${order['id']}/finalize', {'version': 1}, token);
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
    await openTab(tester, 'Aufträge');

    // Breit wie offline: Auftrag links wählen, Folgedokument erscheint rechts.
    Future<void> openOrderAndConvert() async {
      await tester.tap(find.textContaining('A-${yy}001').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Umwandeln'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('In Rechnung umwandeln'));
      await tester.pumpAndSettle();
    }

    Future<void> finalize() async {
      await tester.tap(find.byTooltip('Finalisieren'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finalisieren').last);
      await tester.pumpAndSettle();
    }

    // Abschlag: Rechnung aus dem Auftrag, als Abschlag kennzeichnen, finalisieren.
    await openOrderAndConvert();
    await tester.tap(find.text('Ist eine Abschlagsrechnung'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Entwurf speichern'));
    await tester.pumpAndSettle();
    await finalize();
    expect(find.textContaining('Rechnung R-${yy}001'), findsOneWidget);
    expect(find.text('Abschlagsrechnung'), findsOneWidget);

    // Schlussrechnung zieht den Abschlag einzeln ab.
    await openOrderAndConvert();
    await finalize();
    expect(find.textContaining('Rechnung R-${yy}002'), findsOneWidget);
    expect(find.textContaining('Abschlagsrechnung R-${yy}001: −'), findsOneWidget);
    expect(find.text('Restbetrag: 0,00 €'), findsOneWidget, reason: '1.190 € − 1.190 € Abschlag');

    // Gutschrift zur Schlussrechnung.
    await tester.tap(find.byTooltip('Gutschrift erstellen'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Gutschrift (Entwurf)'), findsOneWidget);
    expect(find.text('Gutschrift zu R-${yy}002'), findsOneWidget);
  });
}
