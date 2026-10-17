import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';
import '../database/tables.dart';

/// Projekte je Firma (C1, Kay-Priorisierungsentscheidung 2026-10-17) —
/// gleiche companyId-Isolation wie alle übrigen A0-Repositories. Dies ist
/// der **C1-Kern**: Projekte anlegen/archivieren und Dokumente ihnen
/// zuordnen. Die Projekt-GuV/Stunden-Soll-Ist-Auswertung ist bewusst
/// NICHT Teil dieses Repositories (siehe Doc-Kommentar bei [Projects] in
/// tables.dart) — dafür fehlen noch mit Kay zu klärende Grundregeln.
class ProjectRepository {
  ProjectRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  Future<List<Project>> listForCompany(
    String companyId, {
    bool includeArchived = false,
  }) {
    final query = _db.select(_db.projects)..where((p) => p.companyId.equals(companyId));
    if (!includeArchived) {
      query.where((p) => p.status.equalsValue(ProjectStatus.active));
    }
    query.orderBy([(p) => OrderingTerm.asc(p.name)]);
    return query.get();
  }

  Future<Project?> findById({required String companyId, required String id}) =>
      (_db.select(_db.projects)..where((p) => p.id.equals(id) & p.companyId.equals(companyId)))
          .getSingleOrNull();

  Future<Project> create({
    required String companyId,
    required String name,
    String? customerId,
    String? notes,
  }) async {
    final id = _uuid.v4();
    await _db.into(_db.projects).insert(
          ProjectsCompanion.insert(
            id: id,
            companyId: companyId,
            name: name,
            customerId: Value(customerId),
            notes: Value(notes),
            createdAt: DateTime.now(),
          ),
        );
    return (await findById(companyId: companyId, id: id))!;
  }

  Future<bool> update({
    required String companyId,
    required String id,
    String? name,
    String? customerId,
    String? notes,
  }) async {
    final existing = await findById(companyId: companyId, id: id);
    if (existing == null) return false;
    final rows = await (_db.update(_db.projects)
          ..where((p) => p.id.equals(id) & p.companyId.equals(companyId)))
        .write(
      ProjectsCompanion(
        name: name == null ? const Value.absent() : Value(name),
        customerId: Value(customerId),
        notes: Value(notes),
      ),
    );
    return rows > 0;
  }

  /// Archiviert ein Projekt (Status `archived`) statt es zu löschen —
  /// gleiches "Deaktivieren löscht keine Daten"-Prinzip wie die
  /// Modul-Schalter. Bereits zugeordnete Dokumente bleiben unverändert
  /// zugeordnet, das Projekt verschwindet nur aus Auswahllisten.
  Future<bool> setStatus({
    required String companyId,
    required String id,
    required ProjectStatus status,
  }) async {
    final rows = await (_db.update(_db.projects)
          ..where((p) => p.id.equals(id) & p.companyId.equals(companyId)))
        .write(ProjectsCompanion(status: Value(status)));
    return rows > 0;
  }

  /// Löscht ein Projekt nur, wenn ihm **kein** Dokument zugeordnet ist —
  /// sonst [StateError] statt stillschweigend Fremdschlüssel auf `null`
  /// zu setzen und Zuordnungshistorie zu verlieren. Für ein Projekt mit
  /// bereits zugeordneten Dokumenten ist [setStatus] (Archivieren) der
  /// richtige Weg.
  Future<bool> delete({required String companyId, required String id}) async {
    final linked = await (_db.select(_db.invoices)..where((i) => i.projectId.equals(id))).get();
    if (linked.isNotEmpty) {
      throw StateError(
        'Projekt hat noch zugeordnete Dokumente (${linked.length}) — archivieren statt löschen.',
      );
    }
    final rows = await (_db.delete(_db.projects)
          ..where((p) => p.id.equals(id) & p.companyId.equals(companyId)))
        .go();
    return rows > 0;
  }
}
