import 'dart:async';
import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'package:werkkernerp_server/src/business/recurring_job.dart';
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
  final corsOrigins = (Platform.environment['CORS_ALLOWED_ORIGINS'] ?? '')
      .split(',')
      .map((o) => o.trim())
      .where((o) => o.isNotEmpty)
      .toSet();
  final business = PostgresBusinessRepository(db);
  final router = PhaseBRouter(
    repository: repository,
    business: business,
    corsAllowedOrigins: corsOrigins,
    trustForwardedFor: Platform.environment['TRUST_PROXY'] == 'true',
  );

  // Abgelaufenes regelmäßig aufräumen (Sitzungen, Login-Token,
  // Einladungen, Idempotenz-Einträge) — sonst wachsen die Tabellen
  // unbegrenzt.
  Future<void> purge() async {
    try {
      await repository.purgeExpired(DateTime.now().toUtc());
    } on Object catch (e) {
      stderr.writeln('Aufräumen fehlgeschlagen: $e');
    }
  }

  await purge();
  Timer.periodic(const Duration(hours: 1), (_) => purge());

  // Wiederkehrende Rechnungen (C11): fällige Entwürfe täglich anlegen —
  // stündlich geprüft, damit ein Neustart keinen Tag verpasst; jede
  // Periode wird atomar beansprucht (mehrere Instanzen sind unkritisch).
  Future<void> recurring() async {
    try {
      final created = await runRecurringInvoiceJob(repository: repository, business: business, now: DateTime.now().toUtc());
      if (created > 0) stdout.writeln('Wiederkehrende Rechnungen: $created Entwurf/Entwürfe angelegt');
    } on Object catch (e) {
      stderr.writeln('Wiederkehrende Rechnungen fehlgeschlagen: $e');
    }
  }

  await recurring();
  Timer.periodic(const Duration(hours: 1), (_) => recurring());
  final handler = const Pipeline().addMiddleware(logRequests()).addHandler(router.handler.call);

  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  stdout.writeln('werkkernerp-server (Phase B) läuft auf Port ${server.port}, Schemastufe $schemaVersion');
}
