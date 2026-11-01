import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:werkkernerp/ui/screens/online/online_login_screen.dart';
import 'package:werkkernerp/ui/widgets/sidebar_nav_item.dart';

import 'online_test_server.dart';

/// Kay-Feedback 2026-11-01: Online-Firma im selben Layout wie die lokale
/// — breit Sidebar mit Gruppen und „Firma wechseln“, schmal Bottom-Bar
/// mit drei festen Einträgen plus „Mehr“.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const permissions = [
    'invoices.read', 'customers.read', 'articles.read', 'projects.read', 'fleet.read', 'accounting.read', //
    'dunning.read',
  ];

  Future<void> openCompany(WidgetTester tester, OnlineTestServer server) async {
    await tester.runAsync(() async {
      final token = await server.seedCompany(email: 'kay@example.com', companyName: 'Elektro Kay', permissions: permissions);
      await server.put('/company/modules', {'modules': ['projects', 'fleet', 'buchhaltung', 'dunning']}, token);
    });
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(navigatorKey: navigator, home: const Scaffold(body: Text('Startseite'))));
    navigator.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => OnlineLoginScreen(clientFactory: (_) => server.client(), offlineStoreFactory: () => null),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('online-server')), 'erp.example.org');
    await tester.enterText(find.byKey(const Key('online-email')), 'kay@example.com');
    await tester.enterText(find.byKey(const Key('online-password')), 'passwort-12345');
    await tester.tap(find.text('Anmelden'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elektro Kay'));
    await tester.pumpAndSettle();
  }

  testWidgets('Breit: Sidebar mit Gruppen wie offline, Details neben der Sidebar, „Firma wechseln“ zur Startseite',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await openCompany(tester, OnlineTestServer());

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Elektro Kay · online'), findsOneWidget);
    for (final section in ['FAKTURIERUNG', 'STAMMDATEN', 'BUCHHALTUNG']) {
      expect(find.text(section), findsOneWidget);
    }
    // Gleiche Bereiche und Namen wie offline (`home_shell.dart`).
    for (final item in [
      'Dashboard',
      'Rechnungen',
      'Mahnwesen',
      'Kunden',
      'Artikel',
      'Lieferanten',
      'Projekte',
      'Fuhrpark',
      'Offene Posten',
      'Belege',
      'EÜR-Übersicht',
      'Bankabgleich',
      'Einstellungen',
    ]) {
      expect(find.widgetWithText(SidebarNavItem, item), findsOneWidget, reason: item);
    }

    await tester.tap(find.widgetWithText(SidebarNavItem, 'Einstellungen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mitglieder'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Mitglieder'), findsOneWidget);
    expect(find.widgetWithText(SidebarNavItem, 'Rechnungen'), findsOneWidget, reason: 'Sidebar bleibt beim Öffnen sichtbar');
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(SidebarNavItem, 'Firma wechseln'));
    await tester.pumpAndSettle();
    expect(find.text('Startseite'), findsOneWidget);
  });

  testWidgets('Schmal: drei feste Einträge plus „Mehr“ mit gruppierter Übersicht', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await openCompany(tester, OnlineTestServer());

    expect(find.byType(SidebarNavItem), findsNothing);
    expect(find.byType(NavigationDestination), findsNWidgets(4));
    for (final item in ['Dashboard', 'Rechnungen', 'Kunden', 'Mehr']) {
      expect(find.widgetWithText(NavigationDestination, item), findsOneWidget, reason: item);
    }
    await tester.tap(find.widgetWithText(NavigationDestination, 'Mehr'));
    await tester.pumpAndSettle();
    expect(find.text('BUCHHALTUNG'), findsOneWidget);
    await tester.tap(find.widgetWithText(ListTile, 'Fuhrpark'));
    await tester.pumpAndSettle();
    expect(find.text('Elektro Kay — Fuhrpark'), findsOneWidget);
  });
}
