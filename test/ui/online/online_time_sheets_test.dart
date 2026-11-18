import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:werkkern_client/werkkern_client.dart';
import 'package:werkkernerp/domain/services/online_session.dart';
import 'package:werkkernerp/ui/screens/online/online_time_sheets_screen.dart';
import 'package:werkkernerp/ui/screens/online/online_login_screen.dart';
import 'package:werkkernerp/ui/widgets/signature_pad.dart';

import 'online_test_server.dart';

/// 1×1-PNG.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('PDF action requires signature and write permission', (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final server = OnlineTestServer();
    late String token;
    late String id;
    await tester.runAsync(() async {
      token = await server.seedCompany(
        email: 'test@example.com', companyName: 'Synthetic Co',
        permissions: ['timeTracking.write', 'invoices.read', 'invoices.write', 'customers.read', 'customers.write'],
      );
      await server.put('/company/modules', {'modules': ['timeTracking', 'orders']}, token);
      final customer = await server.post('/customers', {'name': 'Test Customer'}, token);
      final order = await server.post('/documents', {'kind': 'order', 'customerId': customer['id'], 'items': []}, token);
      final entry = await server.post('/time-entries', {'date': '2026-01-02', 'hours': '1', 'documentId': order['id']}, token);
      final client = server.client()..token = token;
      id = (await client.createTimeSheet(documentId: order['id'] as String,
          date: DateTime(2026, 1, 2), entryIds: [entry['id'] as String])).id;
    });
    final client = server.client()..token = token;
    final session = OnlineSession(client: client, serverUrl: Uri.parse('https://test.example'),
        email: 'test@example.com', companyId: 'test', companyName: 'Synthetic Co',
        isAdmin: false, permissions: {'timeTracking.write'}, modules: {'timeTracking'});
    await tester.pumpWidget(MaterialApp(home: OnlineTimeSheetScreen(session: session, sheetId: id)));
    await tester.pumpAndSettle();
    expect(find.text('PDF erstellen und archivieren'), findsNothing);
    await tester.runAsync(() => client.signTimeSheet(id, _png));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(MaterialApp(home: OnlineTimeSheetScreen(session: session, sheetId: id)));
    await tester.pumpAndSettle();
    final action = find.widgetWithText(OutlinedButton, 'PDF erstellen und archivieren');
    expect(tester.widget<OutlinedButton>(action).onPressed, isNotNull);
    session.permissions = {};
    await tester.pumpWidget(MaterialApp(home: OnlineTimeSheetScreen(session: session, sheetId: id)));
    await tester.pumpAndSettle();
    expect(tester.widget<OutlinedButton>(action).onPressed, isNull);
    expect(tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Per E-Mail senden')).onPressed, isNull);
  });

  testWidgets('Stundenzettel anlegen (Tagesbuchungen übernommen), Unterschrift-Dialog, unterschrieben → Nachtrag', (tester) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final server = OnlineTestServer();
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    late String token;
    await tester.runAsync(() async {
      token = await server.seedCompany(
        email: 'kay@example.com',
        companyName: 'Elektro Kay',
        permissions: ['timeTracking.write', 'invoices.read', 'invoices.write', 'customers.read', 'customers.write'],
      );
      await server.put('/company/modules', {'modules': ['timeTracking', 'orders', 'smtp']}, token);
      final customer = await server.post('/customers', {'name': 'Meyer', 'invoiceEmail': 'buchhaltung@meyer.example'}, token);
      final order = await server.post('/documents', {'kind': 'order', 'customerId': customer['id'], 'items': []}, token);
      await server.post('/time-entries', {'date': today, 'hours': '2.5', 'documentId': order['id']}, token);
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
    await openTab(tester, 'Stundenzettel');

    await tester.tap(find.text('Stundenzettel erstellen'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('online-form-documentId')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Meyer').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anlegen'));
    await tester.pumpAndSettle();
    expect(find.text('2,5 Std.'), findsWidgets, reason: 'Tagesbuchung automatisch übernommen');

    // Unterschrift-Dialog: Zeichnen schaltet „Unterschreiben“ frei.
    await tester.tap(find.text('Vom Kunden unterschreiben lassen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('online-form-signerName')), 'Herr Meyer');
    await tester.tap(find.text('Weiter zur Unterschrift'));
    await tester.pumpAndSettle();
    final signButton = find.widgetWithText(FilledButton, 'Unterschreiben');
    expect(tester.widget<FilledButton>(signButton).onPressed, isNull);
    await tester.dragFrom(tester.getCenter(find.byType(SignaturePad)), const Offset(80, 40));
    await tester.pump();
    expect(tester.widget<FilledButton>(signButton).onPressed, isNotNull);
    expect(find.text(signatureDisclaimer), findsOneWidget);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();

    // PNG-Export ist im Widget-Test nicht ausführbar — Unterschrift per API.
    await tester.runAsync(() async {
      final client = server.client()..token = token;
      final sheet = (await client.timeSheets()).single;
      await client.signTimeSheet(sheet.id, _png, signerName: 'Herr Meyer');
    });
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Unterschrieben'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Unterschrieben von Herr Meyer'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Buchung hinzufügen'), findsNothing);
    final send = find.widgetWithText(OutlinedButton, 'Per E-Mail senden');
    expect(send, findsOneWidget);
    expect(tester.widget<OutlinedButton>(send).onPressed, isNull);
    final createPdf = find.widgetWithText(OutlinedButton, 'PDF erstellen und archivieren');
    expect(tester.widget<OutlinedButton>(createPdf).onPressed, isNotNull);
    await tester.tap(createPdf);
    await tester.pumpAndSettle();
    final ready = find.widgetWithText(OutlinedButton, 'Per E-Mail senden');
    expect(tester.widget<OutlinedButton>(ready).onPressed, isNotNull);
    await tester.runAsync(() async {
      final client = server.client()..token = token;
      final sheet = (await client.timeSheets()).single;
      final versions = await client.timeSheetPdfVersions(sheet.id);
      expect(versions, hasLength(1));
      final bytes = await client.downloadTimeSheetPdf(sheet.id, versions.single);
      expect(utf8.decode(bytes.take(5).toList()), '%PDF-');
      expect(bytes.length, greaterThan(1000));
    });
    await tester.tap(ready);
    await tester.pumpAndSettle();
    expect(find.text('Buchhaltung: Empfänger *'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('online-form-to'))).controller!.text,
        'buchhaltung@meyer.example');
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nachtrag anlegen'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Nachtrag zu einem unterschriebenen Zettel'), findsOneWidget);
  });
}
