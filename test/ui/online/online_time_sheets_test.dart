import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:werkkern_client/werkkern_client.dart';
import 'package:werkkernerp/ui/screens/online/online_login_screen.dart';
import 'package:werkkernerp/ui/widgets/signature_pad.dart';

import 'online_test_server.dart';

/// 1×1-PNG.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

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
      await server.put('/company/modules', {'modules': ['timeTracking', 'orders']}, token);
      final customer = await server.post('/customers', {'name': 'Meyer'}, token);
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
    await tester.tap(find.byIcon(Icons.timer_outlined).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stundenzettel'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Stundenzettel anlegen'));
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
    await tester.tap(find.textContaining('unterschrieben'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Unterschrieben von Herr Meyer'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Buchung hinzufügen'), findsNothing);
    await tester.tap(find.text('Nachtrag anlegen'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Nachtrag zu einem unterschriebenen Zettel'), findsOneWidget);
  });
}
