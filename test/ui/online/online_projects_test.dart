import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:werkkernerp/ui/screens/online/online_login_screen.dart';

import 'online_test_server.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Projekt anlegen, Dokument dem Projekt zuordnen, Zeit aufs Projekt buchen, Projektdetail', (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final server = OnlineTestServer();
    await tester.runAsync(() async {
      final token = await server.seedCompany(
        email: 'kay@example.com',
        companyName: 'Elektro Kay',
        permissions: [
          'customers.read', 'customers.write', 'invoices.read', 'invoices.write',
          'projects.read', 'projects.write', 'timeTracking.read', 'timeTracking.write',
        ],
      );
      await server.put('/company/modules', {'modules': ['projects', 'timeTracking', 'orders']}, token);
      await server.post('/customers', {'name': 'Meyer'}, token);
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

    await tester.tap(find.text('Projekte'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Projekt anlegen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('online-project-name')), 'Neubau Meyer');
    await tester.tap(find.text('Anlegen'));
    await tester.pumpAndSettle();
    expect(find.text('$yy/01 · Neubau Meyer'), findsOneWidget);

    // Dokument mit Projekt anlegen.
    await tester.tap(find.text('Dokumente'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Neues Dokument'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('online-new-document-customer')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Meyer').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('— ohne Projekt —'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('$yy/01 · Neubau Meyer').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anlegen'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Zeit direkt aufs Projekt buchen.
    await tester.tap(find.text('Zeiten'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zeit buchen'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('online-time-project')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('$yy/01 · Neubau Meyer').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('online-time-hours')), '1,5');
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    // Projektdetail: Dokument + gebuchte Stunden.
    await tester.tap(find.text('Projekte'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('$yy/01 · Neubau Meyer'));
    await tester.pumpAndSettle();
    expect(find.text('Rechnung (Entwurf)'), findsOneWidget);
    expect(find.text('0 / 1,5'), findsOneWidget, reason: 'geplant / gebucht');
  });
}
