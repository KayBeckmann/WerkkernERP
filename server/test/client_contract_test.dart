import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';
import 'package:werkkern_client/werkkern_client.dart';

import 'package:werkkernerp_server/src/business/repository_memory.dart';
import 'package:werkkernerp_server/src/repository_memory.dart';
import 'package:werkkernerp_server/src/router.dart';

/// Vertragstest: der Client, den die Flutter-App benutzt
/// (`packages/werkkern_client`), gegen den echten Server-Router. Ein
/// umbenanntes JSON-Feld auf einer Seite fällt hier auf, nicht erst
/// auf Kays Gerät.
void main() {
  late HttpServer server;
  late Uri baseUrl;

  setUp(() async {
    final router = PhaseBRouter(repository: InMemoryPhaseBRepository(), business: InMemoryBusinessRepository());
    server = await shelf_io.serve(router.handler.call, 'localhost', 0);
    baseUrl = Uri.parse('http://localhost:${server.port}');
  });
  tearDown(() => server.close(force: true));

  Future<void> raw(String method, String path, Object body, [String? token]) async {
    final request = http.Request(method, baseUrl.resolve(path))..body = jsonEncode(body);
    if (token != null) request.headers['authorization'] = 'Bearer $token';
    await http.Response.fromStream(await request.send());
  }

  /// Firma + Admin mit allen Fach-Rechten über rohe HTTP-Aufrufe
  /// (Admin-Funktionen sind nicht Teil des App-Clients).
  Future<WerkkernApiClient> loggedInClient() async {
    await raw('POST', '/auth/register', {'email': 'kay@example.com', 'password': 'passwort-12345'});
    final client = WerkkernApiClient(baseUrl: baseUrl);
    final first = await client.login('kay@example.com', 'passwort-12345');
    expect(first.memberships, isEmpty);
    final created = await http.post(baseUrl.resolve('/companies'),
        body: jsonEncode({'identityToken': first.identityToken, 'name': 'Elektro Kay'}));
    final companyId = (jsonDecode(created.body) as Map)['companyId'] as String;

    final login = await client.login('kay@example.com', 'passwort-12345');
    expect(login.memberships.single.companyName, 'Elektro Kay');
    expect(login.memberships.single.isAdmin, isTrue);
    await client.selectCompany(login.identityToken, companyId);

    final me = jsonDecode((await http.get(baseUrl.resolve('/me'), headers: {'authorization': 'Bearer ${client.token}'})).body) as Map;
    for (final p in ['customers.read', 'customers.write', 'articles.read', 'invoices.read', 'invoices.write', 'invoices.finalize']) {
      await raw('PUT', '/groups/${me['groupId']}/permissions/$p', {'granted': true}, client.token);
    }
    return client;
  }

  test('Anmeldung, Rechte, Kunden, Entwurf, Konflikt, Finalisierung über den App-Client', () async {
    final client = await loggedInClient();
    final perms = await client.myPermissions();
    expect(perms.isAdmin, isTrue);
    expect(perms.permissions, contains('invoices.finalize'));
    expect(await client.modules(), isEmpty);

    final customer = await client.createCustomer(const OnlineCustomer(id: '', name: 'Müller GmbH', vatId: 'DE1'));
    expect(customer.id, isNotEmpty);
    final renamed = await client.updateCustomer(OnlineCustomer(id: customer.id, name: 'Müller & Söhne', vatId: 'DE1'));
    expect(renamed.name, 'Müller & Söhne');
    expect((await client.customers(query: 'söhne')).single.id, customer.id);

    final draft = await client.createDocument(customerId: customer.id, items: const [
      OnlineDocumentItem(kind: OnlineItemKind.hours, description: 'Montage', quantity: '1.5', unitPriceCents: 6000, vatRatePercent: 7),
    ]);
    expect(draft.isDraft, isTrue);
    expect(draft.grossCents, 9630);
    expect(draft.taxLines.single.vatRatePercent, 7);

    final updated = await client.updateDocument(id: draft.id, version: draft.version, notes: 'Zählerschrank', items: [
      ...draft.items,
      const OnlineDocumentItem(kind: OnlineItemKind.text, description: 'Anfahrt', quantity: '1', unitPriceCents: 3000, vatRatePercent: 19),
    ]);
    expect(updated.version, draft.version + 1);
    expect(updated.items, hasLength(2));

    // Zweites Gerät arbeitet noch mit der alten Version -> 409, kein
    // stilles Überschreiben.
    await expectLater(
      client.updateDocument(id: draft.id, version: draft.version, items: const []),
      throwsA(isA<ApiException>().having((e) => e.isConflict, 'isConflict', isTrue)),
    );

    final finalized = await client.finalizeDocument(draft.id, version: updated.version);
    expect(finalized.number, matches(RegExp(r'^R-\d{5}$')));
    expect(finalized.customerSnapshotName, 'Müller & Söhne');
    final listed = await client.documents(status: 'finalized');
    expect(listed.single.grossCents, finalized.grossCents);

    await client.logout();
    expect(client.token, isNull);
  });

  test('Fehlerbilder: falsches Passwort 401, fehlendes Modul 403, nicht erreichbarer Server', () async {
    final client = await loggedInClient();
    final customer = await client.createCustomer(const OnlineCustomer(id: '', name: 'K'));
    await expectLater(
      client.createDocument(customerId: customer.id, kind: 'quote'),
      throwsA(isA<ApiException>().having((e) => e.isForbidden, 'isForbidden', isTrue)),
    );
    await expectLater(
      WerkkernApiClient(baseUrl: baseUrl).login('kay@example.com', 'falsch'),
      throwsA(isA<ApiException>().having((e) => e.isUnauthorized, 'isUnauthorized', isTrue)),
    );
    final unreachable = WerkkernApiClient(baseUrl: Uri.parse('http://127.0.0.1:1'));
    await expectLater(unreachable.health(), throwsA(isA<ApiUnreachable>()));
  });
}
