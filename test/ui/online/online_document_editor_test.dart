import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:werkkernerp/ui/screens/online/online_login_screen.dart';

import 'online_test_server.dart';

/// Online-Dokumenteditor mit dem Funktionsumfang des Offline-Editors:
/// Kunde per Suche, Positionen bearbeiten, Rabatt, Gruppen mit
/// Gruppensumme, Zahlungsbedingungen, Projekt, Fälligkeit im Entwurf,
/// Mahnstufe in Liste und Editor.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const permissions = [
    'customers.read',
    'customers.write',
    'invoices.read',
    'invoices.write',
    'invoices.finalize',
    'invoices.payment',
    'dunning.read',
    'dunning.write',
    'projects.read',
    'projects.write',
  ];

  Future<void> login(WidgetTester tester, OnlineTestServer server) async {
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
  }

  testWidgets('Kundensuche, Position bearbeiten, Rabatt, Gruppen mit Summe, Zahlungsbedingungen, Projekt, Fälligkeit',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final server = OnlineTestServer();
    late String token;
    await tester.runAsync(() async {
      token = await server.seedCompany(email: 'kay@example.com', companyName: 'Elektro Kay', permissions: permissions);
      await server.put('/company/modules', {'modules': ['dunning', 'projects']}, token);
      await server.post('/customers', {'name': 'Meyer'}, token);
      await server.post('/customers', {'name': 'Schulze'}, token);
      await server.post('/projects', {'name': 'Neubau Meyer'}, token);
    });
    await login(tester, server);
    await openTab(tester, 'Rechnungen');

    // Kundensuche filtert wie offline.
    await tester.tap(find.text('Neue Rechnung'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('online-pick-customer-search')), 'schu');
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(AlertDialog), matching: find.text('Meyer')), findsNothing);
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Schulze')));
    await tester.pumpAndSettle();
    expect(find.text('Rechnung (Entwurf) — Schulze'), findsOneWidget);

    Future<void> addItem(String description, String price, {String? group, String? discount}) async {
      await tester.tap(find.text('Position hinzufügen'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('online-item-description')), description);
      await tester.enterText(find.byKey(const Key('online-item-price')), price);
      if (discount != null) await tester.enterText(find.byKey(const Key('online-item-discount')), discount);
      if (group != null) {
        await tester.enterText(find.byKey(const Key('online-item-group')), group);
        // Vorschlagsliste der Gruppen schließt sich, sobald nichts mehr passt.
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Hinzufügen'));
      await tester.pumpAndSettle();
    }

    await addItem('Steckdosen', '100', group: 'Bad');
    await addItem('Leuchte', '50', group: 'Küche', discount: '10');
    // 100 € netto + 19 % = 119,00 €; 50 € − 10 % = 45 € + 19 % = 53,55 €.
    expect(find.text('Gruppensumme: 119,00 €'), findsOneWidget);
    expect(find.text('Gruppensumme: 53,55 €'), findsOneWidget);
    expect(find.textContaining('10 % Rabatt'), findsOneWidget);
    expect(find.text('Gesamt: 172,55 €'), findsOneWidget);

    // Position antippen öffnet sie zum Bearbeiten (wie offline).
    await tester.tap(find.text('Steckdosen'));
    await tester.pumpAndSettle();
    expect(find.text('Position bearbeiten'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('online-item-price')), '200');
    await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
    await tester.pumpAndSettle();
    expect(find.text('Gruppensumme: 238,00 €'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Zahlungsbedingungen'), '14 Tage netto');
    await tester.tap(find.text('Ohne Projekt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Neubau Meyer').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fälligkeitsdatum (optional)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Fälligkeitsdatum: '), findsOneWidget);
    await tester.tap(find.byTooltip('Entwurf speichern'));
    await tester.pumpAndSettle();
    expect(find.text('Entwurf gespeichert.'), findsOneWidget);

    final saved = await tester.runAsync(() async {
      final client = server.client()..token = token;
      return client.document((await client.documents(kind: 'invoice')).single.id);
    });
    expect(saved!.paymentTerms, '14 Tage netto');
    expect(saved.dueDate, isNotNull, reason: 'Fälligkeit schon im Entwurf (wie offline)');
    expect(saved.projectId, isNotNull);
    expect(saved.items.map((i) => (i.description, i.groupLabel, i.discountPercent, i.unitPriceCents)), [
      ('Steckdosen', 'Bad', 0, 20000),
      ('Leuchte', 'Küche', 10, 5000),
    ]);
  });

  testWidgets('Überfällige Rechnung: Mahnstufe rot in der Liste, Mahnschreiben direkt aus der Rechnung', (tester) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final server = OnlineTestServer();
    final due = DateTime.now().toUtc().subtract(const Duration(days: 20));
    final dueText = '${due.year}-${due.month.toString().padLeft(2, '0')}-${due.day.toString().padLeft(2, '0')}';
    await tester.runAsync(() async {
      final token = await server.seedCompany(email: 'kay@example.com', companyName: 'Elektro Kay', permissions: permissions);
      await server.put('/company/modules', {'modules': ['dunning']}, token);
      final customer = await server.post('/customers', {'name': 'Meyer'}, token);
      final draft = await server.post('/documents', {
        'kind': 'invoice',
        'customerId': customer['id'],
        'items': [
          {'kind': 'text', 'description': 'Installation', 'quantity': '1', 'unitPriceCents': 10000, 'vatRatePercent': 19},
        ],
      }, token);
      final finalized = await server.post('/documents/${draft['id']}/finalize', {'version': draft['version']}, token);
      await server.put('/documents/${finalized['id']}/due-date', {'dueDate': dueText}, token);
    });
    await login(tester, server);
    await openTab(tester, 'Rechnungen');

    // 20 Tage überfällig, 2. Stufe erst ab 14 Tagen → „2. Mahnstufe“.
    expect(find.textContaining('Überfällig (2. Mahnstufe)'), findsOneWidget);
    await tester.tap(find.text('Meyer'));
    await tester.pumpAndSettle();
    expect(find.text('Als bezahlt markieren'), findsOneWidget);
    expect(find.textContaining('Offen — fällig am'), findsOneWidget);
    await tester.tap(find.text('2. Mahnung erzeugen'));
    // Die PDF-Vorschau rendert fortlaufend — nicht auf Ruhe warten.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(PdfPreview), findsOneWidget);
    expect(find.textContaining('2. Mahnung R-'), findsOneWidget, reason: 'Mahnschreiben geöffnet');
  });
}
