import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';
import '../database/tables.dart';

/// C14.2 Belege/Ausgaben (Kay-Priorisierungsentscheidung 2026-10-18) —
/// Kategorien je Firma, siehe ausführlichen Doc-Kommentar bei
/// [ExpenseCategories] in tables.dart: die SKR03-Kontonummer ist Kays
/// eigene Angabe, nicht von dieser App vorgegeben.
class ExpenseCategoryRepository {
  ExpenseCategoryRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  /// Typische Kategorien für ein Elektro-Kleingewerbe — bewusst nur
  /// **Labels**, keine Kontonummern (siehe Klassendoc). Kay ergänzt die
  /// tatsächliche SKR03-Nummer selbst, ändert/löscht/ergänzt Kategorien
  /// frei.
  static const _defaultLabels = [
    'Material/Wareneinkauf',
    'Fahrzeugkosten',
    'Versicherungen',
    'Miete/Nebenkosten',
    'Bürokosten/Porto',
    'Werbung/Marketing',
    'Sonstiges',
  ];

  Future<List<ExpenseCategory>> listForCompany(String companyId) =>
      (_db.select(_db.expenseCategories)
            ..where((c) => c.companyId.equals(companyId))
            ..orderBy([(c) => OrderingTerm.asc(c.label)]))
          .get();

  /// Legt die Standardkategorien an, falls die Firma aktuell keine hat —
  /// lazy beim ersten Öffnen der Belege-Übersicht aufgerufen, NICHT beim
  /// Aktivieren des Moduls selbst (ein Modul-Schalter soll keine
  /// Seiteneffekte auf andere Tabellen haben). Bewusst simpel über
  /// "Liste leer?" statt eines eigenen "schon geseedet"-Flags: löscht
  /// Kay irgendwann alle Kategorien, kommen beim nächsten Öffnen wieder
  /// genau die Standardkategorien — kein Datenverlust, nur ein
  /// nachvollziehbarer Fallback statt einer dauerhaft leeren Liste.
  Future<void> seedDefaultsIfNeverSeeded(String companyId) async {
    final existing = await listForCompany(companyId);
    if (existing.isNotEmpty) return;
    for (final label in _defaultLabels) {
      await create(companyId: companyId, label: label);
    }
  }

  Future<ExpenseCategory> create({
    required String companyId,
    required String label,
    String? skr03Account,
  }) async {
    final id = _uuid.v4();
    await _db.into(_db.expenseCategories).insert(
          ExpenseCategoriesCompanion.insert(
            id: id,
            companyId: companyId,
            label: label,
            skr03Account: Value(skr03Account),
            createdAt: DateTime.now(),
          ),
        );
    return (_db.select(_db.expenseCategories)..where((c) => c.id.equals(id))).getSingle();
  }

  Future<bool> update({
    required String companyId,
    required String id,
    String? label,
    Value<String?> skr03Account = const Value.absent(),
  }) async {
    final rows = await (_db.update(_db.expenseCategories)
          ..where((c) => c.id.equals(id) & c.companyId.equals(companyId)))
        .write(
      ExpenseCategoriesCompanion(
        label: label == null ? const Value.absent() : Value(label),
        skr03Account: skr03Account,
      ),
    );
    return rows > 0;
  }

  Future<bool> delete({required String companyId, required String id}) async {
    final rows = await (_db.delete(_db.expenseCategories)
          ..where((c) => c.id.equals(id) & c.companyId.equals(companyId)))
        .go();
    return rows > 0;
  }
}
