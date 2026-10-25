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
  _step4ConversionAndPayment,
  _step5IdempotencyKeys,
  _step6AgentTokensApprovals,
  _step7TimeTracking,
  _step8Projects,
  _step9AdvanceFixedPrice,
  _step10DocumentTextsSmallBusiness,
  _step11SuppliersArticleGroups,
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

Future<void> _step4ConversionAndPayment(Session db) async {
  await db.execute(
    'ALTER TABLE documents ADD COLUMN IF NOT EXISTS converted_from_id TEXT REFERENCES documents(id) ON DELETE SET NULL',
  );
  await db.execute("ALTER TABLE documents ADD COLUMN IF NOT EXISTS payment_status TEXT NOT NULL DEFAULT 'open'");
  await db.execute('ALTER TABLE documents ADD COLUMN IF NOT EXISTS paid_at TIMESTAMPTZ');
  await db.execute('ALTER TABLE documents ADD COLUMN IF NOT EXISTS due_date DATE');
}

/// B2: Antworten auf Schreibaufrufe mit `Idempotency-Key` — eine
/// erneut gesendete Offline-Änderung (Antwort ging verloren) liefert
/// die gespeicherte Antwort statt ein zweites Mal zu wirken.
Future<void> _step5IdempotencyKeys(Session db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS idempotency_keys (
      company_id TEXT NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
      user_id TEXT NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
      key TEXT NOT NULL,
      request_fingerprint TEXT NOT NULL,
      status INTEGER NOT NULL,
      body TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL,
      PRIMARY KEY (company_id, user_id, key)
    );
  ''');
}

/// C8: Agent-Token (LLM/MCP) und Freigaben irreversibler Aktionen.
Future<void> _step6AgentTokensApprovals(Session db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS agent_tokens (
      id TEXT PRIMARY KEY,
      token_hash TEXT NOT NULL UNIQUE,
      membership_id TEXT NOT NULL REFERENCES memberships(id) ON DELETE CASCADE,
      user_id TEXT NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
      company_id TEXT NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
      label TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL,
      last_used_at TIMESTAMPTZ
    );
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS pending_approvals (
      id TEXT PRIMARY KEY,
      company_id TEXT NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
      user_id TEXT NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
      agent_token_id TEXT NOT NULL,
      method TEXT NOT NULL,
      path TEXT NOT NULL,
      body TEXT NOT NULL,
      summary TEXT NOT NULL,
      status TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL,
      decided_at TIMESTAMPTZ,
      result_status INTEGER,
      result_body TEXT
    );
  ''');
  await db.execute('CREATE INDEX IF NOT EXISTS pending_approvals_user_idx ON pending_approvals (company_id, user_id, status)');
}

/// C3 online: Zeiterfassung mit echten Benutzerkonten und Stundensatz je
/// Mitgliedschaft (beim Buchen eingefroren).
Future<void> _step7TimeTracking(Session db) async {
  await db.execute('ALTER TABLE memberships ADD COLUMN IF NOT EXISTS hourly_cost_cents BIGINT');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS time_entries (
      id TEXT PRIMARY KEY,
      company_id TEXT NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
      user_id TEXT NOT NULL REFERENCES app_users(id),
      document_id TEXT REFERENCES documents(id) ON DELETE RESTRICT,
      work_date DATE NOT NULL,
      hours TEXT NOT NULL,
      note TEXT,
      hourly_cost_cents BIGINT,
      created_at TIMESTAMPTZ NOT NULL,
      updated_at TIMESTAMPTZ NOT NULL
    );
  ''');
  await db.execute('CREATE INDEX IF NOT EXISTS time_entries_company_idx ON time_entries (company_id, work_date)');
  await db.execute('CREATE INDEX IF NOT EXISTS time_entries_document_idx ON time_entries (document_id)');
}

/// C1/C2 online: Projekte mit eingefrorener Projektnummer (PP je Firma
/// und Gründungsjahr), Zuordnung von Dokumenten und Zeitbuchungen.
Future<void> _step8Projects(Session db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS projects (
      id TEXT PRIMARY KEY,
      company_id TEXT NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
      name TEXT NOT NULL,
      customer_id TEXT REFERENCES customers(id) ON DELETE SET NULL,
      status TEXT NOT NULL,
      founding_year INTEGER NOT NULL,
      project_number INTEGER NOT NULL,
      created_at TIMESTAMPTZ NOT NULL,
      UNIQUE (company_id, founding_year, project_number)
    );
  ''');
  await db.execute('CREATE INDEX IF NOT EXISTS projects_company_idx ON projects (company_id)');
  await db.execute(
    'ALTER TABLE documents ADD COLUMN IF NOT EXISTS project_id TEXT REFERENCES projects(id) ON DELETE RESTRICT',
  );
  await db.execute(
    'ALTER TABLE time_entries ADD COLUMN IF NOT EXISTS project_id TEXT REFERENCES projects(id) ON DELETE RESTRICT',
  );
}

