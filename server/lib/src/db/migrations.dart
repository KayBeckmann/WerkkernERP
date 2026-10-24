import 'package:postgres/postgres.dart';

import '../business/schema.dart';
import 'schema.dart';

/// Versionierte Schema-Migrationen — ersetzt das reine
/// `CREATE TABLE IF NOT EXISTS`-Bootstrap, das bestehenden Datenbanken
/// nie neue Spalten hinzufügen könnte. Gleiches Prinzip wie die
/// Offline-App (`MigrationStrategy.onUpgrade`): Stufen werden nur
/// angehängt, nie nachträglich geändert.
///
/// Stufe 1 und 2 sind die bisherigen idempotenten Bootstraps — eine
/// vor Einführung dieser Tabelle angelegte Datenbank durchläuft sie
/// gefahrlos erneut.
final List<Future<void> Function(Session db)> _steps = [
  ensureSchema, // 1: B1 Mitgliedschaften/Gruppen/Sitzungen/Einladungen
  ensureBusinessSchema, // 2: B1.3 Kunden/Artikel/Dokumente/Nummernkreise
  _step3CompanyProfileAuditSnapshots,
];

int get latestSchemaVersion => _steps.length;

/// Führt alle ausstehenden Stufen in **einer** Transaktion aus. Der
/// transaktionsgebundene Advisory-Lock verhindert, dass zwei parallel
/// startende Server-Instanzen dieselbe Stufe doppelt ausführen.
Future<int> migrate(SessionExecutor db) => db.runTx((tx) async {
      await tx.execute('SELECT pg_advisory_xact_lock(7340211)');
      await tx.execute('CREATE TABLE IF NOT EXISTS schema_migrations (version INTEGER PRIMARY KEY)');
      final result = await tx.execute('SELECT coalesce(max(version), 0) FROM schema_migrations');
      final current = result.first.first as int;
      for (var version = current + 1; version <= _steps.length; version++) {
        await _steps[version - 1](tx);
        await tx.execute(Sql.named('INSERT INTO schema_migrations (version) VALUES (@v)'), parameters: {'v': version});
      }
      return _steps.length;
    });

Future<void> _step3CompanyProfileAuditSnapshots(Session db) async {
  for (final column in ['address', 'tax_number', 'vat_id', 'iban', 'email', 'phone']) {
    await db.execute('ALTER TABLE companies ADD COLUMN IF NOT EXISTS $column TEXT');
  }
  for (final column in [
    'company_snapshot_address',
    'company_snapshot_tax_number',
    'company_snapshot_vat_id',
    'company_snapshot_iban',
  ]) {
    await db.execute('ALTER TABLE documents ADD COLUMN IF NOT EXISTS $column TEXT');
  }
  await db.execute('''
    CREATE TABLE IF NOT EXISTS audit_log (
      id BIGSERIAL PRIMARY KEY,
      company_id TEXT NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
      user_id TEXT REFERENCES app_users(id) ON DELETE SET NULL,
      action TEXT NOT NULL,
      entity_type TEXT NOT NULL,
      entity_id TEXT,
      at TIMESTAMPTZ NOT NULL
    );
  ''');
  await db.execute('CREATE INDEX IF NOT EXISTS audit_log_company_at_idx ON audit_log (company_id, at DESC)');
}
