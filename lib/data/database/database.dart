import 'package:drift/drift.dart';

import 'connection.dart';
import 'tables.dart';

part 'database.g.dart';

/// Lokale Datenbank (A0 Punkt 2: "lokale SQLite mit schema-versionierten
/// Migrationen"). Jede Schemaänderung erhöht [schemaVersion] und bekommt
/// eine Migrationsstufe in [migration] — von Anfang an, auch wenn es bei
/// Version 1 noch nichts zu migrieren gibt.
@DriftDatabase(
  tables: [
    Companies,
    Customers,
    Suppliers,
    ArticleGroups,
    Articles,
    ArticleSupplierPrices,
    Invoices,
    InvoiceItems,
    NumberSequences,
    Projects,
    Vehicles,
    VehicleCostEntries,
    RecurringInvoiceTemplates,
    RecurringInvoiceTemplateItems,
    ExpenseCategories,
    Expenses,
    BankTransactions,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// [encryptionKey] siehe Doc-Kommentar bei `openConnection()` (F4,
  /// Kay-Entscheidung 2026-10-19) — `null` bleibt unverschlüsselt
  /// (Standard, Bestandsverhalten).
  AppDatabase({String? encryptionKey}) : super(openConnection(encryptionKey: encryptionKey));

  /// Für Tests: eigene Verbindung injizieren (z. B. in-memory).
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 24;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (migrator) async {
          await migrator.createAll();
        },
        // Niemals eine bestehende Stufe nachträglich ändern, nur neue
        // anhängen (A0: "schema-versionierte Migrationen").
        onUpgrade: (migrator, from, to) async {
          if (from < 2) {
            // A5: Angebot/Auftrag. `addColumn` nutzt den in tables.dart
            // definierten withDefault()-Wert, Bestandszeilen bekommen
            // also automatisch quotesEnabled=false/ordersEnabled=false
            // bzw. kind='invoice' — keine bestehende Rechnung wechselt
            // dadurch die Dokumentart.
            await migrator.addColumn(invoices, invoices.kind);
            await migrator.addColumn(companies, companies.quotesEnabled);
            await migrator.addColumn(companies, companies.ordersEnabled);
          }
          if (from < 3) {
            // Kay-Nachtrag 2026-10-16: erweiterte Kunden-/Lieferanten-
            // Datenfelder + USt-IdNr.-Snapshot bei Finalisierung.
            await migrator.addColumn(customers, customers.vatId);
            await migrator.addColumn(customers, customers.contactPerson);
            await migrator.addColumn(customers, customers.notes);
            await migrator.addColumn(suppliers, suppliers.vatId);
            await migrator.addColumn(suppliers, suppliers.contactPerson);
            await migrator.addColumn(suppliers, suppliers.notes);
            await migrator.addColumn(invoices, invoices.customerSnapshotVatId);
          }
          if (from < 4) {
            // Kay-Nachtrag 2026-10-16: anpassbare PDF-Texte.
            await migrator.addColumn(companies, companies.pdfIntroText);
            await migrator.addColumn(companies, companies.pdfClosingText);
            await migrator.addColumn(companies, companies.pdfFooterText);
          }
          if (from < 5) {
            // Kay-Nachtrag 2026-10-16: Lieferschein + Dokumentumwandlung.
            await migrator.addColumn(companies, companies.deliveryNotesEnabled);
            await migrator.addColumn(invoices, invoices.convertedFromId);
          }
          if (from < 6) {
            // Kay-Nachtrag 2026-10-16: Einheit + Rabatt pro Position.
            await migrator.addColumn(invoiceItems, invoiceItems.unit);
            await migrator.addColumn(invoiceItems, invoiceItems.discountPercent);
          }
          if (from < 7) {
            // Kay-Nachtrag 2026-10-16 (zweiter Nachtrag): Einleitungs-/
            // Schlusstext pro Dokumentart statt eines gemeinsamen Satzes.
            await migrator.addColumn(companies, companies.pdfIntroTextQuote);
            await migrator.addColumn(companies, companies.pdfClosingTextQuote);
            await migrator.addColumn(companies, companies.pdfIntroTextOrder);
            await migrator.addColumn(companies, companies.pdfClosingTextOrder);
            await migrator.addColumn(companies, companies.pdfIntroTextDeliveryNote);
            await migrator.addColumn(companies, companies.pdfClosingTextDeliveryNote);
          }
          if (from < 8) {
            // C10 Proforma-Rechnungen (Kay-Priorisierungsentscheidung
            // 2026-10-17, vor Phase B).
            await migrator.addColumn(companies, companies.proformaEnabled);
            await migrator.addColumn(companies, companies.pdfIntroTextProforma);
            await migrator.addColumn(companies, companies.pdfClosingTextProforma);
          }
          if (from < 9) {
            // C1 Projekte (Kay-Priorisierungsentscheidung 2026-10-17).
            // Neue Tabelle zuerst anlegen, DANACH die auf sie
            // verweisende Spalte ergänzen (Invoices.projectId).
            await migrator.createTable(projects);
            await migrator.addColumn(companies, companies.projectsEnabled);
            await migrator.addColumn(invoices, invoices.projectId);
          }
          if (from < 10) {
            // C6 Fuhrpark/Auswärtsmontage (Kay-Priorisierungsentscheidung
            // 2026-10-17). vehicleCostEntries verweist auf vehicles UND
            // projects — beide müssen vorher existieren (projects seit
            // v9 bereits vorhanden).
            await migrator.createTable(vehicles);
            await migrator.createTable(vehicleCostEntries);
            await migrator.addColumn(companies, companies.fleetEnabled);
          }
          if (from < 11) {
            // Audit-Befund 2026-10-17 (Abweichungen.md Abschnitt 2.1):
            // PDF-Text-Schnappschuss, damit ein später geänderter
            // Einleitungs-/Schluss-/Fußzeilentext eine bereits
            // finalisierte Rechnung nicht nachträglich anders aussehen
            // lässt. Bestehende finalisierte Dokumente bekommen hier
            // bewusst KEINEN rückwirkenden Schnappschuss (die zum
            // damaligen Finalisierungszeitpunkt tatsächlich verwendeten
            // Texte sind nicht mehr rekonstruierbar) — `null` bedeutet
            // für sie weiterhin "kein Text", genau wie zuvor.
            await migrator.addColumn(invoices, invoices.pdfIntroTextSnapshot);
            await migrator.addColumn(invoices, invoices.pdfClosingTextSnapshot);
            await migrator.addColumn(invoices, invoices.pdfFooterTextSnapshot);
          }
          if (from < 12) {
            // C11 Wiederkehrende Rechnungen (Kay-Priorisierungsentscheidung
            // 2026-10-17). Vorlagen-Tabelle zuerst, dann die Positionen,
            // die auf sie verweisen.
            await migrator.createTable(recurringInvoiceTemplates);
            await migrator.createTable(recurringInvoiceTemplateItems);
            await migrator.addColumn(companies, companies.recurringInvoicesEnabled);
          }
          if (from < 13) {
            // C13 Abschlagsrechnungen (Kay-Priorisierungsentscheidung
            // 2026-10-17).
            await migrator.addColumn(invoices, invoices.isAdvancePayment);
            await migrator.addColumn(companies, companies.advancePaymentInvoicesEnabled);
          }
          if (from < 14) {
            // C12 Mahnwesen (Kay-Priorisierungsentscheidung 2026-10-17).
            await migrator.addColumn(invoices, invoices.dueDate);
            await migrator.addColumn(invoices, invoices.paymentStatus);
            await migrator.addColumn(invoices, invoices.paidAt);
            await migrator.addColumn(companies, companies.dunningEnabled);
          }
          if (from < 15) {
            // C12 Mahnwesen — Nachbesserung (Kay-Feedback 2026-10-17):
            // konfigurierbare Fristen/Gebühren/Zins + Mahnschreiben-Texte.
            await migrator.addColumn(companies, companies.dunningReminder2AfterDays);
            await migrator.addColumn(companies, companies.dunningReminder3AfterDays);
            await migrator.addColumn(companies, companies.dunningFeeLevel1Cents);
            await migrator.addColumn(companies, companies.dunningFeeLevel2Cents);
            await migrator.addColumn(companies, companies.dunningFeeLevel3Cents);
            await migrator.addColumn(companies, companies.dunningInterestRatePercent);
            await migrator.addColumn(companies, companies.pdfIntroTextDunning);
            await migrator.addColumn(companies, companies.pdfClosingTextDunning);
          }
          if (from < 16) {
            // C7a SMTP-Versand (Kay-Nachfrage 2026-10-17: "Gibt es schon
            // den SMTP Versand?"). Das Passwort ist bewusst keine Spalte
            // hier — siehe Doc-Kommentar bei `Companies.smtpEnabled`.
            await migrator.addColumn(companies, companies.smtpEnabled);
            await migrator.addColumn(companies, companies.smtpHost);
            await migrator.addColumn(companies, companies.smtpPort);
            await migrator.addColumn(companies, companies.smtpUsername);
            await migrator.addColumn(companies, companies.smtpFromAddress);
            await migrator.addColumn(companies, companies.smtpFromName);
            await migrator.addColumn(companies, companies.smtpUseTls);
            await migrator.addColumn(companies, companies.smtpInvoiceSubjectTemplate);
            await migrator.addColumn(companies, companies.smtpInvoiceBodyTemplate);
            await migrator.addColumn(companies, companies.smtpDunningSubjectTemplate);
            await migrator.addColumn(companies, companies.smtpDunningBodyTemplate);
          }
          if (from < 17) {
            // C14 Buchhaltung (Kay-Priorisierungsentscheidung 2026-10-18,
            // voller Umfang: Offene Posten + Belege + Bankabgleich +
            // DATEV-Export, SKR03, CSV-Bankimport).
            await migrator.addColumn(companies, companies.buchhaltungEnabled);
          }
          if (from < 18) {
            // C14.2 Belege/Ausgaben (Kern).
            await migrator.createTable(expenseCategories);
            await migrator.createTable(expenses);
          }
          if (from < 19) {
            // C14.4 Bankabgleich (CSV).
            await migrator.addColumn(companies, companies.bankCsvDelimiter);
            await migrator.addColumn(companies, companies.bankCsvHasHeaderRow);
            await migrator.addColumn(companies, companies.bankCsvDateColumn);
            await migrator.addColumn(companies, companies.bankCsvAmountColumn);
            await migrator.addColumn(companies, companies.bankCsvPurposeColumn);
            await migrator.addColumn(companies, companies.bankCsvCounterpartyColumn);
            await migrator.addColumn(companies, companies.bankCsvDateFormat);
            await migrator.addColumn(companies, companies.bankCsvDecimalSeparator);
            await migrator.createTable(bankTransactions);
          }
          if (from < 20) {
            // C14.5 DATEV-Export (SKR03).
            await migrator.addColumn(companies, companies.datevBeraterNummer);
            await migrator.addColumn(companies, companies.datevMandantNummer);
            await migrator.addColumn(companies, companies.datevBankGegenkonto);
            await migrator.addColumn(companies, companies.datevSachkontenlaenge);
          }
          if (from < 21) {
            // Gutschriften (Kay-Entscheidung 2026-10-19: "Gutschriften
            // bekommen einen eigenen Nummernkreis") + Projekt-
            // Direktkosten bei Belegen (Kay-Anfrage 2026-10-19:
            // Projekt-Ergebnisrechnung).
            await migrator.addColumn(companies, companies.creditNotesEnabled);
            await migrator.addColumn(companies, companies.pdfIntroTextCreditNote);
            await migrator.addColumn(companies, companies.pdfClosingTextCreditNote);
            // Nur nachträglich hinzufügen, wenn `expenses` schon VOR diesem
            // Schritt existierte (from >= 18) — sonst hat `createTable`
            // oben (from < 18) die Tabelle bereits mit dem aktuellen
            // Schema inkl. project_id angelegt, und ein addColumn hier
            // würde mit "duplicate column name" fehlschlagen.
            if (from >= 18) {
              await migrator.addColumn(expenses, expenses.projectId);
            }
          }
          if (from < 22) {
            // Nachtrag 2026-10-18: Artikel müssen deaktiviert werden
            // können — `articles` existiert seit v1, hier reicht ein
            // einfaches addColumn.
            await migrator.addColumn(articles, articles.active);
          }
          if (from < 23) {
            // Nachtrag 2026-10-18: Kleinunternehmerregelung (§19 UStG).
            await migrator.addColumn(companies, companies.isSmallBusinessExempt);
          }
          if (from < 24) {
            // C5.1 Lagerbestand (Nachtrag 2026-10-19). `bestellwesenEnabled`
            // kommt erst mit C5.2 in einer eigenen, späteren Migration.
            await migrator.addColumn(companies, companies.lagerbestandEnabled);
            await migrator.addColumn(articles, articles.stockQuantity);
            await migrator.addColumn(articles, articles.minimumStock);
          }
        },
      );
}
