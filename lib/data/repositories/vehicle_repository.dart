import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';
import '../database/tables.dart';

/// Fahrzeuge und ihre Kostenbuchungen je Firma (C6-Kern, Kay-
/// Priorisierungsentscheidung 2026-10-17) — gleiche companyId-Isolation
/// wie alle übrigen A0-Repositories. Keine Umlage/Summierung in eine
/// Projekt-Ergebnisrechnung (siehe Doc-Kommentar bei [Vehicles] in
/// tables.dart).
class VehicleRepository {
  VehicleRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  Future<List<Vehicle>> listForCompany(String companyId, {bool includeInactive = false}) {
    final query = _db.select(_db.vehicles)..where((v) => v.companyId.equals(companyId));
    if (!includeInactive) {
      query.where((v) => v.active.equals(true));
    }
    query.orderBy([(v) => OrderingTerm.asc(v.name)]);
    return query.get();
  }

  Future<Vehicle?> findById({required String companyId, required String id}) =>
      (_db.select(_db.vehicles)..where((v) => v.id.equals(id) & v.companyId.equals(companyId)))
          .getSingleOrNull();

  Future<Vehicle> create({
    required String companyId,
    required String name,
    String? licensePlate,
    String? notes,
    DateTime? nextInspectionDate,
  }) async {
    final id = _uuid.v4();
    await _db.into(_db.vehicles).insert(
          VehiclesCompanion.insert(
            id: id,
            companyId: companyId,
            name: name,
            licensePlate: Value(licensePlate),
            notes: Value(notes),
            nextInspectionDate: Value(nextInspectionDate),
            createdAt: DateTime.now(),
          ),
        );
    return (await findById(companyId: companyId, id: id))!;
  }

  /// Deaktivieren statt löschen (gleiches Prinzip wie die Modul-
  /// Schalter/Projekte) — bereits erfasste Kostenbuchungen bleiben
  /// unangetastet, das Fahrzeug verschwindet nur aus Auswahllisten.
  Future<bool> setActive({required String companyId, required String id, required bool active}) async {
    final rows = await (_db.update(_db.vehicles)
          ..where((v) => v.id.equals(id) & v.companyId.equals(companyId)))
        .write(VehiclesCompanion(active: Value(active)));
    return rows > 0;
  }

  Future<List<VehicleCostEntry>> listCostsForVehicle({
    required String companyId,
    required String vehicleId,
  }) =>
      (_db.select(_db.vehicleCostEntries)
            ..where((c) => c.companyId.equals(companyId) & c.vehicleId.equals(vehicleId))
            ..orderBy([(c) => OrderingTerm.desc(c.date)]))
          .get();

  /// Alle Kostenbuchungen einer Firma, über ALLE Fahrzeuge hinweg — für
  /// die C14.3 EÜR-Übersicht (Kay-Entscheidung 2026-10-19: "Fuhrpark
  /// wird auf Gemeinkosten gerechnet, nicht auf die Projekte"). Bewusst
  /// ohne Projektfilter — [VehicleCostEntry.projectId] bleibt reine
  /// Markierung, siehe Doc-Kommentar bei [Vehicles] in tables.dart.
  Future<List<VehicleCostEntry>> listAllCostsForCompany(String companyId) =>
      (_db.select(_db.vehicleCostEntries)
            ..where((c) => c.companyId.equals(companyId))
            ..orderBy([(c) => OrderingTerm.desc(c.date)]))
          .get();

  Future<VehicleCostEntry> addCostEntry({
    required String companyId,
    required String vehicleId,
    required DateTime date,
    required int amountCents,
    required VehicleCostCategory category,
    String? description,
    String? projectId,
  }) async {
    final id = _uuid.v4();
    await _db.into(_db.vehicleCostEntries).insert(
          VehicleCostEntriesCompanion.insert(
            id: id,
            companyId: companyId,
            vehicleId: vehicleId,
            date: date,
            amountCents: amountCents,
            category: category,
            description: Value(description),
            projectId: Value(projectId),
            createdAt: DateTime.now(),
          ),
        );
    return (_db.select(_db.vehicleCostEntries)..where((c) => c.id.equals(id))).getSingle();
  }
}
