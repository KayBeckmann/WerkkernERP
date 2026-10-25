import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:werkkernerp/ui/screens/online/online_login_screen.dart';

import 'online_test_server.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Fuhrpark unter „Mehr“: Fahrzeug anlegen, Leasing mit Tilgung/Zins buchen, Jahressumme', (tester) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final server = OnlineTestServer();
    await tester.runAsync(() async {
      final token = await server.seedCompany(
        email: 'kay@example.com',
        companyName: 'Elektro Kay',
        permissions: [
          'invoices.read', 'customers.read', 'projects.read', 'timeTracking.write', 'articles.read',
          'fleet.read', 'fleet.write',
        ],
      );
      await server.put('/company/modules', {'modules': ['fleet', 'projects', 'timeTracking']}, token);
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

    expect(find.text('Mehr'), findsOneWidget, reason: 'sechs Bereiche → vier + Mehr');
    await tester.tap(find.text('Mehr'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fuhrpark'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Fahrzeug anlegen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('online-form-name')), 'Sprinter');
    await tester.enterText(find.byKey(const Key('online-form-licensePlate')), 'HH-EK 1');
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sprinter · HH-EK 1'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kosten buchen'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('online-form-category')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leasing/Finanzierung').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('online-form-amount')), '450');
    await tester.enterText(find.byKey(const Key('online-form-principal')), '400');
    await tester.enterText(find.byKey(const Key('online-form-interest')), '50');
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    expect(find.text('Summe ${DateTime.now().year}'), findsOneWidget);
    expect(find.text('450,00 €'), findsWidgets);
    expect(find.text('davon Zins'), findsOneWidget);
    expect(find.textContaining('Tilgung 400,00 €'), findsOneWidget);
  });
}
