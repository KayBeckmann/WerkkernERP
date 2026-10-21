import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';
import '../database/tables.dart';

/// Kunden-Stundenzettel mit Touch-Unterschrift (C3-Rest, Nachtrag
/// 2026-10-21) — gleiche companyId-Isolation wie alle übrigen
/// Repositories. Siehe ausführlichen Doc-Kommentar bei [TimeSheets] in
/// tables.dart für das Datenmodell und die Kay-Entscheidungen.
class TimeSheetRepository {
  TimeSheetRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  Future<List<TimeSheet>> listForCompany(String companyId) =>
      (_db.select(_db.timeSheets)
            ..where((s) => s.companyId.equals(companyId))
            ..orderBy([(s) => OrderingTerm.desc(s.date)]))
          .get();

  Future<TimeSheet?> findById({required String companyId, required String id}) =>
      (_db.select(_db.timeSheets)..where((s) => s.id.equals(id) & s.companyId.equals(companyId)))
          .getSingleOrNull();

  Future<List<TimeEntry>> entriesFor(String timeSheetId) =>
      (_db.select(_db.timeEntries)
            ..where((t) => t.timeSheetId.equals(timeSheetId))
            ..orderBy([(t) => OrderingTerm.asc(t.date)]))
          .get();

  /// Legt einen neuen Stundenzettel-Entwurf an. Mindestens eines von
  /// [invoiceId]/[projectId] ist Pflicht — gleiche Regel wie bei
  /// [TimeEntries] selbst (siehe `TimeEntryRepository.create()`).
  /// [initialEntryIds] (optional) ordnet bereits vorhandene, noch keinem
  /// ANDEREN Stundenzettel zugeordnete Zeitbuchungen gleich bei Anlage
  /// zu — weitere lassen sich danach über [addEntries] ergänzen, solange
  /// der Entwurf noch nicht unterschrieben ist.
  Future<TimeSheet> createDraft({
    required String companyId,
    required DateTime date,
    String? invoiceId,
    String? projectId,
    Set<String> initialEntryIds = const {},
  }) async {
    if (invoiceId == null && projectId == null) {
      throw ArgumentError('Ein Stundenzettel braucht einen Auftrag/eine Rechnung oder ein Projekt.');
    }
    return _db.transaction(() async {
      final id = _uuid.v4();
      await _db.into(_db.timeSheets).insert(
            TimeSheetsCompanion.insert(
              id: id,
              companyId: companyId,
              date: date,
              invoiceId: Value(invoiceId),
              projectId: Value(projectId),
              createdAt: DateTime.now(),
            ),
          );
      if (initialEntryIds.isNotEmpty) {
        await _assignEntries(companyId: companyId, timeSheetId: id, entryIds: initialEntryIds);
      }
      return (await findById(companyId: companyId, id: id))!;
    });
  }

  /// Ordnet weitere Zeitbuchungen einem noch nicht unterschriebenen
  /// Entwurf zu. Wirft [StateError], wenn der Stundenzettel bereits
  /// `signed` ist (unveränderlich, siehe Klassendoc bei [TimeSheets]).
  Future<void> addEntries({
    required String companyId,
    required String timeSheetId,
    required Set<String> entryIds,
  }) async {
    final sheet = await findById(companyId: companyId, id: timeSheetId);
    if (sheet == null) {
      throw StateError('Stundenzettel $timeSheetId existiert nicht in Firma $companyId.');
    }
    if (sheet.status == TimeSheetStatus.signed) {
      throw StateError('Ein unterschriebener Stundenzettel ist unveränderlich.');
    }
    await _assignEntries(companyId: companyId, timeSheetId: timeSheetId, entryIds: entryIds);
  }

  Future<void> _assignEntries({
    required String companyId,
    required String timeSheetId,
    required Set<String> entryIds,
  }) async {
    for (final entryId in entryIds) {
      final entry = await (_db.select(_db.timeEntries)
            ..where((t) => t.id.equals(entryId) & t.companyId.equals(companyId)))
          .getSingleOrNull();
      if (entry == null) continue;
      if (entry.timeSheetId != null) {
        final currentSheet = await (_db.select(_db.timeSheets)
              ..where((s) => s.id.equals(entry.timeSheetId!)))
            .getSingleOrNull();
        if (currentSheet?.status == TimeSheetStatus.signed) {
          throw StateError(
            'Zeitbuchung $entryId gehört bereits zu einem unterschriebenen Stundenzettel und '
            'kann nicht umgehängt werden.',
          );
        }
      }
      await (_db.update(_db.timeEntries)
            ..where((t) => t.id.equals(entryId) & t.companyId.equals(companyId)))
          .write(TimeEntriesCompanion(timeSheetId: Value(timeSheetId)));
    }
  }

