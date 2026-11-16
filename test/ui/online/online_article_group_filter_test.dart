import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:werkkernerp/ui/screens/online/online_login_screen.dart';

import 'online_test_server.dart';

/// A1-Nachtrag (Kay, 15.11.2026): Gruppenfilter der Artikelübersicht online.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Online: Gruppe, leere Gruppe, ohne Gruppe, alle', (tester) async {
    tester.view.physicalSize = const Size(1400, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final server = OnlineTestServer();
    await tester.runAsync(() async {
      final token = await server.seedCompany(
        email: 'kay@example.com',
        companyName: 'Nord-Impuls',
        permissions: ['articles.read', 'articles.write'],
      );
      final verteiler = (await server.post('/article-groups', {'name': 'Verteilereinbau', 'markupPercent': 30}, token))['id'];
      await server.post('/article-groups', {'name': 'Schaltermaterial', 'markupPercent': 25}, token);
      await server.post('/articles', {'name': 'FI-Schalter 40A', 'articleGroupId': verteiler, 'active': true}, token);
      await server.post('/articles', {'name': 'Anfahrt pauschal', 'active': true}, token);
    });
    await tester.pumpWidget(MaterialApp(
      home: OnlineLoginScreen(clientFactory: (_) => server.client(), offlineStoreFactory: () => null),
    ));
    await tester.enterText(find.byKey(const Key('online-server')), 'erp.example.org');
    await tester.enterText(find.byKey(const Key('online-email')), 'kay@example.com');
    await tester.enterText(find.byKey(const Key('online-password')), 'passwort-12345');
    await tester.tap(find.text('Anmelden'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nord-Impuls'));
    await tester.pumpAndSettle();
    await openTab(tester, 'Artikel');

    Future<void> choose(String label) async {
      await tester.tap(find.byKey(const Key('article-group-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    expect(find.text('FI-Schalter 40A'), findsOneWidget);
    await choose('Verteilereinbau');
    expect(find.text('FI-Schalter 40A'), findsOneWidget);
    expect(find.text('Anfahrt pauschal'), findsNothing);
    await choose('Schaltermaterial');
    expect(find.text('Keine Artikel für diese Auswahl.'), findsOneWidget);
    await choose('Ohne Gruppe');
    expect(find.text('Anfahrt pauschal'), findsOneWidget);
    expect(find.text('FI-Schalter 40A'), findsNothing);
    await choose('Alle Gruppen');
    expect(find.text('FI-Schalter 40A'), findsOneWidget);
    expect(find.text('Anfahrt pauschal'), findsOneWidget);
  });
}
