import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';
import '../database/tables.dart';

/// Rollen-Stamm für die Zeiterfassung (C3, Nachtrag 2026-10-20) — siehe
/// ausführlichen Doc-Kommentar bei [StaffRoles] in tables.dart: eine
/// Rolle ist eine frei benennbare Stundensatz-Kategorie, **keine**
/// Mitarbeiter-Stammdaten mit Namen (kein Login/Mehrbenutzer-Konzept in
/// dieser App, A0-Prinzip).
class StaffRoleRepository {
  StaffRoleRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  /// Vorschlag-Defaults aus dem Nachtrag ("Monteur, Meister,
  /// Projektleiter") — bewusst nur Labels, kein geratener Stundensatz
  /// (startet bei 0, siehe Doc-Kommentar bei [StaffRoles.
  /// hourlyCostRateCents]). Frei umbenennbar/ergänzbar/löschbar.
  static const _defaultLabels = ['Monteur', 'Meister', 'Projektleiter'];

  Future<List<StaffRole>> listForCompany(String companyId) =>
      (_db.select(_db.staffRoles)
            ..where((r) => r.companyId.equals(companyId))
            ..orderBy([(r) => OrderingTerm.asc(r.name)]))
          .get();

  Future<StaffRole?> findById({required String companyId, required String id}) =>
      (_db.select(_db.staffRoles)..where((r) => r.id.equals(id) & r.companyId.equals(companyId)))
          .getSingleOrNull();

  /// Lazy beim ersten Öffnen der Rollenverwaltung aufgerufen — gleiches
  /// Prinzip wie `ExpenseCategoryRepository.seedDefaultsIfNeverSeeded()`
  /// (siehe dort für die Begründung: kein "schon geseedet"-Flag nötig,
  /// nur "Liste leer?").
  Future<void> seedDefaultsIfNeverSeeded(String companyId) async {
    final existing = await listForCompany(companyId);
    if (existing.isNotEmpty) return;
    for (final label in _defaultLabels) {
      await create(companyId: companyId, name: label);
    }
  }

  Future<StaffRole> create({
    required String companyId,
    required String name,
    int hourlyCostRateCents = 0,
  }) async {
    final id = _uuid.v4();
    await _db.into(_db.staffRoles).insert(
          StaffRolesCompanion.insert(
            id: id,
            companyId: companyId,
            name: name,
            hourlyCostRateCents: Value(hourlyCostRateCents),
            createdAt: DateTime.now(),
          ),
        );
    return (await findById(companyId: companyId, id: id))!;
  }

  Future<bool> update({
    required String companyId,
    required String id,
    String? name,
    int? hourlyCostRateCents,
  }) async {
    final rows = await (_db.update(_db.staffRoles)
          ..where((r) => r.id.equals(id) & r.companyId.equals(companyId)))
        .write(
      StaffRolesCompanion(
        name: name == null ? const Value.absent() : Value(name),
        hourlyCostRateCents:
            hourlyCostRateCents == null ? const Value.absent() : Value(hourlyCostRateCents),
      ),
    );
    return rows > 0;
  }

  Future<bool> delete({required String companyId, required String id}) async {
    final rows =
        await (_db.delete(_db.staffRoles)..where((r) => r.id.equals(id) & r.companyId.equals(companyId)))
            .go();
    return rows > 0;
  }
}
