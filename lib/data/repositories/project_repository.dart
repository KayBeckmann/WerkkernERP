import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';
import '../database/tables.dart';
import 'number_sequence_repository.dart';

/// Zähler-Dokumenttyp für [NumberSequenceRepository.allocateNext] — ein
/// Projekt ist kein [DocumentKind], braucht aber (C2-Nachtrag
/// 2026-10-21) denselben Firmen-/Jahres-Zähler-Mechanismus für seine
/// Projekt-Kennziffer (PP), siehe Doc-Kommentar bei [Projects] in
/// tables.dart.
const projectNumberDocumentType = 'project';

/// Projekte je Firma (C1, Kay-Priorisierungsentscheidung 2026-10-17) —
/// gleiche companyId-Isolation wie alle übrigen A0-Repositories. Dies ist
/// der **C1-Kern**: Projekte anlegen/archivieren und Dokumente ihnen
/// zuordnen. Die Projekt-GuV/Stunden-Soll-Ist-Auswertung ist bewusst
/// NICHT Teil dieses Repositories (siehe Doc-Kommentar bei [Projects] in
/// tables.dart) — dafür fehlen noch mit Kay zu klärende Grundregeln.
class ProjectRepository {
  ProjectRepository(this._db, this._numberSequences);

  final AppDatabase _db;
  final NumberSequenceRepository _numberSequences;
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

  /// [foundingYear]/[projectNumber] (C2-Nachtrag 2026-10-21, Kay-
  /// Entscheidung auf Rückfrage) werden hier **fest eingefroren** —
  /// [projectNumber] (PP) ist ein pro Kalenderjahr neu bei 1 startender
  /// Zähler je Firma (siehe [projectNumberDocumentType]), nie rückwirkend
  /// neu vergeben. Beide Werte ändern sich auch dann nicht mehr, wenn
  /// das Projekt über mehrere Jahre hinweg weiterläuft.
  Future<Project> create({
    required String companyId,
    required String name,
    String? customerId,
    String? notes,
  }) async {
    return _db.transaction(() async {
      final id = _uuid.v4();
      final now = DateTime.now();
      final foundingYear = now.year;
      final projectNumber = await _numberSequences.allocateNext(
        companyId: companyId,
        documentType: projectNumberDocumentType,
        year: foundingYear,
      );
      await _db.into(_db.projects).insert(
            ProjectsCompanion.insert(
              id: id,
              companyId: companyId,
              name: name,
              customerId: Value(customerId),
              notes: Value(notes),
              createdAt: now,
              foundingYear: Value(foundingYear),
              projectNumber: Value(projectNumber),
            ),
          );
      return (await findById(companyId: companyId, id: id))!;
    });
  }

  /// Rückwirkende PP-Vergabe für Projekte, die vor dem C2-Nachtrag
  /// (2026-10-21) angelegt wurden und daher `projectNumber == null`
  /// haben (Kay-Entscheidung: "Bestehende Projekte ohne PP werden beim
  /// Umstellen rückwirkend in Anlage-Reihenfolge innerhalb ihres
  /// Gründungsjahres nummeriert"). [foundingYear] wird dabei aus dem
  /// bereits vorhandenen `createdAt` abgeleitet. Idempotent und günstig
  /// genug für einen einfachen Aufruf bei jedem Laden der Projektliste
  /// (gleiches Lazy-Prinzip wie `ExpenseCategoryRepository.
  /// seedDefaultsIfNeverSeeded()`) — betrifft nach dem ersten Lauf nie
  /// wieder etwas, da jedes neue Projekt seine Nummer schon bei
  /// [create] bekommt.
  Future<void> backfillProjectNumbersIfMissing(String companyId) async {
    final missing = await (_db.select(_db.projects)
          ..where((p) => p.companyId.equals(companyId) & p.projectNumber.isNull())
          ..orderBy([(p) => OrderingTerm.asc(p.createdAt)]))
        .get();
    if (missing.isEmpty) return;

    await _db.transaction(() async {
      for (final project in missing) {
        final foundingYear = project.createdAt.year;
        final projectNumber = await _numberSequences.allocateNext(
          companyId: companyId,
          documentType: projectNumberDocumentType,
          year: foundingYear,
        );
        await (_db.update(_db.projects)..where((p) => p.id.equals(project.id))).write(
          ProjectsCompanion(
            foundingYear: Value(foundingYear),
            projectNumber: Value(projectNumber),
          ),
        );
      }
    });
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
