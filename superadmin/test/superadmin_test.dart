import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:werkkern_client/werkkern_client.dart';
import 'package:werkkern_superadmin/app.dart';
import 'package:werkkernerp_server/src/platform_admin_tool.dart';
import 'package:werkkernerp_server/src/repository_memory.dart';
import 'package:werkkernerp_server/src/router.dart';

/// Echter Server-Router (In-Memory) hinter einem MockClient.
class _Server {
  final repository = InMemoryPhaseBRepository();
  late final handler = PhaseBRouter(repository: repository).handler;
  late final http.Client httpClient = MockClient((request) async {
    final response = await handler(shelf.Request(
      request.method,
      Uri.parse('http://localhost${request.url.path}'),
      body: request.body,
      headers: request.headers,
    ));
    return http.Response.bytes(await response.read().expand((b) => b).toList(), response.statusCode,
        headers: response.headers);
  });

  WerkkernApiClient client() => WerkkernApiClient(baseUrl: Uri.parse('http://localhost'), httpClient: httpClient);

  Future<Map<String, Object?>> call(String path, Object body) async {
    final response = await handler(shelf.Request('POST', Uri.parse('http://localhost$path'), body: jsonEncode(body)));
    return jsonDecode(await response.readAsString()) as Map<String, Object?>;
  }

  Future<String> seedCompany(String email, String name) async {
    await call('/auth/register', {'email': email, 'password': 'passwort-123'});
    final identity = (await call('/auth/login', {'email': email, 'password': 'passwort-123'}))['identityToken'];
    return (await call('/companies', {'identityToken': identity, 'name': name}))['companyId'] as String;
  }
}

void main() {
  late _Server server;

  setUp(() => server = _Server());

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(SuperadminApp(clientFactory: server.client));
  }

  Future<void> login(WidgetTester tester, String email, String password) async {
    await tester.enterText(find.byKey(const Key('login-email')), email);
    await tester.enterText(find.byKey(const Key('login-password')), password);
    await tester.tap(find.text('Anmelden'));
    await tester.pumpAndSettle();
  }

  testWidgets('Firmenkonto ohne Superadmin-Freigabe kommt nicht ins Panel', (tester) async {
    await tester.runAsync(() => server.seedCompany('kunde@example.org', 'Elektro Kunde'));
    await pumpApp(tester);
    await login(tester, 'kunde@example.org', 'passwort-123');
    expect(find.byKey(const Key('login-error')), findsOneWidget);
    expect(find.text('Firmen'), findsNothing);
  });

  testWidgets('Abo pflegen, überfällig markieren, sperren und entsperren', (tester) async {
    late String companyId;
    await tester.runAsync(() async {
      companyId = await server.seedCompany('kunde@example.org', 'Elektro Kunde');
      await server.seedCompany('zweite@example.org', 'Zweite GmbH');
      await grantPlatformAdmin(server.repository, email: 'betreiber@example.org', password: 'betreiber-123');
    });
    await pumpApp(tester);
    await login(tester, 'betreiber@example.org', 'betreiber-123');

    expect(find.text('Elektro Kunde'), findsOneWidget);
    expect(find.text('Zweite GmbH'), findsOneWidget);
    expect(find.textContaining('kunde@example.org · 1 Mitglied'), findsOneWidget);
    expect(find.text('Alle (2)'), findsOneWidget);

    // Suche nach Admin-E-Mail.
    await tester.enterText(find.byKey(const Key('companies-search')), 'zweite@');
    await tester.pumpAndSettle();
    expect(find.text('Elektro Kunde'), findsNothing);
    await tester.enterText(find.byKey(const Key('companies-search')), '');
    await tester.pumpAndSettle();

    // Abo mit Datum in der Vergangenheit -> überfällig (direkt über den Client,
    // der Datumsdialog ist Flutter-Standard).
    await tester.runAsync(() async {
      final client = server.client();
      await client.platformLogin('betreiber@example.org', 'betreiber-123');
      await client.setPlatformBilling(companyId, plan: 'Basis', paidUntil: DateTime.utc(2020, 1, 31));
    });
    await tester.tap(find.byTooltip('Neu laden'));
    await tester.pumpAndSettle();
    expect(find.text('Überfällig'), findsOneWidget);
    expect(find.text('Überfällig (1)'), findsOneWidget);

    // Im Dialog: +1 Monat ab heute (Datum überschritten), Notiz speichern.
    await tester.tap(find.text('Elektro Kunde'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('billing-paid-until'))).data, '31.01.2020');
    await tester.tap(find.text('+1 Monat'));
    await tester.enterText(find.byKey(const Key('billing-note')), 'Rechnung 17 bezahlt');
    await tester.tap(find.text('Abo speichern'));
    await tester.pumpAndSettle();
    expect(find.text('Überfällig'), findsNothing);
    expect(find.text('Überfällig (0)'), findsOneWidget);

    // Sperren mit internem Grund.
    await tester.tap(find.text('Elektro Kunde'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Sperren'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('suspend-reason')), 'Abo offen');
    await tester.tap(find.widgetWithText(FilledButton, 'Sperren'));
    await tester.pumpAndSettle();
    expect(find.text('Gesperrt'), findsOneWidget);
    expect(find.text('Gesperrt (1)'), findsOneWidget);
    final login1 = await tester.runAsync(() => server.call('/auth/login', {'email': 'kunde@example.org', 'password': 'passwort-123'}));
    final m = (login1!['memberships'] as List).single as Map;
    expect(m['suspended'], isTrue);

    // Filter „Gesperrt“, dann entsperren.
    await tester.tap(find.text('Gesperrt (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Zweite GmbH'), findsNothing);
    await tester.tap(find.text('Elektro Kunde'));
    await tester.pumpAndSettle();
    expect(find.text('Abo offen'), findsOneWidget);
    await tester.tap(find.text('Entsperren'));
    await tester.pumpAndSettle();
    expect(find.text('Gesperrt (0)'), findsOneWidget);
    expect(find.text('Keine Firmen in dieser Ansicht.'), findsOneWidget);

    // Abmelden führt zurück zum Login.
    await tester.tap(find.byTooltip('Konto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abmelden'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-email')), findsOneWidget);
  });
}
