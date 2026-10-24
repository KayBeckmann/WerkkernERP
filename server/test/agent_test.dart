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

void main() => runAgentTests(() async => (InMemoryPhaseBRepository(), InMemoryBusinessRepository()));

/// C8-Abnahme: "dieselbe erlaubte Fachaktion funktioniert über UI/API/MCP
/// regelgleich; verbotene Aktionen und Firmenwechsel werden serverseitig
/// pro Aufruf abgewiesen, kein automatischer Versand/Finalisierung ohne
/// die festgelegte Bestätigung."
void runAgentTests(Future<(PhaseBRepository, BusinessRepository)> Function() create) {
  late HttpServer server;
  late Uri base;

  setUp(() async {
    final (repository, business) = await create();
    server = await shelf_io.serve(PhaseBRouter(repository: repository, business: business).handler.call, InternetAddress.loopbackIPv4, 0);
    base = Uri.parse('http://127.0.0.1:${server.port}');
  });
  tearDown(() => server.close(force: true));

  Future<http.Response> call(String method, String path, {Map<String, String>? auth, Object? body}) async {
    final request = http.Request(method, base.resolve(path));
    if (auth != null) request.headers.addAll(auth);
    if (body != null) request.body = jsonEncode(body);
    return http.Response.fromStream(await request.send());
  }

  Map<String, Object?> json(http.Response r) => jsonDecode(r.body) as Map<String, Object?>;

  Future<({Map<String, String> user, String groupId, String companyId})> company(String email, String name) async {
    await call('POST', '/auth/register', body: {'email': email, 'password': 'passwort-12345'});
    Future<String> identity() async =>
        json(await call('POST', '/auth/login', body: {'email': email, 'password': 'passwort-12345'}))['identityToken'] as String;
    final companyId = json(await call('POST', '/companies', body: {'identityToken': await identity(), 'name': name}))['companyId'] as String;
    final token = json(await call('POST', '/auth/select-company', body: {'identityToken': await identity(), 'companyId': companyId}))['token'] as String;
    final user = {'authorization': 'Bearer $token'};
    final groupId = json(await call('GET', '/me', auth: user))['groupId'] as String;
    for (final p in ['customers.read', 'customers.write', 'invoices.read', 'invoices.write', 'invoices.finalize']) {
      await call('PUT', '/groups/$groupId/permissions/$p', auth: user, body: {'granted': true});
    }
    return (user: user, groupId: groupId, companyId: companyId);
  }

  Future<Map<String, String>> agentFor(Map<String, String> user) async {
    await call('PUT', '/company/modules', auth: user, body: {'modules': ['aiAgents']});
    final created = await call('POST', '/agent-tokens', auth: user, body: {'label': 'Claude Desktop'});
    expect(created.statusCode, 201);
    final token = json(created)['token'] as String;
    expect(token, startsWith('wka_'));
    return {'authorization': 'Bearer $token'};
  }

  Map<String, Object?> draftBody(String customerId) => {
        'customerId': customerId,
        'items': [
          {'kind': 'hours', 'description': 'Montage', 'quantity': '2', 'unitPriceCents': 6500, 'vatRatePercent': 19},
        ],
      };

  test('Ohne Modul aiAgents keine Agent-Token; danach gleiche Fachaktionen wie in der App', () async {
    final a = await company('a@example.com', 'Firma A');
    expect((await call('POST', '/agent-tokens', auth: a.user, body: {'label': 'x'})).statusCode, 403);
    final agent = await agentFor(a.user);

    final customer = await call('POST', '/customers', auth: agent, body: {'name': 'Von KI angelegt'});
    expect(customer.statusCode, 201);
    final draft = await call('POST', '/documents', auth: agent, body: draftBody(json(customer)['id'] as String));
    expect(draft.statusCode, 201);
    expect((json(draft)['totals'] as Map)['grossCents'], 15470, reason: 'gleicher Rechenkern wie UI');
  });

  test('Agent erreicht nie Admin-Funktionen und kann keine Token/Freigaben verwalten', () async {
    final a = await company('a@example.com', 'Firma A');
    final agent = await agentFor(a.user);
    for (final (method, path, body) in [
      ('GET', '/memberships', null),
      ('PUT', '/company/modules', {'modules': <String>[]}),
      ('PUT', '/groups/${a.groupId}/permissions/invoices.payment', {'granted': true}),
      ('POST', '/invitations', {'email': 'x@example.com', 'groupId': a.groupId}),
      ('POST', '/agent-tokens', {'label': 'Kette'}),
      ('GET', '/audit', null),
    ]) {
      expect((await call(method, path, auth: agent, body: body)).statusCode, 403, reason: '$method $path');
    }
  });

  test('Finalisieren durch den Agenten: nur Freigabe-Anfrage; erst die Bestätigung des Nutzers finalisiert — genau einmal',
      () async {
    final a = await company('a@example.com', 'Firma A');
    final agent = await agentFor(a.user);
    final customer = json(await call('POST', '/customers', auth: agent, body: {'name': 'Meyer'}));
    final draft = json(await call('POST', '/documents', auth: agent, body: draftBody(customer['id'] as String)));

    final request = await call('POST', '/documents/${draft['id']}/finalize', auth: agent, body: {'version': 1});
    expect(request.statusCode, 202);
    final approvalId = json(request)['approvalId'] as String;
    expect(json(request)['summary'], contains('Rechnung für Meyer über 154,70 €'));
    expect(json(await call('GET', '/documents/${draft['id']}', auth: a.user))['status'], 'draft',
        reason: 'nichts passiert ohne Bestätigung');

    expect((await call('POST', '/approvals/$approvalId/confirm', auth: agent)).statusCode, 403,
        reason: 'Agent bestätigt sich nie selbst');
    final pending = json(await call('GET', '/approvals?status=pending', auth: a.user))['approvals'] as List;
    expect(pending.single['id'], approvalId);

    final confirmed = await call('POST', '/approvals/$approvalId/confirm', auth: a.user);
    expect(confirmed.statusCode, 200);
    expect(json(confirmed)['number'], matches(RegExp(r'^R-\d{5}$')));
    expect((await call('POST', '/approvals/$approvalId/confirm', auth: a.user)).statusCode, 409);

    final audit = (json(await call('GET', '/audit', auth: a.user))['entries'] as List).map((e) => (e as Map)['action']).toList();
    expect(audit, containsAll(['approval.request [agent]', 'document.create [agent]', 'approval.confirm', 'document.finalize']));
  });

  test('Bestätigung prüft Rechte neu; Ablehnen ändert nichts; Löschen braucht ebenfalls Freigabe', () async {
    final a = await company('a@example.com', 'Firma A');
    final agent = await agentFor(a.user);
    final customer = json(await call('POST', '/customers', auth: agent, body: {'name': 'Meyer'}));
    final draft = json(await call('POST', '/documents', auth: agent, body: draftBody(customer['id'] as String)));

    final finalizeRequest = json(await call('POST', '/documents/${draft['id']}/finalize', auth: agent, body: {'version': 1}));
    await call('PUT', '/groups/${a.groupId}/permissions/invoices.finalize', auth: a.user, body: {'granted': false});
    final confirm = await call('POST', '/approvals/${finalizeRequest['approvalId']}/confirm', auth: a.user);
    expect(confirm.statusCode, 403, reason: 'Recht inzwischen entzogen');
    expect(json(await call('GET', '/documents/${draft['id']}', auth: a.user))['status'], 'draft');

    final deleteRequest = await call('DELETE', '/documents/${draft['id']}', auth: agent);
    expect(deleteRequest.statusCode, 202);
    expect((await call('POST', '/approvals/${json(deleteRequest)['approvalId']}/reject', auth: a.user)).statusCode, 204);
    expect((await call('GET', '/documents/${draft['id']}', auth: a.user)).statusCode, 200, reason: 'nicht gelöscht');
  });

  test('Widerruf wirkt sofort: Token löschen, Modul aus, Mitgliedschaft deaktiviert; Firmenwechsel unmöglich', () async {
    final a = await company('a@example.com', 'Firma A');
    final b = await company('b@example.com', 'Firma B');
    final customerB = json(await call('POST', '/customers', auth: b.user, body: {'name': 'Geheim'}));

    var agent = await agentFor(a.user);
    expect((await call('GET', '/customers/${customerB['id']}', auth: agent)).statusCode, 404, reason: 'fremde Firma');
    expect(((json(await call('GET', '/customers?q=Geheim', auth: agent)))['customers'] as List), isEmpty);
    expect((await call('POST', '/auth/select-company', body: {'identityToken': agent['authorization']!.substring(7), 'companyId': b.companyId})).statusCode, 401);

    final tokens = json(await call('GET', '/agent-tokens', auth: a.user))['tokens'] as List;
    expect((await call('DELETE', '/agent-tokens/${tokens.single['id']}', auth: a.user)).statusCode, 204);
    expect((await call('GET', '/customers', auth: agent)).statusCode, 401);

    // Zweites Mitglied mit eigenem Agent-Token, dann Mitgliedschaft deaktivieren.
    await call('POST', '/auth/register', body: {'email': 'm@example.com', 'password': 'passwort-12345'});
    final membership = json(await call('POST', '/memberships', auth: a.user, body: {'email': 'm@example.com', 'groupId': a.groupId}));
    final memberIdentity = json(await call('POST', '/auth/login', body: {'email': 'm@example.com', 'password': 'passwort-12345'}))['identityToken'];
    final memberSession = {
      'authorization': 'Bearer ${json(await call('POST', '/auth/select-company', body: {'identityToken': memberIdentity, 'companyId': a.companyId}))['token']}',
    };
    final memberAgent = await agentFor(a.user).then((_) async {
      final created = await call('POST', '/agent-tokens', auth: memberSession, body: {'label': 'Handy'});
      return {'authorization': 'Bearer ${json(created)['token']}'};
    });
    expect((await call('GET', '/customers', auth: memberAgent)).statusCode, 200);
    await call('PATCH', '/memberships/${membership['id']}', auth: a.user, body: {'active': false});
    expect((await call('GET', '/customers', auth: memberAgent)).statusCode, 401, reason: 'Mitgliedschaft deaktiviert');

    agent = await agentFor(a.user);
    await call('PUT', '/company/modules', auth: a.user, body: {'modules': <String>[]});
    expect((await call('GET', '/customers', auth: agent)).statusCode, 401, reason: 'Modul aus');
  });
}
