/// Rollen & Stundensätze online (wie offline `StaffRoles`): frei
/// benennbare Stundensatz-Kategorien einer Firma, keine Personen. Eine
/// Zeitbuchung mit Rolle friert deren Satz ein; ohne Rolle gilt der Satz
/// des Mitglieds.
library;

/// Vorschläge wie offline — nur Namen, Satz startet bei 0.
const defaultStaffRoleNames = ['Monteur', 'Meister', 'Projektleiter'];

class StaffRole {
  const StaffRole({
    required this.id,
    required this.companyId,
    required this.name,
    required this.hourlyCostCents,
    this.hourlyBillingCents = 0,
    required this.createdAt,
  });
  final String id;
  final String companyId;
  final String name;
  final int hourlyCostCents;

  /// Verrechnungssatz (Preis je Stunde für den Kunden, C3.4) — 0 = nicht
  /// hinterlegt, siehe `resolveHourlyBillingRateCents` in werkkern_core.
  final int hourlyBillingCents;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'hourlyCostCents': hourlyCostCents,
        'hourlyBillingCents': hourlyBillingCents,
        'createdAt': createdAt.toIso8601String(),
      };
}

abstract interface class StaffRoleStore {
  Future<List<StaffRole>> listStaffRoles(String companyId);
  Future<StaffRole?> findStaffRole(String companyId, String id);
  Future<void> createStaffRole(StaffRole role);
  Future<bool> updateStaffRole(StaffRole role);

  /// Gebuchte Zeiten behalten ihren eingefrorenen Satz, verlieren nur
  /// den Rollenbezug.
  Future<bool> deleteStaffRole(String companyId, String id);
}
