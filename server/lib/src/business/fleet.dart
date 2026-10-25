/// Fuhrpark online (C6): Fahrzeuge und Kostenbuchungen. Kosten sind wie
/// offline **Gemeinkosten** — `projectId` ist reine Markierung und wird
/// nie in eine Projekt-Ergebnisrechnung summiert (Kay-Entscheidung
/// 2026-10-19).
library;

import 'request_util.dart';

const vehicleCostCategories = {'fuel', 'maintenance', 'leasing', 'insurance', 'other'};

class Vehicle {
  const Vehicle({
    required this.id,
    required this.companyId,
    required this.name,
    this.licensePlate,
    this.notes,
    this.nextInspectionDate,
    required this.active,
    required this.createdAt,
  });
  final String id;
  final String companyId;
  final String name;
  final String? licensePlate;
  final String? notes;

  /// Nächster TÜV-/HU-Termin.
  final DateTime? nextInspectionDate;
  final bool active;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'licensePlate': licensePlate,
        'notes': notes,
        'nextInspectionDate': nextInspectionDate == null ? null : dateJson(nextInspectionDate!),
        'active': active,
        'createdAt': createdAt.toIso8601String(),
      };
}

class VehicleCostEntry {
  const VehicleCostEntry({
    required this.id,
    required this.companyId,
    required this.vehicleId,
    required this.date,
    required this.amountCents,
    required this.category,
    this.description,
    this.principalAmountCents,
    this.interestAmountCents,
    this.projectId,
    required this.createdByUserId,
    required this.createdAt,
  });
  final String id;
  final String companyId;
  final String vehicleId;
  final DateTime date;

  /// Brutto-Gesamtbetrag der Buchung.
  final int amountCents;
  final String category;
  final String? description;

  /// Leasing/Finanzierung: optionale Aufteilung in Tilgung und Zins.
  final int? principalAmountCents;
  final int? interestAmountCents;
  final String? projectId;
  final String createdByUserId;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'vehicleId': vehicleId,
        'date': dateJson(date),
        'amountCents': amountCents,
        'category': category,
        'description': description,
        'principalAmountCents': principalAmountCents,
        'interestAmountCents': interestAmountCents,
        'projectId': projectId,
        'createdAt': createdAt.toIso8601String(),
      };
}

abstract interface class FleetStore {
  Future<List<Vehicle>> listVehicles(String companyId, {bool includeInactive = false});
  Future<Vehicle?> findVehicle(String companyId, String id);
  Future<void> createVehicle(Vehicle vehicle);
  Future<bool> updateVehicle(Vehicle vehicle);

  /// Kostenbuchungen der Firma, optional eines Fahrzeugs und/oder
  /// Zeitraums (inklusive Grenzen), neueste zuerst.
  Future<List<VehicleCostEntry>> listVehicleCosts(String companyId, {String? vehicleId, DateTime? from, DateTime? to});
  Future<void> createVehicleCost(VehicleCostEntry entry);
  Future<bool> deleteVehicleCost(String companyId, String id);
}
