import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:werkkernerp/ui/screens/online/online_login_screen.dart';

import 'online_test_server.dart';

/// Projekte, Zeiterfassung und Buchhaltung online wie offline: Projekt mit
/// Kunde und Notizen, Rollen & Stundensätze in den Einstellungen und beim
/// Buchen, „Bezahlt“ in den offenen Posten, Projekt am Beleg.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Projekt mit Kunde/Notizen, Rolle beim Buchen, Bezahlt in offenen Posten, Projekt am Beleg', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final server = OnlineTestServer();
    late String token;
    await tester.runAsync(() async {
      token = await server.seedCompany(
        email: 'kay@example.com',
        companyName: 'Elektro Kay',
        permissions: [
          'customers.read', 'customers.write', 'invoices.read', 'invoices.write', 'invoices.finalize',
          'invoices.payment', 'projects.read', 'projects.write', 'timeTracking.read', 'timeTracking.write',
          'accounting.read', 'accounting.write',
        ],
      );
      await server.put('/company/modules', {'modules': ['projects', 'timeTracking', 'buchhaltung', 'orders']}, token);
      final customer = await server.post('/customers', {'name': 'Meyer'}, token);
      final draft = await server.post('/documents', {
        'kind': 'invoice',
        'customerId': customer['id'],
        'items': [
          {'kind': 'text', 'description': 'Leistung', 'quantity': '1', 'unitPriceCents': 10000, 'vatRatePercent': 19},
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
    final yy = (DateTime.now().toUtc().year % 100).toString().padLeft(2, '0');

    // Projekt wie offline mit Kunde und Notizen.
    await openTab(tester, 'Projekte');
    await tester.tap(find.text('Projekt anlegen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('online-project-name')), 'Neubau');
    await tester.tap(find.byKey(const Key('online-project-customer')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Meyer').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('online-project-notes')), 'Schlüssel beim Nachbarn');
    await tester.tap(find.text('Anlegen'));
    await tester.pumpAndSettle();
    expect(find.text('$yy/01 · Neubau'), findsOneWidget);
    expect(find.text('Meyer'), findsOneWidget, reason: 'Kunde als Untertitel');
    await tester.tap(find.text('$yy/01 · Neubau'));
    await tester.pumpAndSettle();
    expect(find.text('Schlüssel beim Nachbarn'), findsOneWidget);
    expect(find.textContaining('Zugeordnete Belege: '), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Rolle mit Stundensatz in den Einstellungen (Vorschläge kommen mit).
    await openTab(tester, 'Einstellungen');
    await tester.tap(find.text('Rollen & Stundensätze'));
    await tester.pumpAndSettle();
    expect(find.text('Monteur'), findsOneWidget, reason: 'Vorschläge wie offline');
    await tester.tap(find.text('Rolle anlegen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('online-role-name')), 'Elektromeister');
    await tester.enterText(find.byKey(const Key('online-role-rate')), '65');
    await tester.tap(find.text('Anlegen'));
    await tester.pumpAndSettle();
    expect(find.text('Verrechnung: nicht hinterlegt · Kosten: 65,00 € / Std.'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Zeit aufs Projekt mit Rolle.
    await openTab(tester, 'Zeiterfassung');
    await tester.tap(find.text('Zeit buchen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Projekt').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('online-time-project')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('$yy/01 · Neubau').last);
    await tester.pumpAndSettle();
    // C3.4: Es gibt Rollen → ohne Rolle wird nicht gebucht.
    await tester.tap(find.text('Buchen'));
    await tester.pumpAndSettle();
    expect(find.text('Bitte eine Rolle wählen — sie bestimmt den Stundensatz beim Abrechnen.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('online-time-role')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elektromeister').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('online-time-hours')), '2');
    await tester.tap(find.text('Buchen'));
    await tester.pumpAndSettle();
    expect(find.text('2 Std. · $yy/01 · Neubau'), findsOneWidget, reason: 'Projekt als Bezug wie offline');
    expect(find.textContaining('Elektromeister'), findsOneWidget);
    final entries = await tester.runAsync(() async => (await (server.client()..token = token).timeEntries()).entries);
    expect(entries!.single.hourlyCostCents, 6500, reason: 'Satz der Rolle eingefroren');

    // Offene Posten: „Bezahlt“ direkt an der Rechnung.
    await openTab(tester, 'Offene Posten');
    await tester.tap(find.text('Meyer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bezahlt'));
    await tester.pumpAndSettle();
    expect(find.text('Keine offenen Posten.'), findsOneWidget);

    // Beleg mit Projekt: Projektname in der Liste.
    await openTab(tester, 'Belege');
    await tester.tap(find.text('Beleg erfassen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('online-form-description')), 'Kabel');
    await tester.enterText(find.byKey(const Key('online-form-amount')), '50');
    await tester.tap(find.byKey(const Key('online-form-projectId')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Neubau').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(find.textContaining('— Neubau'), findsOneWidget);
  });
}
