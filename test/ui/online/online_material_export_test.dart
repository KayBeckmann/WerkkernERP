import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:werkkernerp/ui/screens/online/online_login_screen.dart';

import 'online_test_server.dart';

/// Materialabschlag aus einem Auftrag (wie offline) und „Daten &
/// Sicherung“ mit Firmen-Datenexport.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Materialabschlag: Artikel + gewählter Freitext als Abschlagsrechnung; Exportseite', (tester) async {
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
      await server.put('/company/modules', {'modules': ['orders', 'advancePaymentInvoices']}, token);
      final customer = await server.post('/customers', {'name': 'Meyer'}, token);
      final order = await server.post('/documents', {
        'kind': 'order',
        'customerId': customer['id'],
        'items': [
          {'kind': 'article', 'description': 'Kabel', 'quantity': '1', 'unitPriceCents': 10000, 'vatRatePercent': 19},
          {'kind': 'hours', 'description': 'Montage', 'quantity': '2', 'unitPriceCents': 6500, 'vatRatePercent': 19},
          {'kind': 'text', 'description': 'Kleinmaterial', 'quantity': '1', 'unitPriceCents': 2000, 'vatRatePercent': 19},
          {'kind': 'text', 'description': 'Anfahrt', 'quantity': '1', 'unitPriceCents': 3000, 'vatRatePercent': 19},
        ],
      }, token);
      await server.post('/documents/${order['id']}/finalize', {'version': order['version']}, token);
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

    await openTab(tester, 'Aufträge');
    await tester.tap(find.text('Meyer'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Materialabschlag erstellen'));
    await tester.pumpAndSettle();
    expect(find.text('Alle Artikel-Positionen'), findsOneWidget);
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Kleinmaterial'));
    await tester.tap(find.text('Erstellen'));
    await tester.pumpAndSettle();

    // Breit: der Entwurf erscheint rechts — als Abschlagsrechnung mit
    // Kabel und Kleinmaterial, ohne Stunden und ohne nicht gewählte Texte.
    expect(find.text('Rechnung (Entwurf) — Meyer'), findsOneWidget);
    expect(tester.widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile, 'Ist eine Abschlagsrechnung')).value, isTrue);
    expect(find.text('Kabel'), findsOneWidget);
    expect(find.text('Kleinmaterial'), findsOneWidget);
    expect(find.text('Montage'), findsNothing);
    expect(find.text('Anfahrt'), findsNothing);

    // Daten & Sicherung: Export statt lokaler Sicherung.
    await openTab(tester, 'Einstellungen');
    await tester.tap(find.text('Daten & Sicherung'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('online-export-start')), findsOneWidget);
    expect(find.textContaining('vom Betreiber verschlüsselt gesichert'), findsOneWidget);
  });
}
