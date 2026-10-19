import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/data/database/tables.dart';
import 'package:werkkernerp/data/repositories/article_repository.dart';
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
/// v12→v13: C13 Abschlagsrechnungen; v13→v14: C12 Mahnwesen; v14→v15:
/// C12 Mahnwesen — Nachbesserung (konfigurierbare Fristen/Gebühren/Zins +
/// Mahnschreiben-Texte, Kay-Feedback 2026-10-17); v15→v16: C7a
/// SMTP-Versand; v16→v17: C14 Buchhaltung-Modulschalter; v17→v18:
/// C14.2 Belege/Ausgaben; v18→v19: C14.4 Bankabgleich/CSV; v19→v20:
/// C14.5 DATEV-Export; v20→v21: Gutschriften mit eigenem Nummernkreis +
/// optionale Projektzuordnung bei Belegen, Kay-Entscheidung 2026-10-19;
/// v21→v22: Artikel deaktivierbar, Nachtrag 2026-10-18).
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
    'Migration v1→v22 (A5 + erweiterte Kunden-/Lieferantenfelder + PDF-Texte + Lieferschein + '
    'Einheit/Rabatt pro Position + PDF-Texte pro Dokumentart + C10 Proforma-Rechnungen + '
    'C1 Projekte + C6 Fuhrpark + PDF-Text-Schnappschuss + C11 Wiederkehrende Rechnungen + '
    'C13 Abschlagsrechnungen + C12 Mahnwesen + C12 Mahnwesen-Nachbesserung + C7a '
    'SMTP-Versand + C14 Buchhaltung-Modulschalter + C14.2 Belege/Ausgaben + '
    'C14.4 Bankabgleich/CSV + C14.5 DATEV-Export + Gutschriften/Projektzuordnung '
    'Belege + Artikel deaktivierbar): Bestandsdaten '
    'bekommen automatisch die neuen Default-Werte — ohne '
    'Datenverlust an bestehenden Spalten',
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
      final articleRepo = ArticleRepository(db);

      final company = await companyRepo.create(name: 'Migrations-Testfirma');
      final customer = await customerRepo.create(
        companyId: company.id,
        name: 'Bestandskunde',
        address: 'Alte Anschrift 1',
      );
      final article = await articleRepo.create(companyId: company.id, name: 'Bestandsartikel');
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
      // v13 -> v14 (C12 Mahnwesen):
      raw.execute('ALTER TABLE invoices DROP COLUMN due_date;');
      raw.execute('ALTER TABLE invoices DROP COLUMN payment_status;');
      raw.execute('ALTER TABLE invoices DROP COLUMN paid_at;');
      raw.execute('ALTER TABLE companies DROP COLUMN dunning_enabled;');
      // v14 -> v15 (C12 Mahnwesen — Nachbesserung: konfigurierbare
      // Fristen/Gebühren/Zins + Mahnschreiben-Texte):
      raw.execute('ALTER TABLE companies DROP COLUMN dunning_reminder2_after_days;');
      raw.execute('ALTER TABLE companies DROP COLUMN dunning_reminder3_after_days;');
      raw.execute('ALTER TABLE companies DROP COLUMN dunning_fee_level1_cents;');
      raw.execute('ALTER TABLE companies DROP COLUMN dunning_fee_level2_cents;');
      raw.execute('ALTER TABLE companies DROP COLUMN dunning_fee_level3_cents;');
      raw.execute('ALTER TABLE companies DROP COLUMN dunning_interest_rate_percent;');
      raw.execute('ALTER TABLE companies DROP COLUMN pdf_intro_text_dunning;');
      raw.execute('ALTER TABLE companies DROP COLUMN pdf_closing_text_dunning;');
      // v15 -> v16 (C7a SMTP-Versand, Kay-Nachfrage 2026-10-17):
      raw.execute('ALTER TABLE companies DROP COLUMN smtp_enabled;');
      raw.execute('ALTER TABLE companies DROP COLUMN smtp_host;');
      raw.execute('ALTER TABLE companies DROP COLUMN smtp_port;');
      raw.execute('ALTER TABLE companies DROP COLUMN smtp_username;');
      raw.execute('ALTER TABLE companies DROP COLUMN smtp_from_address;');
      raw.execute('ALTER TABLE companies DROP COLUMN smtp_from_name;');
      raw.execute('ALTER TABLE companies DROP COLUMN smtp_use_tls;');
      raw.execute('ALTER TABLE companies DROP COLUMN smtp_invoice_subject_template;');
      raw.execute('ALTER TABLE companies DROP COLUMN smtp_invoice_body_template;');
      raw.execute('ALTER TABLE companies DROP COLUMN smtp_dunning_subject_template;');
      raw.execute('ALTER TABLE companies DROP COLUMN smtp_dunning_body_template;');
      // v16 -> v17 (C14 Buchhaltung, Kay-Priorisierungsentscheidung
      // 2026-10-18):
      raw.execute('ALTER TABLE companies DROP COLUMN buchhaltung_enabled;');
      // v17 -> v18 (C14.2 Belege/Ausgaben): abhängige Tabelle zuerst.
      // Vorher die project_id-Spalte entfernen, die erst bei v20->v21
      // hinzukam — sonst schlägt DROP TABLE auf einer bereits um diese
      // Spalte erweiterten Tabelle fehl.
      raw.execute('ALTER TABLE expenses DROP COLUMN project_id;');
      raw.execute('DROP TABLE expenses;');
      raw.execute('DROP TABLE expense_categories;');
      // v18 -> v19 (C14.4 Bankabgleich/CSV):
      raw.execute('DROP TABLE bank_transactions;');
      raw.execute('ALTER TABLE companies DROP COLUMN bank_csv_delimiter;');
      raw.execute('ALTER TABLE companies DROP COLUMN bank_csv_has_header_row;');
      raw.execute('ALTER TABLE companies DROP COLUMN bank_csv_date_column;');
      raw.execute('ALTER TABLE companies DROP COLUMN bank_csv_amount_column;');
      raw.execute('ALTER TABLE companies DROP COLUMN bank_csv_purpose_column;');
      raw.execute('ALTER TABLE companies DROP COLUMN bank_csv_counterparty_column;');
      raw.execute('ALTER TABLE companies DROP COLUMN bank_csv_date_format;');
      raw.execute('ALTER TABLE companies DROP COLUMN bank_csv_decimal_separator;');
      // v19 -> v20 (C14.5 DATEV-Export):
      raw.execute('ALTER TABLE companies DROP COLUMN datev_berater_nummer;');
      raw.execute('ALTER TABLE companies DROP COLUMN datev_mandant_nummer;');
      raw.execute('ALTER TABLE companies DROP COLUMN datev_bank_gegenkonto;');
      raw.execute('ALTER TABLE companies DROP COLUMN datev_sachkontenlaenge;');
      // v20 -> v21 (Gutschriften eigener Nummernkreis + optionale
      // Projektzuordnung bei Belegen, Kay-Entscheidung 2026-10-19):
      raw.execute('ALTER TABLE companies DROP COLUMN credit_notes_enabled;');
      raw.execute('ALTER TABLE companies DROP COLUMN pdf_intro_text_credit_note;');
      raw.execute('ALTER TABLE companies DROP COLUMN pdf_closing_text_credit_note;');
      // v21 -> v22 (Artikel deaktivierbar, Nachtrag 2026-10-18):
      raw.execute('ALTER TABLE articles DROP COLUMN active;');
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
        expect(migratedCompany.dunningEnabled, isFalse);
        expect(migratedCompany.dunningReminder2AfterDays, 14);
        expect(migratedCompany.dunningReminder3AfterDays, 28);
        expect(migratedCompany.dunningFeeLevel1Cents, 0);
        expect(migratedCompany.dunningFeeLevel2Cents, 0);
        expect(migratedCompany.dunningFeeLevel3Cents, 0);
        expect(migratedCompany.dunningInterestRatePercent, 0);
        expect(migratedCompany.pdfIntroTextDunning, isNull);
        expect(migratedCompany.pdfClosingTextDunning, isNull);
        expect(migratedCompany.smtpEnabled, isFalse);
        expect(migratedCompany.smtpHost, isNull);
        expect(migratedCompany.smtpPort, 587);
        expect(migratedCompany.smtpUsername, isNull);
        expect(migratedCompany.smtpFromAddress, isNull);
        expect(migratedCompany.smtpFromName, isNull);
        expect(migratedCompany.smtpUseTls, isTrue);
        expect(migratedCompany.smtpInvoiceSubjectTemplate, isNull);
        expect(migratedCompany.smtpInvoiceBodyTemplate, isNull);
        expect(migratedCompany.smtpDunningSubjectTemplate, isNull);
        expect(migratedCompany.smtpDunningBodyTemplate, isNull);
        expect(migratedCompany.buchhaltungEnabled, isFalse);
        expect(migratedCompany.bankCsvDelimiter, ';');
        expect(migratedCompany.bankCsvHasHeaderRow, isTrue);
        expect(migratedCompany.bankCsvDateColumn, isNull);
        expect(migratedCompany.bankCsvAmountColumn, isNull);
        expect(migratedCompany.bankCsvPurposeColumn, isNull);
        expect(migratedCompany.bankCsvCounterpartyColumn, isNull);
        expect(migratedCompany.bankCsvDateFormat, 'dd.MM.yyyy');
        expect(migratedCompany.bankCsvDecimalSeparator, ',');
        expect(migratedCompany.datevBeraterNummer, isNull);
        expect(migratedCompany.datevMandantNummer, isNull);
        expect(migratedCompany.datevBankGegenkonto, isNull);
        expect(migratedCompany.datevSachkontenlaenge, 4);
        expect(migratedCompany.creditNotesEnabled, isFalse);
        expect(migratedCompany.pdfIntroTextCreditNote, isNull);
        expect(migratedCompany.pdfClosingTextCreditNote, isNull);
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
        expect(migratedInvoice.dueDate, isNull);
        expect(migratedInvoice.paymentStatus, PaymentStatus.open);
        expect(migratedInvoice.paidAt, isNull);

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

        // ExpenseCategories/Expenses existieren nach der Migration und
        // sind nutzbar.
        await db.into(db.expenseCategories).insert(
              ExpenseCategoriesCompanion.insert(
                id: 'category-nach-migration',
                companyId: company.id,
                label: 'Material',
                createdAt: DateTime.now(),
              ),
            );
        await db.into(db.expenses).insert(
              ExpensesCompanion.insert(
                id: 'expense-nach-migration',
                companyId: company.id,
                date: DateTime.now(),
                description: 'Testbeleg',
                amountGrossCents: 1190,
                vatRatePercent: 19,
                categoryId: const Value('category-nach-migration'),
                projectId: const Value('project-nach-migration'),
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            );
        final createdExpense = await (db.select(db.expenses)
              ..where((e) => e.id.equals('expense-nach-migration')))
            .getSingle();
        expect(createdExpense.amountGrossCents, 1190);
        expect(
          createdExpense.projectId,
          'project-nach-migration',
          reason: 'C14.2 Belege können seit v21 optional einem Projekt zugeordnet werden (Projekt-Ergebnisrechnung)',
        );

        // BankTransactions existiert nach der Migration und ist nutzbar.
        await db.into(db.bankTransactions).insert(
              BankTransactionsCompanion.insert(
                id: 'bank-tx-nach-migration',
                companyId: company.id,
                date: DateTime.now(),
                amountCents: 11900,
                importHash: 'hash-nach-migration',
                importedAt: DateTime.now(),
              ),
            );
        final createdBankTransaction = await (db.select(db.bankTransactions)
              ..where((t) => t.id.equals('bank-tx-nach-migration')))
            .getSingle();
        expect(createdBankTransaction.amountCents, 11900);

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

        final migratedArticle =
            await (db.select(db.articles)..where((a) => a.id.equals(article.id))).getSingle();
        expect(
          migratedArticle.active,
          isTrue,
          reason: 'Bestandsartikel gelten nach der Migration als aktiv (withDefault(true))',
        );
        expect(
          migratedArticle.name,
          'Bestandsartikel',
          reason: 'Bestandsdaten dürfen nicht verändert werden',
        );
      } finally {
        await db.close();
      }
    },
  );
}