/// C13 Abschlagsrechnung + C3.2 Festpreis-Kennzeichen online.
Future<void> _step9AdvanceFixedPrice(Session db) async {
  await db.execute('ALTER TABLE documents ADD COLUMN IF NOT EXISTS is_advance_payment BOOLEAN NOT NULL DEFAULT false');
  await db.execute('ALTER TABLE documents ADD COLUMN IF NOT EXISTS is_fixed_price BOOLEAN NOT NULL DEFAULT false');
}

/// Dokumenttexte je Art, Fußzeile, Kleinunternehmerregelung (§ 19 UStG)
/// — und deren Schnappschuss im finalisierten Dokument.
Future<void> _step10DocumentTextsSmallBusiness(Session db) async {
  await db.execute("ALTER TABLE companies ADD COLUMN IF NOT EXISTS document_texts TEXT NOT NULL DEFAULT '{}'");
  await db.execute('ALTER TABLE companies ADD COLUMN IF NOT EXISTS pdf_footer_text TEXT');
  await db.execute('ALTER TABLE companies ADD COLUMN IF NOT EXISTS small_business_exempt BOOLEAN NOT NULL DEFAULT false');
  for (final column in ['intro_text_snapshot', 'closing_text_snapshot', 'footer_text_snapshot']) {
    await db.execute('ALTER TABLE documents ADD COLUMN IF NOT EXISTS $column TEXT');
  }
  await db.execute(
    'ALTER TABLE documents ADD COLUMN IF NOT EXISTS small_business_exempt_snapshot BOOLEAN NOT NULL DEFAULT false',
  );
}

/// A1 online: Lieferanten, Artikelgruppen, Einkaufspreise je Lieferant;
/// am Artikel Gruppe und Standardlieferant (beide wie offline `setNull`).
Future<void> _step11SuppliersArticleGroups(Session db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS suppliers (
      id TEXT PRIMARY KEY,
      company_id TEXT NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
      name TEXT NOT NULL,
      address TEXT, email TEXT, phone TEXT, vat_id TEXT, contact_person TEXT, notes TEXT,
      minimum_order_quantity TEXT, delivery_terms TEXT,
      created_at TIMESTAMPTZ NOT NULL
    );
  ''');
  await db.execute('CREATE INDEX IF NOT EXISTS suppliers_company_idx ON suppliers (company_id)');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS article_groups (
      id TEXT PRIMARY KEY,
      company_id TEXT NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
      name TEXT NOT NULL,
      markup_percent DOUBLE PRECISION NOT NULL,
      created_at TIMESTAMPTZ NOT NULL
    );
  ''');
  await db.execute('CREATE INDEX IF NOT EXISTS article_groups_company_idx ON article_groups (company_id)');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS article_supplier_prices (
      company_id TEXT NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
      article_id TEXT NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
      supplier_id TEXT NOT NULL REFERENCES suppliers(id) ON DELETE CASCADE,
      purchase_price_cents BIGINT NOT NULL,
      PRIMARY KEY (article_id, supplier_id)
    );
  ''');
  await db.execute('CREATE INDEX IF NOT EXISTS article_prices_company_idx ON article_supplier_prices (company_id)');
  await db.execute(
    'ALTER TABLE articles ADD COLUMN IF NOT EXISTS article_group_id TEXT REFERENCES article_groups(id) ON DELETE SET NULL',
  );
  await db.execute(
    'ALTER TABLE articles ADD COLUMN IF NOT EXISTS default_supplier_id TEXT REFERENCES suppliers(id) ON DELETE SET NULL',
  );
}
