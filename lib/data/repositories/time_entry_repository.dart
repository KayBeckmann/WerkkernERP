import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/money.dart';
import '../database/database.dart';
import '../database/tables.dart';

/// Zeitbuchungen (C3 Zeiterfassung, Nachtrag 2026-10-20: "Der Monteur
/// muss seine Zeiten buchen können: Auftrag / Rechnung / Projekt") —
/// gleiche companyId-Isolation wie alle übrigen Repositories. Siehe
/// ausführlichen Doc-Kommentar bei [TimeEntries] in tables.dart für das
/// Datenmodell (insbesondere: kein Personenbezug, nur optional eine
/// Rolle).
class TimeEntryRepository {
  TimeEntryRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  Future<List<TimeEntry>> listForCompany(String companyId) =>
      (_db.select(_db.timeEntries)
            ..where((t) => t.companyId.equals(companyId))
            ..orderBy([(t) => OrderingTerm.desc(t.date)]))
          .get();

  Future<TimeEntry?> findById({required String companyId, required String id}) =>
      (_db.select(_db.timeEntries)..where((t) => t.id.equals(id) & t.companyId.equals(companyId)))
          .getSingleOrNull();

  Future<List<TimeEntry>> listForInvoice(String invoiceId) =>
      (_db.select(_db.timeEntries)
            ..where((t) => t.invoiceId.equals(invoiceId))
            ..orderBy([(t) => OrderingTerm.desc(t.date)]))
          .get();

  /// Alle Zeitbuchungen eines Projekts — über das zum Buchungszeitpunkt
  /// eingefrorene [TimeEntries.projectId] (siehe [create]), nicht
  /// dynamisch über eine evtl. seither geänderte Dokument-Zuordnung
  /// nachgeschlagen — gleiches Schnappschuss-Prinzip wie überall sonst
  /// in dieser App (z. B. `InventoryCountItems.expectedQuantity`).
  Future<List<TimeEntry>> listForProject({required String companyId, required String projectId}) =>
      (_db.select(_db.timeEntries)
            ..where((t) => t.companyId.equals(companyId) & t.projectId.equals(projectId))
            ..orderBy([(t) => OrderingTerm.desc(t.date)]))
          .get();

  Future<double> totalHoursForInvoice(String invoiceId) async {
    final entries = await listForInvoice(invoiceId);
    return entries.fold<double>(0.0, (sum, e) => sum + e.hours);
  }

  Future<double> totalHoursForProject({required String companyId, required String projectId}) async {
    final entries = await listForProject(companyId: companyId, projectId: projectId);
    return entries.fold<double>(0.0, (sum, e) => sum + e.hours);
  }

  /// Stundenkosten eines Projekts (Nachtrag 2026-10-20: "Gebuchte
  /// Zeiten bringen ... Kosten aber auch Gehälter") — Summe aus
  /// `hours × StaffRoles.hourlyCostRateCents` je Buchung mit gewählter
  /// Rolle. Buchungen ohne Rolle (Standalone-Normalfall) tragen 0 €
  /// bei, werden also nicht geschätzt/geraten.
  Future<Money> totalCostForProject({required String companyId, required String projectId}) async {
    final entries = await listForProject(companyId: companyId, projectId: projectId);
    var totalCents = 0;
    for (final entry in entries) {
      if (entry.staffRoleId == null) continue;
      final role =
          await (_db.select(_db.staffRoles)..where((r) => r.id.equals(entry.staffRoleId!)))
              .getSingleOrNull();
      if (role == null) continue;
      totalCents += (entry.hours * role.hourlyCostRateCents).round();
    }
    return Money.fromCents(totalCents);
  }

