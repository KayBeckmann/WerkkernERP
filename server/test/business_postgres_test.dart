@Tags(['postgres'])
library;

import 'package:postgres/postgres.dart';
import 'package:test/test.dart';
import 'package:werkkernerp_server/src/business/repository_postgres.dart';
import 'package:werkkernerp_server/src/repository_postgres.dart';

import 'business_router_test.dart';
import 'support/postgres_test_db.dart';

/// Fach-Suite gegen echtes Postgres — prüft insbesondere die
/// Finalisierungs-Transaktion (FOR UPDATE + Nummernkreis-UPSERT) unter
/// echter Nebenläufigkeit über einen Pool mit mehreren Verbindungen.
void main() {
  if (testDbConfig == null) {
    test('Postgres-Fachtests', () {}, skip: 'WERKKERN_TEST_DB nicht gesetzt');
    return;
  }

  Connection? admin;
  Pool<void>? pool;
  tearDownAll(() async {
    await pool?.close();
    await admin?.close();
  });

  runBusinessTests(() async {
    admin ??= await openTestDb();
    await resetSchema(admin!);
    pool ??= openTestPool();
    return (PostgresPhaseBRepository(pool!), PostgresBusinessRepository(pool!));
  });
}
