import 'api_client.dart';

/// Fuhrpark online (C6).
class OnlineVehicle {
  const OnlineVehicle({
    required this.id,
    required this.name,
    this.licensePlate,
    this.notes,
    this.nextInspectionDate,
    this.active = true,
  });
  factory OnlineVehicle.fromJson(Map<String, Object?> j) => OnlineVehicle(
        id: j['id'] as String,
        name: j['name'] as String,
        licensePlate: j['licensePlate'] as String?,
        notes: j['notes'] as String?,
        nextInspectionDate: j['nextInspectionDate'] == null ? null : DateTime.parse(j['nextInspectionDate'] as String),
        active: j['active'] as bool,
      );
  final String id;
  final String name;
  final String? licensePlate;
  final String? notes;
  final DateTime? nextInspectionDate;
  final bool active;

  Map<String, Object?> toWriteJson() => {
        'name': name,
        'licensePlate': licensePlate,
        'notes': notes,
        'nextInspectionDate': nextInspectionDate == null ? null : onlineDate(nextInspectionDate!),
        'active': active,
      };
}

class OnlineVehicleCost {
  const OnlineVehicleCost({
    required this.id,
    required this.vehicleId,
    required this.date,
    required this.amountCents,
    required this.category,
    this.description,
    this.principalAmountCents,
    this.interestAmountCents,
    this.projectId,
  });
  factory OnlineVehicleCost.fromJson(Map<String, Object?> j) => OnlineVehicleCost(
        id: j['id'] as String,
        vehicleId: j['vehicleId'] as String,
        date: DateTime.parse(j['date'] as String),
        amountCents: j['amountCents'] as int,
        category: j['category'] as String,
        description: j['description'] as String?,
        principalAmountCents: j['principalAmountCents'] as int?,
        interestAmountCents: j['interestAmountCents'] as int?,
        projectId: j['projectId'] as String?,
      );
  final String id;
  final String vehicleId;
  final DateTime date;
  final int amountCents;
  final String category;
  final String? description;
  final int? principalAmountCents;
  final int? interestAmountCents;
  final String? projectId;
}

typedef OnlineVehicleCostTotals = ({int totalCents, Map<String, int> byCategory, int principalCents, int interestCents});

/// Datum als `JJJJ-MM-TT` für die API.
String onlineDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

extension FleetApi on WerkkernApiClient {
  Future<List<OnlineVehicle>> vehicles({bool includeInactive = false}) async {
    final j = await request('GET', '/vehicles', query: {if (includeInactive) 'includeInactive': 'true'}) as Map<String, Object?>;
    return [for (final v in j['vehicles'] as List) OnlineVehicle.fromJson(v as Map<String, Object?>)];
  }

  Future<OnlineVehicle> saveVehicle(OnlineVehicle vehicle) async => OnlineVehicle.fromJson((vehicle.id.isEmpty
      ? await request('POST', '/vehicles', body: vehicle.toWriteJson())
      : await request('PUT', '/vehicles/${vehicle.id}', body: vehicle.toWriteJson())) as Map<String, Object?>);

  Future<({List<OnlineVehicleCost> costs, OnlineVehicleCostTotals totals})> vehicleCosts({
    String? vehicleId,
    DateTime? from,
    DateTime? to,
  }) async {
    final j = await request('GET', '/vehicle-costs', query: {
      'vehicleId': ?vehicleId,
      if (from != null) 'from': onlineDate(from),
      if (to != null) 'to': onlineDate(to),
    }) as Map<String, Object?>;
    final t = j['totals'] as Map<String, Object?>;
    return (
      costs: [for (final c in j['costs'] as List) OnlineVehicleCost.fromJson(c as Map<String, Object?>)],
      totals: (
        totalCents: t['totalCents'] as int,
        byCategory: (t['byCategory'] as Map).cast<String, int>(),
        principalCents: t['principalCents'] as int,
        interestCents: t['interestCents'] as int,
      ),
    );
  }

  Future<void> addVehicleCost({
    required String vehicleId,
    required DateTime date,
    required int amountCents,
    required String category,
    String? description,
    int? principalAmountCents,
    int? interestAmountCents,
    String? projectId,
  }) =>
      request('POST', '/vehicle-costs', body: {
        'vehicleId': vehicleId,
        'date': onlineDate(date),
        'amountCents': amountCents,
        'category': category,
        'description': description,
        'principalAmountCents': principalAmountCents,
        'interestAmountCents': interestAmountCents,
        'projectId': projectId,
      });

  Future<void> deleteVehicleCost(String id) => request('DELETE', '/vehicle-costs/$id');
}
