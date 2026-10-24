import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:werkkernerp_server/src/admin_recovery.dart';
import 'package:werkkernerp_server/src/repository_postgres.dart';

/// Betreiber-Werkzeug für die Erstadmin-Recovery — siehe
/// `lib/src/admin_recovery.dart`. Gleiche DB_*-Umgebungsvariablen wie
/// der Server selbst, z. B. im laufenden Container:
///
/// ```bash
/// docker compose exec server /app/recover_admin <email> <companyId>
/// ```
Future<void> main(List<String> args) async {
  if (args.length != 2) {
    stderr.writeln('Aufruf: recover_admin <email> <companyId>');
    exit(64);
  }
  final db = await Connection.open(
    Endpoint(
      host: Platform.environment['DB_HOST'] ?? 'localhost',
      port: int.parse(Platform.environment['DB_PORT'] ?? '5432'),
      database: Platform.environment['DB_NAME'] ?? 'werkkernerp_server',
      username: Platform.environment['DB_USER'] ?? 'werkkernerp_server',
      password: Platform.environment['DB_PASSWORD'] ?? 'werkkernerp_server',
    ),
    settings: ConnectionSettings(sslMode: SslMode.disable),
  );
  try {
    stdout.writeln(await recoverCompanyAdmin(PostgresPhaseBRepository(db), email: args[0], companyId: args[1]));
  } on StateError catch (e) {
    stderr.writeln(e.message);
    exitCode = 1;
  } finally {
    await db.close();
  }
}
