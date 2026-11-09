@Tags(['postgres'])
library;

import 'package:postgres/postgres.dart';
import 'package:test/test.dart';
import 'package:werkkernerp_server/src/business/schema.dart';
import 'package:werkkernerp_server/src/db/migrations.dart';
import 'package:werkkernerp_server/src/db/schema.dart';

import 'support/postgres_test_db.dart';

void main() {
  if (testDbConfig == null) {
    test('Postgres-Migrationstests', () {}, skip: 'WERKKERN_TEST_DB nicht gesetzt');
    return;
  }

  late Connection db;
  setUp(() async {
    db = await openTestDb();
    await db.execute('DROP SCHEMA public CASCADE');
    await db.execute('CREATE SCHEMA public');
  });
  tearDown(() => db.close());

  Future<Set<String>> columns(String table) async {
    final result = await db.execute(
      Sql.named('SELECT column_name FROM information_schema.columns WHERE table_name = @t'),
      parameters: {'t': table},
    );
    return {for (final r in result) r.first as String};
  }

  test('Bestandsdatenbank von vor der Migrationstabelle bekommt die neuen Spalten, Daten bleiben', () async {
    // Zustand eines Servers vor Einführung der Migrationen: nur die
    // beiden idempotenten Bootstraps, keine schema_migrations-Tabelle.
    await ensureSchema(db);
    await ensureBusinessSchema(db);
    await db.execute("INSERT INTO companies (id, name) VALUES ('c1', 'Bestandsfirma')");
    expect(await columns('companies'), isNot(contains('tax_number')));

    expect(await migrate(db), latestSchemaVersion);
    expect(await columns('companies'), containsAll(['tax_number', 'iban']));
    expect(await columns('documents'), contains('company_snapshot_address'));
    expect(await columns('audit_log'), contains('action'));
    final name = await db.execute("SELECT name FROM companies WHERE id = 'c1'");
    expect(name.first.first, 'Bestandsfirma');
  });

  test('Bisheriger Ansprechpartner wird zur ersten Kontaktperson (Stufe 22)', () async {
    await ensureSchema(db);
    await ensureBusinessSchema(db);
    await db.execute("INSERT INTO companies (id, name) VALUES ('c1', 'Bestandsfirma')");
    await db.execute(
      "INSERT INTO customers (id, company_id, name, contact_person, created_at) VALUES "
      "('k1', 'c1', 'Remondis', ' Vincent ', now()), ('k2', 'c1', 'Ohne', '  ', now()), ('k3', 'c1', 'Leer', NULL, now())",
    );
    await migrate(db);
    final contacts = await db.execute('SELECT customer_id, name, company_id FROM customer_contacts');
    expect([for (final r in contacts) (r[0], r[1], r[2])], [('k1', 'Vincent', 'c1')]);
    final remaining = await db.execute('SELECT count(*) FROM customers WHERE contact_person IS NOT NULL');
    expect(remaining.first.first, 0);
    expect(await columns('customers'), contains('invoice_email'));
    expect(await columns('documents'), contains('contact_id'));
  });

  test('Erneuter Lauf ist ein No-op; parallele Läufe (zwei Instanzen) kollidieren nicht', () async {
    await migrate(db);
    final other = await openTestDb();
    final pool = openTestPool();
    try {
      await Future.wait([migrate(db), migrate(other), migrate(pool)]);
      final versions = await db.execute('SELECT version FROM schema_migrations ORDER BY version');
      expect([for (final r in versions) r.first], [for (var v = 1; v <= latestSchemaVersion; v++) v]);
    } finally {
      await other.close();
      await pool.close();
    }
  });
}
