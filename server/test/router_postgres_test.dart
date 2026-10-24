@Tags(['postgres'])
library;

import 'package:postgres/postgres.dart';
import 'package:test/test.dart';
import 'package:werkkernerp_server/src/repository_postgres.dart';

import 'router_test.dart';
import 'support/postgres_test_db.dart';

/// Dieselbe Router-Suite wie `router_test.dart`, aber gegen echtes
/// Postgres statt In-Memory — deckt SQL-Fehler, Typ-Mappings
/// (TIMESTAMPTZ, BOOLEAN) und Constraints ab, die ein In-Memory-Fake
/// nie sieht.
void main() {
  if (testDbConfig == null) {
    test('Postgres-Integrationstests', () {}, skip: 'WERKKERN_TEST_DB nicht gesetzt');
    return;
  }

  Connection? db;
  tearDownAll(() async => db?.close());

  runRouterTests(() async {
    db ??= await openTestDb();
    await resetSchema(db!);
    return PostgresPhaseBRepository(db!);
  });
}
