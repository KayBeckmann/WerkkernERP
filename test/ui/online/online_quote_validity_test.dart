import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:werkkernerp/ui/screens/online/online_login_screen.dart';
import 'package:werkkernerp/ui/widgets/quote_validity_dialog.dart' show formatValidityDate;

import 'online_test_server.dart';

/// A5-Nachtrag (Kay, 16.11.2026) online: Bindefrist im Entwurf,
/// „bindend bis“ nach Finalisierung, Rückfrage beim Ändern.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Angebot online: Bindefrist vorbelegt, finalisiert „bindend bis“, Nein/Ja', (tester) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final server = OnlineTestServer();
    late String token;
    late String quoteId;
    await tester.runAsync(() async {
      token = await server.seedCompany(
        email: 'kay@example.com',
        companyName: 'Elektro Kay',
        permissions: ['customers.read', 'customers.write', 'invoices.read', 'invoices.write', 'invoices.finalize'],
      );
      await server.put('/company/modules', {'modules': ['quotes']}, token);
      final customer = await server.post('/customers', {'name': 'REMONDIS'}, token);
      final quote = await server.post('/documents', {
        'kind': 'quote',
        'customerId': customer['id'],
        'items': [
          {'kind': 'text', 'description': 'Außenbeleuchtung', 'quantity': '1', 'unitPriceCents': 10000, 'vatRatePercent': 19},
        ],
      }, token);
      quoteId = quote['id'] as String;
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

    await openTab(tester, 'Angebote');
    await tester.tap(find.textContaining('REMONDIS').first);
    await tester.pumpAndSettle();

    final field = find.byKey(const Key('online-quote-validity-days'));
    expect(tester.widget<TextField>(field).controller!.text, '14');
    await tester.enterText(field, '21');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Entwurf speichern'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Finalisieren'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finalisieren').last);
    await tester.pumpAndSettle();

    final now = DateTime.now().toUtc();
    final until = DateTime(now.year, now.month, now.day + 21);
    expect(find.textContaining('Bindend bis ${formatValidityDate(until)}'), findsOneWidget);

    // Änderung: „Nein“ behält die Frist.
    await tester.enterText(find.widgetWithText(TextField, 'Notizen'), 'Arbeitsbühne stellt der Auftraggeber');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Änderungen speichern'));
    await tester.pumpAndSettle();
    expect(find.text('Bindefrist anpassen?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('quote-validity-keep')));
    await tester.pumpAndSettle();
    var stored = await tester.runAsync(() => server.get('/documents/$quoteId', token));
    String day(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    expect((stored!['quoteValidUntil'], stored['notes']), (day(until), 'Arbeitsbühne stellt der Auftraggeber'));

    // „Ja“ mit bestätigtem Datum.
    await tester.enterText(find.widgetWithText(TextField, 'Notizen'), 'Zweite Änderung');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Änderungen speichern'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quote-validity-change')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Neue Bindefrist bestätigen'), findsOneWidget);
    await tester.tap(find.byKey(const Key('quote-validity-confirm')));
    await tester.pumpAndSettle();
    stored = await tester.runAsync(() => server.get('/documents/$quoteId', token));
    expect((stored!['quoteValidUntil'], stored['quoteValidityDays'], stored['notes']), (day(until), 21, 'Zweite Änderung'));
  });
}