  /// Legt eine Zeitbuchung an. Mindestens eines von [invoiceId]/
  /// [projectId] ist Pflicht (wirft [ArgumentError], wenn beide fehlen —
  /// die Tabelle selbst erzwingt das nicht, siehe Doc-Kommentar bei
  /// [TimeEntries]). Ist [invoiceId] gesetzt und [projectId] nicht
  /// explizit angegeben, wird die Projektzuordnung des referenzierten
  /// Dokuments automatisch übernommen (überschreibbar durch explizites
  /// Setzen von [projectId]) — analog zum bestehenden Belege-
  /// Projektzuordnungs-Muster.
  Future<TimeEntry> create({
    required String companyId,
    required DateTime date,
    required double hours,
    String? staffRoleId,
    String? invoiceId,
    String? projectId,
    String? note,
  }) async {
    if (invoiceId == null && projectId == null) {
      throw ArgumentError('Eine Zeitbuchung braucht einen Auftrag/eine Rechnung oder ein Projekt.');
    }

    var resolvedProjectId = projectId;
    if (invoiceId != null && resolvedProjectId == null) {
      final invoice =
          await (_db.select(_db.invoices)..where((i) => i.id.equals(invoiceId))).getSingleOrNull();
      resolvedProjectId = invoice?.projectId;
    }

    final id = _uuid.v4();
    await _db.into(_db.timeEntries).insert(
          TimeEntriesCompanion.insert(
            id: id,
            companyId: companyId,
            date: date,
            hours: hours,
            staffRoleId: Value(staffRoleId),
            invoiceId: Value(invoiceId),
            projectId: Value(resolvedProjectId),
            note: Value(note),
            createdAt: DateTime.now(),
          ),
        );
    return (await findById(companyId: companyId, id: id))!;
  }

  /// C3-Rest (Nachtrag 2026-10-21) — ist die Buchung einem bereits
  /// `signed` [TimeSheet] zugeordnet, ist sie unveränderlich (F3-
  /// Prinzip, gleiche Begründung wie bei einer finalisierten Rechnung).
  /// Eine Korrektur geht nur über `TimeSheetRepository.
  /// createCorrectionDraft()` + eine neue Zeitbuchung, nie über eine
  /// stille Änderung dieser hier.
  Future<void> _assertNotLocked(TimeEntry entry) async {
    if (entry.timeSheetId == null) return;
    final sheet =
        await (_db.select(_db.timeSheets)..where((s) => s.id.equals(entry.timeSheetId!)))
            .getSingleOrNull();
    if (sheet?.status == TimeSheetStatus.signed) {
      throw StateError(
        'Zeitbuchung gehört zu einem bereits unterschriebenen Stundenzettel und ist '
        'unveränderlich — Korrektur über einen neuen Stundenzettel.',
      );
    }
  }

  Future<TimeEntry?> update({
    required String companyId,
    required String id,
    DateTime? date,
    double? hours,
    Value<String?> staffRoleId = const Value.absent(),
    Value<String?> invoiceId = const Value.absent(),
    Value<String?> projectId = const Value.absent(),
    Value<String?> note = const Value.absent(),
  }) async {
    final existing = await findById(companyId: companyId, id: id);
    if (existing == null) return null;
    await _assertNotLocked(existing);

    final nextInvoiceId = invoiceId.present ? invoiceId.value : existing.invoiceId;
    final nextProjectId = projectId.present ? projectId.value : existing.projectId;
    if (nextInvoiceId == null && nextProjectId == null) {
      throw ArgumentError('Eine Zeitbuchung braucht einen Auftrag/eine Rechnung oder ein Projekt.');
    }

    await (_db.update(_db.timeEntries)..where((t) => t.id.equals(id))).write(
      TimeEntriesCompanion(
        date: date == null ? const Value.absent() : Value(date),
        hours: hours == null ? const Value.absent() : Value(hours),
        staffRoleId: staffRoleId,
        invoiceId: invoiceId,
        projectId: projectId,
        note: note,
      ),
    );
    return findById(companyId: companyId, id: id);
  }

  Future<bool> delete({required String companyId, required String id}) async {
    final existing = await findById(companyId: companyId, id: id);
    if (existing == null) return false;
    await _assertNotLocked(existing);

    final rows = await (_db.delete(_db.timeEntries)
          ..where((t) => t.id.equals(id) & t.companyId.equals(companyId)))
        .go();
    return rows > 0;
  }
}
