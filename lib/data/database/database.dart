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
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openConnection());

  /// Für Tests: eigene Verbindung injizieren (z. B. in-memory).
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 6;

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
        },
      );
}
