import 'dart:convert';
import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:werkkernerp_server/src/platform_admin_tool.dart';
import 'package:werkkernerp_server/src/repository_postgres.dart';

/// Superadmin-Zugang für das Plattform-Panel vergeben/entziehen — siehe
/// `lib/src/platform_admin_tool.dart`. Gleiche DB_*-Variablen wie der
/// Server, im laufenden Container:
///
/// ```bash
/// docker compose exec server /app/platform_admin grant kay@example.org
/// # neues Konto: Passwort über stdin
/// echo 'geheim123' | docker compose exec -T server /app/platform_admin grant kay@example.org
/// docker compose exec server /app/platform_admin revoke kay@example.org
/// ```
Future<void> main(List<String> args) async {
  if (args.length != 2 || !{'grant', 'revoke'}.contains(args[0])) {
    stderr.writeln('Aufruf: platform_admin grant|revoke <email>');
    exit(64);
  }
  String? password;
  if (args[0] == 'grant' && !stdin.hasTerminal) {
    final lines = await stdin.transform(utf8.decoder).transform(const LineSplitter()).take(1).toList();
    password = lines.isEmpty ? null : lines.first.trim();
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
    final repository = PostgresPhaseBRepository(db);
    stdout.writeln(args[0] == 'grant'
        ? await grantPlatformAdmin(repository, email: args[1], password: password)
        : await revokePlatformAdmin(repository, email: args[1]));
  } on StateError catch (e) {
    stderr.writeln(e.message);
    exitCode = 1;
  } finally {
    await db.close();
  }
}
