import 'api_client.dart';

/// Rolle mit Stundensätzen (wie offline „Rollen & Stundensätze“). Eine
/// Zeitbuchung mit Rolle friert deren Kostensatz ein, sonst den des
/// Mitglieds. Der Verrechnungssatz (C3.4) ist der Preis für den Kunden.
class OnlineStaffRole {
  const OnlineStaffRole({
    required this.id,
    required this.name,
    required this.hourlyCostCents,
    this.hourlyBillingCents = 0,
  });
  factory OnlineStaffRole.fromJson(Map<String, Object?> j) => OnlineStaffRole(
        id: j['id'] as String,
        name: j['name'] as String,
        hourlyCostCents: j['hourlyCostCents'] as int,
        hourlyBillingCents: j['hourlyBillingCents'] as int? ?? 0,
      );
  final String id;
  final String name;
  final int hourlyCostCents;

  /// 0 = nicht hinterlegt.
  final int hourlyBillingCents;
}

extension StaffRoleApi on WerkkernApiClient {
  /// Für Admins legt der Server beim ersten Aufruf die Vorschläge
  /// Monteur/Meister/Projektleiter an (wie offline).
  Future<List<OnlineStaffRole>> staffRoles() async {
    final j = await request('GET', '/staff-roles') as Map<String, Object?>;
    return [for (final r in j['staffRoles'] as List) OnlineStaffRole.fromJson(r as Map<String, Object?>)];
  }

  Future<OnlineStaffRole> saveStaffRole({
    String? id,
    required String name,
    required int hourlyCostCents,
    int hourlyBillingCents = 0,
  }) async {
    final body = {'name': name, 'hourlyCostCents': hourlyCostCents, 'hourlyBillingCents': hourlyBillingCents};
    final j = await (id == null ? request('POST', '/staff-roles', body: body) : request('PUT', '/staff-roles/$id', body: body));
    return OnlineStaffRole.fromJson(j as Map<String, Object?>);
  }

  Future<void> deleteStaffRole(String id) => request('DELETE', '/staff-roles/$id');
}
