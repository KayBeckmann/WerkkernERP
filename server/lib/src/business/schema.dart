import 'package:postgres/postgres.dart';

/// Schema der Fachdaten (B1 Punkt 3) — idempotent wie `ensureSchema`.
/// Jede Tabelle führt `company_id` direkt (ADR-0001 B0.5); Positionen
/// hängen über ihr Dokument an der Firma.
Future<void> ensureBusinessSchema(Session db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS customers (
      id TEXT PRIMARY KEY,
      company_id TEXT NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
      name TEXT NOT NULL,
      address TEXT, email TEXT, phone TEXT, vat_id TEXT, contact_person TEXT, notes TEXT,
      created_at TIMESTAMPTZ NOT NULL
    );
  ''');
  await db.execute('CREATE INDEX IF NOT EXISTS customers_company_idx ON customers (company_id)');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS articles (
      id TEXT PRIMARY KEY,
      company_id TEXT NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
      name TEXT NOT NULL,
      unit TEXT,
      sale_price_cents BIGINT,
      active BOOLEAN NOT NULL DEFAULT true,
      created_at TIMESTAMPTZ NOT NULL
    );
  ''');
  await db.execute('CREATE INDEX IF NOT EXISTS articles_company_idx ON articles (company_id)');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS documents (
      id TEXT PRIMARY KEY,
      company_id TEXT NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
      customer_id TEXT NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
      kind TEXT NOT NULL,
      status TEXT NOT NULL,
      number TEXT,
      number_year INTEGER,
      issue_date DATE NOT NULL,
      service_date DATE NOT NULL,
      payment_terms TEXT,
      notes TEXT,
      customer_snapshot_name TEXT,
      customer_snapshot_address TEXT,
      customer_snapshot_vat_id TEXT,
      company_snapshot_name TEXT,
      created_by_user_id TEXT NOT NULL REFERENCES app_users(id),
      created_at TIMESTAMPTZ NOT NULL,
      updated_at TIMESTAMPTZ NOT NULL,
      finalized_at TIMESTAMPTZ,
      version INTEGER NOT NULL,
      -- Letzte Verteidigungslinie gegen doppelte Nummern, falls je ein
      -- Codepfad die Transaktion umgehen sollte.
      UNIQUE (company_id, number)
    );
  ''');
  await db.execute('CREATE INDEX IF NOT EXISTS documents_company_idx ON documents (company_id)');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS document_items (
      id TEXT PRIMARY KEY,
      document_id TEXT NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
      kind TEXT NOT NULL,
      article_id TEXT REFERENCES articles(id) ON DELETE SET NULL,
      description TEXT NOT NULL,
      quantity TEXT NOT NULL,
      unit_price_cents BIGINT NOT NULL,
      vat_rate_percent DOUBLE PRECISION NOT NULL,
      unit TEXT,
      discount_percent DOUBLE PRECISION NOT NULL DEFAULT 0,
      group_label TEXT,
      sort_order INTEGER NOT NULL
    );
  ''');
  await db.execute('CREATE INDEX IF NOT EXISTS document_items_document_idx ON document_items (document_id)');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS number_sequences (
      company_id TEXT NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
      document_type TEXT NOT NULL,
      year INTEGER NOT NULL,
      last_number INTEGER NOT NULL,
      PRIMARY KEY (company_id, document_type, year)
    );
  ''');
}
