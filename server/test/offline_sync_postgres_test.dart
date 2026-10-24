@Tags(['postgres'])
library;

import 'package:postgres/postgres.dart';
import 'package:test/test.dart';
import 'package:werkkernerp_server/src/business/repository_postgres.dart';
import 'package:werkkernerp_server/src/repository_postgres.dart';

import 'offline_sync_test.dart';
import 'support/postgres_test_db.dart';

void main() {
  if (testDbConfig == null) {
    test('Postgres-Offline-Sync-Tests', () {}, skip: 'WERKKERN_TEST_DB nicht gesetzt');
    return;
  }
  Connection? admin;
  Pool<void>? pool;
  tearDownAll(() async {
    await pool?.close();
    await admin?.close();
  });
  runOfflineSyncTests(() async {
    admin ??= await openTestDb();
    await resetSchema(admin!);
    pool ??= openTestPool();
    return (PostgresPhaseBRepository(pool!), PostgresBusinessRepository(pool!));
  });
}
