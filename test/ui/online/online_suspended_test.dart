import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:werkkernerp/ui/screens/online/online_login_screen.dart';
import 'package:werkkernerp_server/src/platform_admin_tool.dart';

import 'online_test_server.dart';

/// SaaS: vom Anbieter gesperrte Firma — in der Firmenwahl erkennbar,
/// Anmeldung scheitert mit verständlicher Meldung.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Gesperrte Firma: Hinweis in der Firmenwahl, Öffnen scheitert', (tester) async {
    final server = OnlineTestServer();
    await tester.runAsync(() async {
      await server.seedCompany(email: 'kay@example.com', companyName: 'Elektro Kay', permissions: const ['customers.read']);
      await grantPlatformAdmin(server.repository, email: 'betreiber@example.org', password: 'betreiber-123');
      final platform = server.client();
      await platform.platformLogin('betreiber@example.org', 'betreiber-123');
      final company = (await platform.platformCompanies()).single;
      await platform.suspendCompany(company.id, reason: 'Abo offen');
    });

    await tester.pumpWidget(MaterialApp(
      home: OnlineLoginScreen(clientFactory: (_) => server.client(), offlineStoreFactory: () => null),
    ));
    await tester.enterText(find.byKey(const Key('online-server')), 'erp.example.org');
    await tester.enterText(find.byKey(const Key('online-email')), 'kay@example.com');
    await tester.enterText(find.byKey(const Key('online-password')), 'passwort-12345');
    await tester.tap(find.text('Anmelden'));
    await tester.pumpAndSettle();

    expect(find.text('Gesperrt — bitte an den Anbieter wenden'), findsOneWidget);
    await tester.tap(find.text('Elektro Kay'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Diese Firma ist gesperrt'), findsOneWidget);
    expect(find.textContaining('Abo offen'), findsNothing, reason: 'Grund bleibt intern');
    expect(find.textContaining('Elektro Kay — '), findsNothing);
  });
}
