import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/data/repositories/company_repository.dart';
import 'package:werkkernerp/domain/services/active_company_service.dart';
import 'package:werkkernerp/domain/services/online_accounts.dart';
import 'package:werkkernerp/domain/services/online_session.dart';
import 'package:werkkernerp/ui/screens/company_switcher_screen.dart';
import 'package:werkkernerp/ui/screens/online/online_home_screen.dart';

import 'online_test_server.dart';

/// Online-Firmen auf der Startseite, „angemeldet bleiben“ (nur das
/// Sitzungs-Token, nie das Passwort) und automatisches Abmelden nach
/// Ablauf der 7-Tage-Sitzung.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  late OnlineTestServer server;
  late MemoryOnlineAccountStore store;

  Future<void> pumpStart(WidgetTester tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      ChangeNotifierProvider<ActiveCompanyService>.value(
        value: ActiveCompanyService(CompanyRepository(db)),
        child: MaterialApp(
          home: CompanySwitcherScreen(
            accountStore: store,
            onlineClientFactory: (_) => server.client(),
            offlineStoreFactory: () => null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> loginFromStart(WidgetTester tester, {required bool stay}) async {
    await tester.tap(find.byTooltip('Online anmelden'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('online-server')), 'erp.example.org');
    await tester.enterText(find.byKey(const Key('online-email')), 'kay@example.com');
    await tester.enterText(find.byKey(const Key('online-password')), 'passwort-12345');
    if (stay) await tester.tap(find.byKey(const Key('online-stay-logged-in')));
    await tester.tap(find.text('Anmelden'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elektro Kay'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Elektro Kay — '), findsOneWidget);
  }

  Future<void> backToStart(WidgetTester tester) async {
    await tester.pageBack();
    await tester.pumpAndSettle();
  }

  setUp(() {
    server = OnlineTestServer();
    store = MemoryOnlineAccountStore();
  });

  testWidgets('Angemeldet bleiben: Firma auf der Startseite öffnet ohne Passwort, nie wird das Passwort gespeichert',
      (tester) async {
    await tester.runAsync(() => server.seedCompany(email: 'kay@example.com', companyName: 'Elektro Kay', permissions: const ['customers.read']));
    await pumpStart(tester);
    await loginFromStart(tester, stay: true);
    expect(store.value, isNot(contains('passwort-12345')));
    await backToStart(tester);

    expect(find.text('Online'), findsOneWidget);
    expect(find.textContaining('angemeldet bis'), findsOneWidget);
    await tester.tap(find.text('Elektro Kay'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Elektro Kay — '), findsOneWidget, reason: 'ohne Passworteingabe');
    expect(find.byKey(const Key('online-password')), findsNothing);

    // Abmelden beendet die gespeicherte Sitzung; die Firma bleibt gelistet.
    await tester.tap(find.byTooltip('Weitere Aktionen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abmelden'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Passwort nötig'), findsOneWidget);
  });

  testWidgets('Ohne „angemeldet bleiben“: Klick auf die Firma fragt nur das Passwort und öffnet dann direkt',
      (tester) async {
    await tester.runAsync(() => server.seedCompany(email: 'kay@example.com', companyName: 'Elektro Kay', permissions: const ['customers.read']));
    await pumpStart(tester);
    await loginFromStart(tester, stay: false);
    await backToStart(tester);
    expect(find.textContaining('Passwort nötig'), findsOneWidget);
    expect(store.value, isNot(contains('"token"')));

    await tester.tap(find.text('Elektro Kay'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byKey(const Key('online-email'))).controller!.text, 'kay@example.com');
    await tester.enterText(find.byKey(const Key('online-password')), 'passwort-12345');
    await tester.tap(find.text('Anmelden'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Elektro Kay — '), findsOneWidget, reason: 'keine erneute Firmenwahl');
  });

  testWidgets('Zweite Firma desselben Kontos öffnet mit der gespeicherten Sitzung; ungültige Sitzung verlangt Passwort',
      (tester) async {
    await tester.runAsync(
      () => server.seedCompany(email: 'kay@example.com', companyName: 'Elektro Kay', permissions: const ['customers.read']),
    );
    await tester.runAsync(() async {
      final client = server.client();
      final login = await client.login('kay@example.com', 'passwort-12345');
      await client.createCompany(login.identityToken, 'Nord Impuls');
    });
    await pumpStart(tester);
    await loginFromStart(tester, stay: true);
    await backToStart(tester);

    await tester.tap(find.text('Nord Impuls'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Nord Impuls — '), findsOneWidget);
    await backToStart(tester);

    // Sitzung serverseitig beendet (z. B. Passwort auf anderem Gerät
    // geändert): verwerfen und Passwort verlangen statt Fehlerschleife.
    final saved = (await tester.runAsync(store.load))!.single;
    await tester.runAsync(() => (server.client()..token = saved.token).logout());
    await tester.tap(find.text('Elektro Kay'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Anmeldung abgelaufen'), findsOneWidget);
    expect((await tester.runAsync(store.load))!.single.token, isNull);
  });

  testWidgets('Nach Ablauf der Sitzung meldet die App automatisch ab und verlangt das Passwort', (tester) async {
    final token = await tester.runAsync(
      () => server.seedCompany(email: 'kay@example.com', companyName: 'Elektro Kay', permissions: const ['customers.read']),
    );
    var ended = false;
    final session = OnlineSession(
      client: server.client()..token = token,
      serverUrl: Uri.parse('http://localhost'),
      email: 'kay@example.com',
      companyId: 'c',
      companyName: 'Elektro Kay',
      isAdmin: false,
      permissions: const {'customers.read'},
      modules: const {},
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 1)),
      onEnded: () async => ended = true,
    );
    await tester.pumpWidget(MaterialApp(
      home: OnlineHomeScreen(session: session, expiredBuilder: (notice) => Scaffold(body: Text(notice))),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Elektro Kay — '), findsOneWidget);

    await tester.pump(const Duration(minutes: 2));
    await tester.pumpAndSettle();
    expect(find.textContaining('Anmeldung ist abgelaufen'), findsOneWidget);
    expect(ended, isTrue, reason: 'gespeicherte Sitzung verworfen');
  });
}
