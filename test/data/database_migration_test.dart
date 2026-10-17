import 'dart:io';

import 'package:decimal/decimal.dart';
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

/// Migrationen dieser App (v1→v2 A5: Angebot/Auftrag; v2→v3: erweiterte
/// Kunden-/Lieferantenfelder; v3→v4: anpassbare PDF-Texte; v4→v5:
/// Lieferschein + Dokumentumwandlung; v5→v6: Einheit + Rabatt pro
/// Position; v6→v7: PDF-Texte pro Dokumentart; v7→v8: C10
/// Proforma-Rechnungen; v8→v9: C1 Projekte; v9→v10: C6 Fuhrpark; v10→v11:
/// PDF-Text-Schnappschuss; v11→v12: C11 Wiederkehrende Rechnungen;
/// v12→v13: C13 Abschlagsrechnungen).
/// Statt das Spaltentyp-/
/// Datumsspeicherformat von drifts NativeDatabase zu raten,
/// wird eine ECHTE aktuelle Datenbank von drift selbst erzeugt und
/// dann über `ALTER TABLE ... DROP COLUMN` mechanisch auf den exakten
/// v1-Zustand zurückgebaut (nur die seither hinzugekommenen Spalten
/// entfernt, alles andere bleibt drifts eigene, authentische DDL).
/// Erst danach wird die Datei neu geöffnet — das triggert drifts
/// reguläre Migrationslogik durch ALLE onUpgrade-Stufen genauso, wie
/// es ein echtes App-Update über mehrere Versionen hinweg täte.
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
    'Migration v1→v13 (A5 + erweiterte Kunden-/Lieferantenfelder + PDF-Texte + Lieferschein + '
    'Einheit/Rabatt pro Position + PDF-Texte pro Dokumentart + C10 Proforma-Rechnungen + '
    'C1 Projekte + C6 Fuhrpark + PDF-Text-Schnappschuss + C11 Wiederkehrende Rechnungen + '
    'C13 Abschlagsrechnungen): Bestandsdaten bekommen automatisch die neuen Default-Werte — '
    'ohne Datenverlust an bestehenden Spalten',
    () async {
      // Schritt 1: Eine echte aktuelle Datenbank mit Nutzdaten anlegen
      // (reales onCreate, drifts eigene DDL).
      final file = File(dbPath);
      var db = AppDatabase.forTesting(
        NativeDatabase(file, setup: (raw) => raw.execute('PRAGMA foreign_keys = ON;')),
      );
      final companyRepo = CompanyRepository(db);
      final customerRepo = CustomerRepository(db);
      final invoiceRepo = InvoiceRepository(db, NumberSequenceRepository(db));

      final company = await companyRepo.create(name: 'Migrations-Testfirma');
      final customer = await customerRepo.create(
        companyId: company.id,
        name: 'Bestandskunde',
        address: 'Alte Anschrift 1',
      );
      final invoice = await invoiceRepo.createDraft(
        companyId: company.id,
        customerId: customer.id,
        issueDate: DateTime(2026, 1, 10),
        serviceDate: DateTime(2026, 1, 10),
        items: [
          InvoiceItemInput(
            kind: InvoiceItemKind.text,
            description: 'Bestandsposition',
            quantity: Decimal.one,
            unitPriceCents: 1000,
            vatRatePercent: 19,
          ),
        ],
      );
      await db.close();

      // Schritt 2: Mechanisch auf v1 zurückbauen — alle seit v1
      // hinzugekommenen Spalten entfernen, PRAGMA user_version auf 1
      // setzen. Das ist byte-genau das, was ein echtes v1-Bestandsgerät
      // auf der Platte hätte (keine Annahme über Spaltenformate nötig,
      // da die restliche DDL drifts eigene ist).
      final raw = sqlite3.open(dbPath);
      // v1 -> v2 (A5):
      raw.execute('ALTER TABLE invoices DROP COLUMN kind;');
      raw.execute('ALTER TABLE companies DROP COLUMN quotes_enabled;');
      raw.execute('ALTER TABLE companies DROP COLUMN orders_enabled;');
      // v2 -> v3 (erweiterte Kunden-/Lieferantenfelder):
      raw.execute('ALTER TABLE customers DROP COLUMN vat_id;');
      raw.execute('ALTER TABLE customers DROP COLUMN contact_person;');
      raw.execute('ALTER TABLE customers DROP COLUMN notes;');
      raw.execute('ALTER TABLE suppliers DROP COLUMN vat_id;');
      raw.execute('ALTER TABLE suppliers DROP COLUMN contact_person;');
      raw.execute('ALTER TABLE suppliers DROP COLUMN notes;');
      raw.execute('ALTER TABLE invoices DROP COLUMN customer_snapshot_vat_id;');
      // v3 -> v4 (anpassbare PDF-Texte):
      raw.execute('ALTER TABLE companies DROP COLUMN pdf_intro_text;');
      raw.execute('ALTER TABLE companies DROP COLUMN pdf_closing_text;');
      raw.execute('ALTER TABLE companies DROP COLUMN pdf_footer_text;');
      // v4 -> v5 (Lieferschein + Dokumentumwandlung):
      raw.execute('ALTER TABLE companies DROP COLUMN delivery_notes_enabled;');
      raw.execute('ALTER TABLE invoices DROP COLUMN converted_from_id;');
      // v5 -> v6 (Einheit + Rabatt pro Position):
      raw.execute('ALTER TABLE invoice_items DROP COLUMN unit;');
      raw.execute('ALTER TABLE invoice_items DROP COLUMN discount_percent;');
      // v6 -> v7 (PDF-Texte pro Dokumentart):
      raw.execute('ALTER TABLE companies DROP COLUMN pdf_intro_text_quote;');
      raw.execute('ALTER TABLE companies DROP COLUMN pdf_closing_text_quote;');
      raw.execute('ALTER TABLE companies DROP COLUMN pdf_intro_text_order;');
      raw.execute('ALTER TABLE companies DROP COLUMN pdf_closing_text_order;');
      raw.execute('ALTER TABLE companies DROP COLUMN pdf_intro_text_delivery_note;');
      raw.execute('ALTER TABLE companies DROP COLUMN pdf_closing_text_delivery_note;');
      // v7 -> v8 (C10 Proforma-Rechnungen):
      raw.execute('ALTER TABLE companies DROP COLUMN proforma_enabled;');
      raw.execute('ALTER TABLE companies DROP COLUMN pdf_intro_text_proforma;');
      raw.execute('ALTER TABLE companies DROP COLUMN pdf_closing_text_proforma;');
      // v8 -> v9 (C1 Projekte): die Invoices-Spalte zuerst entfernen,
      // DANACH die Tabelle, auf die sie verweist (umgekehrte Reihenfolge
      // der Migration selbst — beim Rückbau muss die FK-Spalte weg, bevor
      // ihr Ziel verschwindet).
      raw.execute('ALTER TABLE invoices DROP COLUMN project_id;');
      raw.execute('ALTER TABLE companies DROP COLUMN projects_enabled;');
      raw.execute('DROP TABLE projects;');
      // v9 -> v10 (C6 Fuhrpark): abhängige Tabelle zuerst, dann die
      // Tabelle, auf die sie verweist.
      raw.execute('DROP TABLE vehicle_cost_entries;');
      raw.execute('DROP TABLE vehicles;');
      raw.execute('ALTER TABLE companies DROP COLUMN fleet_enabled;');
      // v10 -> v11 (PDF-Text-Schnappschuss, Audit-Befund 2026-10-17):
      raw.execute('ALTER TABLE invoices DROP COLUMN pdf_intro_text_snapshot;');
      raw.execute('ALTER TABLE invoices DROP COLUMN pdf_closing_text_snapshot;');
      raw.execute('ALTER TABLE invoices DROP COLUMN pdf_footer_text_snapshot;');
      // v11 -> v12 (C11 Wiederkehrende Rechnungen):
      raw.execute('DROP TABLE recurring_invoice_template_items;');
      raw.execute('DROP TABLE recurring_invoice_templates;');
      raw.execute('ALTER TABLE companies DROP COLUMN recurring_invoices_enabled;');
      // v12 -> v13 (C13 Abschlagsrechnungen):
      raw.execute('ALTER TABLE invoices DROP COLUMN is_advance_payment;');
      raw.execute('ALTER TABLE companies DROP COLUMN advance_payment_invoices_enabled;');
      raw.execute('PRAGMA user_version = 1;');
      raw.close();

      // Schritt 3: Neu öffnen — drift erkennt user_version=1 < schemaVersion
      // und muss automatisch BEIDE onUpgrade-Stufen durchlaufen, exakt wie
      // bei einem echten App-Update über mehrere Versionen hinweg.
      db = AppDatabase.forTesting(
        NativeDatabase(file, setup: (r) => r.execute('PRAGMA foreign_keys = ON;')),
      );
      try {
        final migratedCompany = await (db.select(db.companies)..where((c) => c.id.equals(company.id)))
            .getSingle();
        expect(migratedCompany.quotesEnabled, isFalse);
        expect(migratedCompany.ordersEnabled, isFalse);
        expect(migratedCompany.pdfIntroText, isNull);
        expect(migratedCompany.pdfClosingText, isNull);
        expect(migratedCompany.pdfFooterText, isNull);
        expect(migratedCompany.deliveryNotesEnabled, isFalse);
        expect(migratedCompany.pdfIntroTextQuote, isNull);
        expect(migratedCompany.pdfClosingTextQuote, isNull);
        expect(migratedCompany.pdfIntroTextOrder, isNull);
        expect(migratedCompany.pdfClosingTextOrder, isNull);
        expect(migratedCompany.pdfIntroTextDeliveryNote, isNull);
        expect(migratedCompany.pdfClosingTextDeliveryNote, isNull);
        expect(migratedCompany.proformaEnabled, isFalse);
        expect(migratedCompany.pdfIntroTextProforma, isNull);
        expect(migratedCompany.pdfClosingTextProforma, isNull);
        expect(migratedCompany.projectsEnabled, isFalse);
        expect(migratedCompany.fleetEnabled, isFalse);
        expect(migratedCompany.recurringInvoicesEnabled, isFalse);
        expect(migratedCompany.advancePaymentInvoicesEnabled, isFalse);
        expect(migratedCompany.name, 'Migrations-Testfirma', reason: 'Bestandsdaten dürfen nicht verändert werden');

        final migratedInvoice =
            await (db.select(db.invoices)..where((i) => i.id.equals(invoice.id))).getSingle();
        expect(migratedInvoice.kind, DocumentKind.invoice);
        expect(migratedInvoice.customerId, customer.id, reason: 'Bestandsdaten dürfen nicht verändert werden');
        expect(migratedInvoice.customerSnapshotVatId, isNull);
        expect(migratedInvoice.convertedFromId, isNull);
        expect(migratedInvoice.projectId, isNull);
        expect(migratedInvoice.pdfIntroTextSnapshot, isNull);
        expect(migratedInvoice.pdfClosingTextSnapshot, isNull);
        expect(migratedInvoice.pdfFooterTextSnapshot, isNull);
        expect(migratedInvoice.isAdvancePayment, isFalse);

        // Projects-Tabelle existiert nach der Migration und ist nutzbar
        // (nicht nur die Spalte auf Invoices).
        await db.into(db.projects).insert(
              ProjectsCompanion.insert(
                id: 'project-nach-migration',
                companyId: company.id,
                name: 'Testprojekt nach Migration',
                createdAt: DateTime.now(),
              ),
            );
        final createdProject = await (db.select(db.projects)
              ..where((p) => p.id.equals('project-nach-migration')))
            .getSingle();
        expect(createdProject.status, ProjectStatus.active);

        // Vehicles/VehicleCostEntries-Tabellen existieren nach der
        // Migration und sind nutzbar.
        await db.into(db.vehicles).insert(
              VehiclesCompanion.insert(
                id: 'vehicle-nach-migration',
                companyId: company.id,
                name: 'Transporter 1',
                createdAt: DateTime.now(),
              ),
            );
        await db.into(db.vehicleCostEntries).insert(
              VehicleCostEntriesCompanion.insert(
                id: 'cost-nach-migration',
                companyId: company.id,
                vehicleId: 'vehicle-nach-migration',
                date: DateTime.now(),
                amountCents: 5000,
                category: VehicleCostCategory.fuel,
                createdAt: DateTime.now(),
              ),
            );
        final createdCost = await (db.select(db.vehicleCostEntries)
              ..where((c) => c.id.equals('cost-nach-migration')))
            .getSingle();
        expect(createdCost.amountCents, 5000);

        // RecurringInvoiceTemplates/-Items existieren nach der Migration
        // und sind nutzbar.
        await db.into(db.recurringInvoiceTemplates).insert(
              RecurringInvoiceTemplatesCompanion.insert(
                id: 'template-nach-migration',
                companyId: company.id,
                customerId: customer.id,
                label: 'Hosting monatlich',
                interval: RecurrenceInterval.monthly,
                nextDueDate: DateTime(2026, 11, 1),
                createdAt: DateTime.now(),
              ),
            );
        final createdTemplate = await (db.select(db.recurringInvoiceTemplates)
              ..where((t) => t.id.equals('template-nach-migration')))
            .getSingle();
        expect(createdTemplate.active, isTrue);

        final migratedCustomer =
            await (db.select(db.customers)..where((c) => c.id.equals(customer.id))).getSingle();
        expect(migratedCustomer.vatId, isNull);
        expect(migratedCustomer.contactPerson, isNull);
        expect(migratedCustomer.notes, isNull);
        expect(
          migratedCustomer.address,
          'Alte Anschrift 1',
          reason: 'Bestandsdaten dürfen nicht verändert werden',
        );

        final migratedItem =
            await (db.select(db.invoiceItems)..where((i) => i.invoiceId.equals(invoice.id))).getSingle();
        expect(migratedItem.unit, isNull);
        expect(migratedItem.discountPercent, 0);
        expect(
          migratedItem.description,
          'Bestandsposition',
          reason: 'Bestandsdaten dürfen nicht verändert werden',
        );
      } finally {
        await db.close();
      }
    },
  );
}
