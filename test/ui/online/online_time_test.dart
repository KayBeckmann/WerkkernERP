import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:werkkernerp/ui/screens/online/online_login_screen.dart';

import 'online_test_server.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Zeit auf einen Auftrag buchen, Summe und "Gebucht" im Auftrag', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final server = OnlineTestServer();
    await tester.runAsync(() async {
      final token = await server.seedCompany(
        email: 'monteur@example.com',
        companyName: 'Elektro Kay',
        permissions: ['customers.read', 'customers.write', 'invoices.read', 'invoices.write', 'timeTracking.write'],
      );
      await server.put('/company/modules', {'modules': ['orders', 'timeTracking']}, token);
      final customer = await server.post('/customers', {'name': 'Baustelle Meyer'}, token);
      await server.post('/documents', {'kind': 'order', 'customerId': customer['id']}, token);
    });

    await tester.pumpWidget(MaterialApp(
      home: OnlineLoginScreen(clientFactory: (_) => server.client(), offlineStoreFactory: () => null),
    ));
    await tester.enterText(find.byKey(const Key('online-server')), 'erp.example.org');
    await tester.enterText(find.byKey(const Key('online-email')), 'monteur@example.com');
    await tester.enterText(find.byKey(const Key('online-password')), 'passwort-12345');
    await tester.tap(find.text('Anmelden'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elektro Kay'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Zeiten'));
    await tester.pumpAndSettle();
    expect(find.text('Noch keine Zeiten gebucht.'), findsOneWidget);
    await tester.tap(find.text('Zeit buchen'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('online-time-document')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Baustelle Meyer').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('online-time-hours')), '2,5');
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(find.text('2,5 Std.'), findsOneWidget);
    expect(find.text('Deine Buchungen'), findsOneWidget);

    await tester.tap(find.text('Dokumente'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Auftrag (Entwurf)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Gebucht 2,5 Std.'), findsOneWidget);
  });
}
