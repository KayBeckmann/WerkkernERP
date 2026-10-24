import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'package:werkkernerp_server/src/business/repository_postgres.dart';
import 'package:werkkernerp_server/src/db/migrations.dart';
import 'package:werkkernerp_server/src/repository_postgres.dart';
import 'package:werkkernerp_server/src/router.dart';

/// WerkkernERP Online-Multi-User-Server (Phase B, B1). Konfiguration
/// ausschließlich über Umgebungsvariablen — siehe `.env.example` im
/// Repo-Root und [[Decisions/ADR-0001-phase-b-architektur]] im Vault.
Future<void> main() async {
  final port = int.parse(Platform.environment['PORT'] ?? '8090');

  // Pool statt einzelner Verbindung: Finalisierung/Entwurfs-Update
  // laufen als Transaktion mit Zeilensperre und dürfen andere Requests
  // nicht blockieren.
  final db = Pool.withEndpoints(
    [
      Endpoint(
      host: Platform.environment['DB_HOST'] ?? 'localhost',
      port: int.parse(Platform.environment['DB_PORT'] ?? '5432'),
      database: Platform.environment['DB_NAME'] ?? 'werkkernerp_server',
      username: Platform.environment['DB_USER'] ?? 'werkkernerp_server',
      password: Platform.environment['DB_PASSWORD'] ?? 'werkkernerp_server',
      ),
    ],
    settings: PoolSettings(sslMode: SslMode.disable, maxConnectionCount: 10),
  );
  final schemaVersion = await migrate(db);

  final repository = PostgresPhaseBRepository(db);
  final router = PhaseBRouter(repository: repository, business: PostgresBusinessRepository(db));
  final handler = const Pipeline().addMiddleware(logRequests()).addHandler(router.handler.call);

  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  stdout.writeln('werkkernerp-server (Phase B) läuft auf Port ${server.port}, Schemastufe $schemaVersion');
}
