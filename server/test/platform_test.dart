import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';

import 'package:werkkernerp_server/src/platform_admin_tool.dart';
import 'package:werkkernerp_server/src/repository.dart';
import 'package:werkkernerp_server/src/repository_memory.dart';
import 'package:werkkernerp_server/src/router.dart';

void main() => runPlatformTests(() async => InMemoryPhaseBRepository());

/// Superadmin-Panel (SaaS): Plattform-Login, Firmenliste, Abo, Sperre.
/// Gleiche Suite gegen Postgres in `platform_postgres_test.dart`.
void runPlatformTests(Future<PhaseBRepository> Function() createRepository) {
  late PhaseBRepository repository;
  late HttpServer server;
  late Uri baseUrl;

  setUp(() async {
    repository = await createRepository();
    server = await shelf_io.serve(PhaseBRouter(repository: repository).handler.call, InternetAddress.loopbackIPv4, 0);
    baseUrl = Uri.parse('http://127.0.0.1:${server.port}');
  });
  tearDown(() => server.close(force: true));

  Future<http.Response> post(String path, Map<String, Object?> body, [String? token]) => http.post(
        baseUrl.resolve(path),
        headers: {if (token != null) 'authorization': 'Bearer $token'},
        body: jsonEncode(body),
      );
  Future<http.Response> get(String path, [String? token]) =>
      http.get(baseUrl.resolve(path), headers: {if (token != null) 'authorization': 'Bearer $token'});
  Map<String, Object?> json(http.Response r) => jsonDecode(r.body) as Map<String, Object?>;

  /// Kunde mit eigener Firma; liefert (companyId, Sitzungs-Token).
  Future<(String, String)> customer(String email, String companyName) async {
    expect((await post('/auth/register', {'email': email, 'password': 'passwort-123'})).statusCode, 201);
    final identity = json(await post('/auth/login', {'email': email, 'password': 'passwort-123'}))['identityToken'];
    final companyId = json(await post('/companies', {'identityToken': identity, 'name': companyName}))['companyId'] as String;
    final identity2 = json(await post('/auth/login', {'email': email, 'password': 'passwort-123'}))['identityToken'];
    final token = json(await post('/auth/select-company', {'identityToken': identity2, 'companyId': companyId}))['token'] as String;
    return (companyId, token);
  }

  Future<String> platformLogin() async {
    await grantPlatformAdmin(repository, email: 'betreiber@example.org', password: 'betreiber-123');
    final response = await post('/platform/login', {'email': 'betreiber@example.org', 'password': 'betreiber-123'});
    expect(response.statusCode, 200);
    return json(response)['token'] as String;
  }

  test('Nur Superadmins kommen ins Panel; Firmen-Sitzungen gelten dort nicht', () async {
    final (_, companyToken) = await customer('kunde@example.org', 'Elektro Kunde');
    final denied = await post('/platform/login', {'email': 'kunde@example.org', 'password': 'passwort-123'});
    expect(denied.statusCode, 401, reason: 'gleiche Antwort wie falsches Passwort');
    expect((await get('/platform/companies', companyToken)).statusCode, 401);
    expect((await get('/platform/companies')).statusCode, 401);

    final token = await platformLogin();
    expect(json(await get('/platform/me', token))['email'], 'betreiber@example.org');
    // Superadmin-Token taugt nicht als Firmensitzung.
    expect((await get('/me', token)).statusCode, 401);

    await revokePlatformAdmin(repository, email: 'betreiber@example.org');
    expect((await get('/platform/companies', token)).statusCode, 401, reason: 'Entzug wirkt sofort');
  });

  test('Firmenliste zeigt Mitglieder, Admins und Abo — keine Fachdaten', () async {
    final (companyId, _) = await customer('kunde@example.org', 'Elektro Kunde');
    final token = await platformLogin();
    final companies = (json(await get('/platform/companies', token))['companies'] as List).cast<Map<String, Object?>>();
    expect(companies, hasLength(1));
    final c = companies.single;
    expect(c['id'], companyId);
    expect(c['name'], 'Elektro Kunde');
    expect(c['activeMembers'], 1);
    expect(c['adminEmails'], ['kunde@example.org']);
    expect(c['suspended'], isFalse);
    expect(c['overdue'], isFalse);
    expect(c.keys, isNot(contains('customers')));

    final billing = await http.put(
      baseUrl.resolve('/platform/companies/$companyId/billing'),
      headers: {'authorization': 'Bearer $token'},
      body: jsonEncode({'plan': 'Basis', 'paidUntil': '2020-01-31', 'note': 'Rechnung 17 offen'}),
    );
    expect(billing.statusCode, 200);
    expect(json(billing)['paidUntil'], '2020-01-31');
    expect(json(billing)['overdue'], isTrue);
    expect(json(billing)['plan'], 'Basis');

    final bad = await http.put(
      baseUrl.resolve('/platform/companies/$companyId/billing'),
      headers: {'authorization': 'Bearer $token'},
      body: jsonEncode({'paidUntil': '31.01.2020'}),
    );
    expect(bad.statusCode, 400);
    expect((await post('/platform/companies/unbekannt/suspend', {}, token)).statusCode, 404);
  });

  test('Sperre: laufende Sitzung endet, Login zeigt gesperrt, Firmenwahl scheitert; Entsperren hebt das auf', () async {
    final (companyId, companyToken) = await customer('kunde@example.org', 'Elektro Kunde');
    final token = await platformLogin();
    expect((await get('/me', companyToken)).statusCode, 200);

    final suspended = await post('/platform/companies/$companyId/suspend', {'reason': 'Abo seit 2 Monaten offen'}, token);
    expect(suspended.statusCode, 200);
    expect(json(suspended)['suspended'], isTrue);
    expect(json(suspended)['suspendReason'], 'Abo seit 2 Monaten offen');
    expect((await get('/me', companyToken)).statusCode, 401, reason: 'Sitzung beendet');

    final login = json(await post('/auth/login', {'email': 'kunde@example.org', 'password': 'passwort-123'}));
    final membership = (login['memberships'] as List).single as Map<String, Object?>;
    expect(membership['suspended'], isTrue);
    final select = await post('/auth/select-company', {'identityToken': login['identityToken'], 'companyId': companyId});
    expect(select.statusCode, 403);
    expect(json(select)['error'], contains('gesperrt'));
    expect(json(select)['error'], isNot(contains('Abo seit')), reason: 'Grund bleibt intern');

    final audit = (await repository.listAudit(companyId)).map((e) => e.action);
    expect(audit, contains('platform.suspend'));

    expect(json(await post('/platform/companies/$companyId/resume', {}, token))['suspended'], isFalse);
    final again = json(await post('/auth/login', {'email': 'kunde@example.org', 'password': 'passwort-123'}));
    expect(((again['memberships'] as List).single as Map).containsKey('suspended'), isFalse);
    final reselect = await post('/auth/select-company', {'identityToken': again['identityToken'], 'companyId': companyId});
    expect(reselect.statusCode, 200);
  });

  test('Firmenwechsel in eine gesperrte Firma scheitert', () async {
    final (_, tokenA) = await customer('kunde@example.org', 'Firma A');
    final identity = json(await post('/auth/login', {'email': 'kunde@example.org', 'password': 'passwort-123'}))['identityToken'];
    final companyB = json(await post('/companies', {'identityToken': identity, 'name': 'Firma B'}))['companyId'] as String;
    final token = await platformLogin();
    await post('/platform/companies/$companyB/suspend', {}, token);
    final switched = await post('/auth/switch-company', {'companyId': companyB}, tokenA);
    expect(switched.statusCode, 403);
    expect((await get('/me', tokenA)).statusCode, 200, reason: 'andere Firma bleibt nutzbar');
  });

  test('Superadmin-Konto über das Werkzeug anlegen braucht ein Passwort', () async {
    expect(() => grantPlatformAdmin(repository, email: 'neu@example.org'), throwsStateError);
    expect(await grantPlatformAdmin(repository, email: 'neu@example.org', password: 'lang-genug-1'), contains('angelegt'));
  });
}
