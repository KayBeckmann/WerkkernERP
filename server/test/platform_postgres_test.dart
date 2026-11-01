@Tags(['postgres'])
library;

import 'package:postgres/postgres.dart';
import 'package:test/test.dart';
import 'package:werkkernerp_server/src/repository_postgres.dart';

import 'platform_test.dart';
import 'support/postgres_test_db.dart';

void main() {
  if (testDbConfig == null) {
    test('Postgres-Plattform-Tests', () {}, skip: 'WERKKERN_TEST_DB nicht gesetzt');
    return;
  }
  Connection? admin;
  Pool<void>? pool;
  tearDownAll(() async {
    await pool?.close();
    await admin?.close();
  });
  runPlatformTests(() async {
    admin ??= await openTestDb();
    await resetSchema(admin!);
    pool ??= openTestPool();
    return PostgresPhaseBRepository(pool!);
  });
}
