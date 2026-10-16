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
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (migrator) async {
          await migrator.createAll();
        },
        // onUpgrade: ab Schema-Version 2 hier je Stufe eine `if (from < X)`
        // Migration ergänzen. Niemals eine bestehende Stufe nachträglich
        // ändern, nur neue anhängen (A0: "schema-versionierte
        // Migrationen").
      );
}
