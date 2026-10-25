import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';
import 'package:werkkern_client/werkkern_client.dart';
import 'package:werkkernerp_server/src/business/repository.dart';
import 'package:werkkernerp_server/src/business/repository_memory.dart';
import 'package:werkkernerp_server/src/business/repository_postgres.dart';
import 'package:werkkernerp_server/src/repository.dart';
import 'package:werkkernerp_server/src/repository_memory.dart';
import 'package:werkkernerp_server/src/repository_postgres.dart';
import 'package:werkkernerp_server/src/router.dart';

import 'postgres_test_db.dart';
import 'starter_groups.dart';

typedef RepositoryFactory = Future<(PhaseBRepository, BusinessRepository)> Function();

Future<(PhaseBRepository, BusinessRepository)> inMemoryRepositories() async =>
    (InMemoryPhaseBRepository(), InMemoryBusinessRepository());

/// Führt [suite] gegen eine echte Postgres-Instanz aus (oder überspringt
/// sie ohne `WERKKERN_TEST_DB`) — jeder Test auf leerem Schema.
void runOnPostgres(String name, void Function(RepositoryFactory create) suite) {
  if (testDbConfig == null) {
    test(name, () {}, skip: 'WERKKERN_TEST_DB nicht gesetzt');
    return;
  }
  Connection? admin;
  Pool<void>? pool;
  tearDownAll(() async {
    await pool?.close();
    await admin?.close();
  });
  suite(() async {
    admin ??= await openTestDb();
    await resetSchema(admin!);
    pool ??= openTestPool();
    return (PostgresPhaseBRepository(pool!), PostgresBusinessRepository(pool!));
  });
}

/// Laufender Server + Firma mit genau den angegebenen Rechten/Modulen.
class ModuleHarness {
  ModuleHarness(this.create);
  final RepositoryFactory create;

  late HttpServer server;
  late Uri base;
  late PhaseBRepository repository;
  late BusinessRepository business;

  void install() {
    setUp(() async {
      final (r, b) = await create();
      repository = r;
      business = b;
      server = await shelf_io.serve(
        PhaseBRouter(repository: repository, business: business).handler.call,
        InternetAddress.loopbackIPv4,
        0,
      );
      base = Uri.parse('http://127.0.0.1:${server.port}');
    });
    tearDown(() => server.close(force: true));
  }

  Future<CompanyClient> company(String email, {required List<String> permissions, Set<String> modules = const {}}) async {
    final client = WerkkernApiClient(baseUrl: base);
    await client.register(email, 'passwort-12345');
    final companyId = await client.createCompany((await client.login(email, 'passwort-12345')).identityToken, 'Firma $email');
    await client.selectCompany((await client.login(email, 'passwort-12345')).identityToken, companyId);
    await clearGroupPermissions(client);
    final groups = await client.groups();
    final own = groups.firstWhere((g) => g.name == 'Projektleiter').id;
    for (final p in permissions) {
      await client.setGroupPermission(own, p, granted: true);
    }
    if (modules.isNotEmpty) await client.setModules(modules);
    return CompanyClient(client, companyId, own, {for (final g in groups) g.name: g.id});
  }

  /// Zweites Konto in derselben Firma (über Einladung) in [groupName].
  Future<WerkkernApiClient> member(CompanyClient company, String email, {String groupName = 'Monteur'}) async {
    final token = await company.client.createInvitation(email, company.groups[groupName]!);
    final client = WerkkernApiClient(baseUrl: base);
    await client.acceptInvitation(token, 'passwort-12345');
    await client.selectCompany((await client.login(email, 'passwort-12345')).identityToken, company.companyId);
    return client;
  }
}

class CompanyClient {
  CompanyClient(this.client, this.companyId, this.ownGroup, this.groups);
  final WerkkernApiClient client;
  final String companyId;
  final String ownGroup;
  final Map<String, String> groups;

  Future<Map<String, Object?>> get(String path, {Map<String, String>? query}) async =>
      await client.request('GET', path, query: query) as Map<String, Object?>;
  Future<Map<String, Object?>> post(String path, [Map<String, Object?> body = const {}]) async =>
      await client.request('POST', path, body: body) as Map<String, Object?>;
  Future<Map<String, Object?>> put(String path, Map<String, Object?> body) async =>
      await client.request('PUT', path, body: body) as Map<String, Object?>;
  Future<void> delete(String path) => client.request('DELETE', path);
}

Matcher throwsStatus(int status) =>
    throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', status));
