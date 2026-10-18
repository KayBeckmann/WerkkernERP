import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';
import '../database/tables.dart';

/// C14.2 Belege/Ausgaben (Kay-Priorisierungsentscheidung 2026-10-18) —
/// gleiche companyId-Isolation wie alle übrigen A0-Repositories. Ein
/// Beleg wird als Bruttobetrag + Steuersatz erfasst (F2-Muster, siehe
/// Doc-Kommentar bei [Expenses] in tables.dart).
class ExpenseRepository {
  ExpenseRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  Future<List<Expense>> listForCompany(String companyId) =>
      (_db.select(_db.expenses)
            ..where((e) => e.companyId.equals(companyId))
            ..orderBy([(e) => OrderingTerm.desc(e.date)]))
          .get();

  Future<Expense?> findById({required String companyId, required String id}) =>
      (_db.select(_db.expenses)..where((e) => e.id.equals(id) & e.companyId.equals(companyId)))
          .getSingleOrNull();

  Future<Expense> create({
    required String companyId,
    required DateTime date,
    required String description,
    required int amountGrossCents,
    required double vatRatePercent,
    String? categoryId,
    String? supplierReference,
    // C1 Projekte / Projekt-Ergebnisrechnung (Kay-Entscheidung
    // 2026-10-19: "Was brauchst du für die Projekt-Ergebnisrechnung?"
    // -> erster Baustein "Belege bekommen eine optionale
    // Projektzuordnung") — optional, wie bei allen übrigen Dokumenten.
    String? projectId,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    await _db.into(_db.expenses).insert(
          ExpensesCompanion.insert(
            id: id,
            companyId: companyId,
            date: date,
            description: description,
            amountGrossCents: amountGrossCents,
            vatRatePercent: vatRatePercent,
            categoryId: Value(categoryId),
            supplierReference: Value(supplierReference),
            projectId: Value(projectId),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return (await findById(companyId: companyId, id: id))!;
  }

  Future<Expense?> update({
    required String companyId,
    required String id,
    DateTime? date,
    String? description,
    int? amountGrossCents,
    double? vatRatePercent,
    Value<String?> categoryId = const Value.absent(),
    Value<String?> supplierReference = const Value.absent(),
    // Wie bei categoryId: `Value.absent()` = unverändert, `Value(null)`
    // = Zuordnung entfernen, `Value(id)` = (neu) zuordnen.
    Value<String?> projectId = const Value.absent(),
  }) async {
    final rows = await (_db.update(_db.expenses)
          ..where((e) => e.id.equals(id) & e.companyId.equals(companyId)))
        .write(
      ExpensesCompanion(
        date: date == null ? const Value.absent() : Value(date),
        description: description == null ? const Value.absent() : Value(description),
        amountGrossCents:
            amountGrossCents == null ? const Value.absent() : Value(amountGrossCents),
        vatRatePercent: vatRatePercent == null ? const Value.absent() : Value(vatRatePercent),
        categoryId: categoryId,
        supplierReference: supplierReference,
        projectId: projectId,
        updatedAt: Value(DateTime.now()),
      ),
    );
    if (rows == 0) return null;
    return findById(companyId: companyId, id: id);
  }

  Future<bool> delete({required String companyId, required String id}) async {
    final rows =
        await (_db.delete(_db.expenses)..where((e) => e.id.equals(id) & e.companyId.equals(companyId)))
            .go();
    return rows > 0;
  }

  /// Alle einem Projekt zugeordneten Belege — Gegenstück zu
  /// `InvoiceRepository.listForProject()`, für die einfache
  /// Projekt-Ergebnisrechnung (Erlöse aus zugeordneten Rechnungen minus
  /// Kosten aus zugeordneten Belegen).
  Future<List<Expense>> listForProject({required String companyId, required String projectId}) =>
      (_db.select(_db.expenses)
            ..where((e) => e.companyId.equals(companyId) & e.projectId.equals(projectId))
            ..orderBy([(e) => OrderingTerm.desc(e.date)]))
          .get();
}
