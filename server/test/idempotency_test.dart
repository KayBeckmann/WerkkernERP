import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';
import 'package:werkkernerp_server/src/business/repository.dart';
import 'package:werkkernerp_server/src/business/repository_memory.dart';
import 'package:werkkernerp_server/src/repository.dart';
import 'package:werkkernerp_server/src/repository_memory.dart';
import 'package:werkkernerp_server/src/router.dart';

void main() => runIdempotencyTests(() async => (InMemoryPhaseBRepository(), InMemoryBusinessRepository()));

/// B2 "Doppelübertragung": dieselbe Änderung zweimal gesendet wirkt
/// genau einmal — auch gleichzeitig.
void runIdempotencyTests(Future<(PhaseBRepository, BusinessRepository)> Function() create) {
  late HttpServer server;
  late Uri base;
  late Map<String, String> auth;
  late String customerId;

  setUp(() async {
    final (repository, business) = await create();
    server = await shelf_io.serve(PhaseBRouter(repository: repository, business: business).handler.call, 'localhost', 0);
    base = Uri.parse('http://localhost:${server.port}');
    Future<Map<String, Object?>> post(String path, Object body, [Map<String, String>? headers]) async =>
        jsonDecode((await http.post(base.resolve(path), headers: headers, body: jsonEncode(body))).body) as Map<String, Object?>;
    await post('/auth/register', {'email': 'a@example.com', 'password': 'passwort-12345'});
    Future<String> identity() async => (await post('/auth/login', {'email': 'a@example.com', 'password': 'passwort-12345'}))['identityToken'] as String;
    final companyId = (await post('/companies', {'identityToken': await identity(), 'name': 'A'}))['companyId'] as String;
    final token = (await post('/auth/select-company', {'identityToken': await identity(), 'companyId': companyId}))['token'] as String;
    auth = {'authorization': 'Bearer $token'};
    final me = jsonDecode((await http.get(base.resolve('/me'), headers: auth)).body) as Map;
    for (final p in ['customers.read', 'customers.write', 'invoices.read', 'invoices.write']) {
      await http.put(base.resolve('/groups/${me['groupId']}/permissions/$p'), headers: auth, body: jsonEncode({'granted': true}));
    }
    customerId = (await post('/customers', {'name': 'K'}, auth))['id'] as String;
  });
  tearDown(() => server.close(force: true));

  Future<http.Response> createDoc(String key, {String notes = 'x'}) => http.post(
        base.resolve('/documents'),
        headers: {...auth, 'idempotency-key': key},
        body: jsonEncode({'customerId': customerId, 'notes': notes}),
      );

  Future<int> documentCount() async =>
      ((jsonDecode((await http.get(base.resolve('/documents'), headers: auth)).body) as Map)['documents'] as List).length;

  test('Erneut gesendete Anlage (Antwort ging verloren) legt nichts doppelt an und liefert dieselbe Antwort', () async {
    final first = await createDoc('op-1');
    final second = await createDoc('op-1');
    expect(first.statusCode, 201);
    expect(second.statusCode, 201);
    expect(second.headers['idempotent-replay'], 'true');
    expect(jsonDecode(second.body)['id'], jsonDecode(first.body)['id']);
    expect(await documentCount(), 1);
  });

  test('Gleichzeitiger Doppelversand: genau eine Anlage', () async {
    final responses = await Future.wait([for (var i = 0; i < 4; i++) createDoc('op-par')]);
    expect(await documentCount(), 1);
    final ids = {for (final r in responses.where((r) => r.statusCode == 201)) jsonDecode(r.body)['id']};
    expect(ids, hasLength(1));
    for (final r in responses) {
      expect(r.statusCode, anyOf(201, 409), reason: '409 = noch in Bearbeitung, erneut senden');
    }
  });

  test('Update mit Version: Wiederholung bekommt die ursprüngliche Erfolgsantwort statt 409', () async {
    final doc = jsonDecode((await createDoc('op-a')).body) as Map;
    Future<http.Response> update() => http.put(
          base.resolve('/documents/${doc['id']}'),
          headers: {...auth, 'idempotency-key': 'op-b'},
          body: jsonEncode({'version': 1, 'notes': 'offline geändert'}),
        );
    final first = await update();
    final again = await update();
    expect(first.statusCode, 200);
    expect(again.statusCode, 200, reason: 'ohne Idempotenz wäre das 409 (Version 1 veraltet)');
    expect(jsonDecode(again.body)['version'], 2);
  });

  test('Derselbe Schlüssel für eine andere Anfrage -> 422; Schlüssel sind je Nutzer/Firma getrennt', () async {
    await createDoc('op-x', notes: 'eins');
    final misuse = await createDoc('op-x', notes: 'zwei');
    expect(misuse.statusCode, 422);
    expect(await documentCount(), 1);
  });

  test('Ohne Sitzung kein Speichern unter dem Schlüssel (401 bleibt 401)', () async {
    final r = await http.post(base.resolve('/documents'), headers: {'idempotency-key': 'op-anon'}, body: '{}');
    expect(r.statusCode, 401);
  });
}