  /// Löst eine Zeitbuchung wieder vom (noch nicht unterschriebenen)
  /// Entwurf, löscht sie aber nicht. Wirft [StateError], wenn der
  /// aktuell zugeordnete Stundenzettel bereits unterschrieben ist.
  Future<void> removeEntry({required String companyId, required String entryId}) async {
    final entry = await (_db.select(_db.timeEntries)
          ..where((t) => t.id.equals(entryId) & t.companyId.equals(companyId)))
        .getSingleOrNull();
    if (entry?.timeSheetId != null) {
      final sheet = await (_db.select(_db.timeSheets)
            ..where((s) => s.id.equals(entry!.timeSheetId!)))
          .getSingleOrNull();
      if (sheet?.status == TimeSheetStatus.signed) {
        throw StateError('Ein unterschriebener Stundenzettel ist unveränderlich.');
      }
    }
    await (_db.update(_db.timeEntries)
          ..where((t) => t.id.equals(entryId) & t.companyId.equals(companyId)))
        .write(const TimeEntriesCompanion(timeSheetId: Value(null)));
  }

  /// Unterschreiben — wirft [ArgumentError] ohne Positionen (ein leerer,
  /// unterschriebener Stundenzettel hätte keinen erkennbaren Zweck) und
  /// [StateError], wenn bereits unterschrieben. Ab hier sind sowohl der
  /// Stundenzettel selbst als auch alle zugeordneten [TimeEntries]
  /// unveränderlich (siehe `TimeEntryRepository.update()`/`delete()`).
  Future<TimeSheet> sign({
    required String companyId,
    required String id,
    required Uint8List signatureImage,
  }) async {
    return _db.transaction(() async {
      final sheet = await findById(companyId: companyId, id: id);
      if (sheet == null) {
        throw StateError('Stundenzettel $id existiert nicht in Firma $companyId.');
      }
      if (sheet.status == TimeSheetStatus.signed) {
        throw StateError('Stundenzettel ist bereits unterschrieben.');
      }
      final entries = await entriesFor(id);
      if (entries.isEmpty) {
        throw ArgumentError('Ein Stundenzettel ohne Zeitbuchungen kann nicht unterschrieben werden.');
      }
      if (signatureImage.isEmpty) {
        throw ArgumentError('Unterschrift fehlt.');
      }

      await (_db.update(_db.timeSheets)..where((s) => s.id.equals(id))).write(
        TimeSheetsCompanion(
          status: const Value(TimeSheetStatus.signed),
          signatureImage: Value(signatureImage),
          signedAt: Value(DateTime.now()),
        ),
      );
      return (await findById(companyId: companyId, id: id))!;
    });
  }

  /// Korrektur eines bereits unterschriebenen Stundenzettels (Kay-
  /// Entscheidung: "Korrektur nur über einen neuen, erneut zu
  /// unterschreibenden Nachtrag, nie stille Änderung") — legt einen
  /// NEUEN Entwurf mit [supersedesId] auf den alten an, übernimmt
  /// dessen Auftrags-/Rechnungs-/Projektzuordnung und Datum, aber
  /// **ohne** Zeitbuchungen (die alten bleiben unverändert dem alten,
  /// weiterhin `signed` bleibenden Stundenzettel zugeordnet). Der
  /// Monteur bucht die Korrektur als neue(n) Zeitbuchung(en) und ordnet
  /// sie diesem neuen Entwurf zu, der Kunde unterschreibt erneut.
  Future<TimeSheet> createCorrectionDraft({
    required String companyId,
    required String supersedesId,
  }) async {
    final original = await findById(companyId: companyId, id: supersedesId);
    if (original == null) {
      throw StateError('Stundenzettel $supersedesId existiert nicht in Firma $companyId.');
    }
    if (original.status != TimeSheetStatus.signed) {
      throw ArgumentError('Nur ein unterschriebener Stundenzettel kann korrigiert werden.');
    }

    final id = _uuid.v4();
    await _db.into(_db.timeSheets).insert(
          TimeSheetsCompanion.insert(
            id: id,
            companyId: companyId,
            date: original.date,
            invoiceId: Value(original.invoiceId),
            projectId: Value(original.projectId),
            supersedesId: Value(supersedesId),
            createdAt: DateTime.now(),
          ),
        );
    return (await findById(companyId: companyId, id: id))!;
  }
}
