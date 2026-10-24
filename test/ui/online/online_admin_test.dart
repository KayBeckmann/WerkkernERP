import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:werkkernerp/ui/screens/online/online_login_screen.dart';

import 'online_test_server.dart';

/// Kompletter Online-Einstieg ausschließlich über die App-Oberfläche —
/// kein vorbereitender API-Aufruf: Konto registrieren, Firma anlegen,
/// eigener Gruppe Rechte geben, Mitarbeiter einladen, Einladung einlösen.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> fillLogin(WidgetTester tester, OnlineTestServer server, String email) async {
    await tester.pumpWidget(MaterialApp(key: UniqueKey(), home: OnlineLoginScreen(clientFactory: (_) => server.client(), offlineStoreFactory: () => null)));
    await tester.enterText(find.byKey(const Key('online-server')), 'erp.example.org');
    await tester.enterText(find.byKey(const Key('online-email')), email);
    await tester.enterText(find.byKey(const Key('online-password')), 'passwort-12345');
  }

  testWidgets('Registrieren → Firma anlegen → Rechte vergeben → einladen → Einladung einlösen', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final server = OnlineTestServer();

    await fillLogin(tester, server, 'chef@example.com');
    await tester.tap(find.text('Konto registrieren'));
    await tester.pumpAndSettle();
    expect(find.textContaining('noch keiner Firma zugeordnet'), findsOneWidget);

    await tester.tap(find.text('Neue Firma anlegen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('online-new-company-name')), 'Elektro Neu');
    await tester.tap(find.text('Anlegen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elektro Neu'));
    await tester.pumpAndSettle();
    // Startgruppe „Projektleiter“ bringt Standardrechte mit — sofort nutzbar.
    expect(find.textContaining('noch keine Rechte zugewiesen'), findsNothing);
    expect(find.text('Kunden'), findsOneWidget);

    // Verwaltung: eigener Gruppe (Projektleiter) das Kunden-Leserecht entziehen.
    await tester.tap(find.byTooltip('Verwaltung'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gruppen & Rechte'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Projektleiter'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Kunden ansehen').first);
    await tester.pumpAndSettle();

    // Mitarbeiter einladen.
    await tester.tap(find.text('Einladungen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Einladen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('online-invite-email')), 'monteur@example.com');
    await tester.tap(find.text('Einladung erstellen'));
    await tester.pumpAndSettle();
    final token = tester.widget<SelectableText>(find.byKey(const Key('online-invitation-token'))).data!;
    expect(token, isNotEmpty);
    await tester.tap(find.text('Fertig'));
    await tester.pumpAndSettle();
    expect(find.text('monteur@example.com'), findsOneWidget);

    // Zurück: Kunden-Tab ist weg (Rechte wurden neu geladen).
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Elektro Neu · online'), findsOneWidget);
    expect(find.text('Kunden'), findsNothing);

    // Eingeladene Person löst die Einladung in der App ein.
    await fillLogin(tester, server, 'monteur@example.com');
    await tester.tap(find.text('Einladung einlösen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('online-invitation-code')), token);
    await tester.tap(find.text('Einlösen'));
    await tester.pumpAndSettle();
    expect(find.text('Elektro Neu'), findsOneWidget);
    expect(find.text('Projektleiter'), findsOneWidget, reason: 'eingeladene Gruppe (Standard: erste)');
  });
}
