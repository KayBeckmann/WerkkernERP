import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/data/database/tables.dart';
import 'package:werkkernerp/data/repositories/company_repository.dart';
import 'package:werkkernerp/data/repositories/customer_repository.dart';
import 'package:werkkernerp/data/repositories/invoice_repository.dart';
import 'package:werkkernerp/data/repositories/number_sequence_repository.dart';

/// Erste echte Schema-Migration dieser App (A5: v1→v2, Angebot/Auftrag).
/// Statt das Spaltentyp-/Datumsspeicherformat von drifts NativeDatabase
/// zu raten, wird eine ECHTE v2-Datenbank von drift selbst erzeugt und
/// dann über `ALTER TABLE ... DROP COLUMN` mechanisch auf den exakten
/// v1-Zustand zurückgebaut (nur die drei neuen Spalten entfernt, alles
/// andere bleibt drifts eigene, authentische DDL). Erst danach wird die
/// Datei neu geöffnet — das triggert drifts reguläre Migrationslogik
/// genauso, wie es ein echtes App-Update auf einem Bestandsgerät täte.
void main() {
  late Directory tempDir;
  late String dbPath;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('werkkernerp_migration_test_');
    dbPath = p.join(tempDir.path, 'test.sqlite');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test(
    'Migration v1→v2 (A5): Bestandsdaten bekommen automatisch kind=invoice, '
    'quotesEnabled=false, ordersEnabled=false — ohne Datenverlust',
    () async {
      // Schritt 1: Eine echte v2-Datenbank mit Nutzdaten anlegen (reales
      // onCreate, drifts eigene DDL).
      final file = File(dbPath);
      var db = AppDatabase.forTesting(
        NativeDatabase(file, setup: (raw) => raw.execute('PRAGMA foreign_keys = ON;')),
      );
      final companyRepo = CompanyRepository(db);
      final customerRepo = CustomerRepository(db);
      final invoiceRepo = InvoiceRepository(db, NumberSequenceRepository(db));

      final company = await companyRepo.create(name: 'Migrations-Testfirma');
      final customer = await customerRepo.create(companyId: company.id, name: 'Bestandskunde');
      final invoice = await invoiceRepo.createDraft(
        companyId: company.id,
        customerId: customer.id,
        issueDate: DateTime(2026, 1, 10),
        serviceDate: DateTime(2026, 1, 10),
        items: const [],
      );
      await db.close();

      // Schritt 2: Mechanisch auf v1 zurückbauen — nur die drei neuen
      // Spalten entfernen, PRAGMA user_version auf 1 setzen. Das ist
      // byte-genau das, was ein echtes v1-Bestandsgerät auf der Platte
      // hätte (keine Annahme über Spaltenformate nötig, da die restliche
      // DDL drifts eigene ist).
      final raw = sqlite3.open(dbPath);
      raw.execute('ALTER TABLE invoices DROP COLUMN kind;');
      raw.execute('ALTER TABLE companies DROP COLUMN quotes_enabled;');
      raw.execute('ALTER TABLE companies DROP COLUMN orders_enabled;');
      raw.execute('PRAGMA user_version = 1;');
      raw.close();

      // Schritt 3: Neu öffnen — drift erkennt user_version=1 < schemaVersion=2
      // und muss automatisch die onUpgrade-Stufe durchlaufen, exakt wie
      // bei einem echten App-Update.
      db = AppDatabase.forTesting(
        NativeDatabase(file, setup: (r) => r.execute('PRAGMA foreign_keys = ON;')),
      );
      try {
        final migratedCompany = await (db.select(db.companies)..where((c) => c.id.equals(company.id)))
            .getSingle();
        expect(migratedCompany.quotesEnabled, isFalse);
        expect(migratedCompany.ordersEnabled, isFalse);
        expect(migratedCompany.name, 'Migrations-Testfirma', reason: 'Bestandsdaten dürfen nicht verändert werden');

        final migratedInvoice =
            await (db.select(db.invoices)..where((i) => i.id.equals(invoice.id))).getSingle();
        expect(migratedInvoice.kind, DocumentKind.invoice);
        expect(migratedInvoice.customerId, customer.id, reason: 'Bestandsdaten dürfen nicht verändert werden');
      } finally {
        await db.close();
      }
    },
  );
}
