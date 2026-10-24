import 'package:postgres/postgres.dart';

/// Idempotentes Schema-Bootstrap (gleiches Prinzip wie LibreECAD M1,
/// siehe ADR-0001) — für B1 ohne Bestandsdaten ausreichend; ein
/// echtes Migrationswerkzeug kommt vor B2/Produktivbetrieb.
Future<void> ensureSchema(Connection db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS app_users (
      id TEXT PRIMARY KEY,
      email TEXT NOT NULL UNIQUE,
      password_hash TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS companies (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      enabled_modules TEXT NOT NULL DEFAULT '',
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS groups (
      id TEXT PRIMARY KEY,
      company_id TEXT NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
      name TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS memberships (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
      company_id TEXT NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
      group_id TEXT NOT NULL REFERENCES groups(id) ON DELETE RESTRICT,
      is_admin BOOLEAN NOT NULL DEFAULT false,
      active BOOLEAN NOT NULL DEFAULT true,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      UNIQUE (user_id, company_id)
    );
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS group_permissions (
      group_id TEXT NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
      permission TEXT NOT NULL,
      PRIMARY KEY (group_id, permission)
    );
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS membership_permission_overrides (
      membership_id TEXT NOT NULL REFERENCES memberships(id) ON DELETE CASCADE,
      permission TEXT NOT NULL,
      allowed BOOLEAN NOT NULL,
      PRIMARY KEY (membership_id, permission)
    );
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS pending_logins (
      token_hash TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
      expires_at TIMESTAMPTZ NOT NULL
    );
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS company_sessions (
      token_hash TEXT PRIMARY KEY,
      membership_id TEXT NOT NULL REFERENCES memberships(id) ON DELETE CASCADE,
      user_id TEXT NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
      company_id TEXT NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
      created_at TIMESTAMPTZ NOT NULL,
      expires_at TIMESTAMPTZ NOT NULL
    );
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS invitations (
      token_hash TEXT PRIMARY KEY,
      company_id TEXT NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
      email TEXT NOT NULL,
      group_id TEXT NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
      invited_by_user_id TEXT NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
      expires_at TIMESTAMPTZ NOT NULL
    );
  ''');
}
