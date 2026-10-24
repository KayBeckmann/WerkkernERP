import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:werkkernerp_server/src/db/schema.dart';

/// Echte Postgres-Instanz für Integrationstests — nur wenn
/// `WERKKERN_TEST_DB` gesetzt ist (Format `host:port:db:user:password`),
/// sonst werden die Postgres-Suiten übersprungen. Lokal z. B.:
///
/// ```bash
/// docker run -d --rm --name werkkern-test-pg -e POSTGRES_PASSWORD=test \
///   -e POSTGRES_USER=test -e POSTGRES_DB=test -p 127.0.0.1:55432:5432 postgres:16-alpine
/// WERKKERN_TEST_DB=localhost:55432:test:test:test dart test
/// ```
String? get testDbConfig => Platform.environment['WERKKERN_TEST_DB'];

Future<Connection> openTestDb() async {
  final parts = testDbConfig!.split(':');
  return Connection.open(
    Endpoint(host: parts[0], port: int.parse(parts[1]), database: parts[2], username: parts[3], password: parts[4]),
    settings: ConnectionSettings(sslMode: SslMode.disable),
  );
}

/// Leert das komplette Schema und legt es neu an — jeder Test startet
/// auf einer leeren Datenbank, genau wie mit dem In-Memory-Repository.
Future<void> resetSchema(Connection db) async {
  await db.execute('DROP SCHEMA public CASCADE');
  await db.execute('CREATE SCHEMA public');
  await ensureSchema(db);
}
