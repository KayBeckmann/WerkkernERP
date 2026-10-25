part of '../repository_postgres.dart';

mixin _PostgresFleet implements FleetStore {
  Future<Result> _q(String sql, [Map<String, Object?> parameters = const {}]);

  static const _vehicleColumns = 'id, company_id, name, license_plate, notes, next_inspection_date, active, created_at';

  Vehicle _toVehicle(ResultRow r) => Vehicle(
        id: r[0] as String,
        companyId: r[1] as String,
        name: r[2] as String,
        licensePlate: r[3] as String?,
        notes: r[4] as String?,
        nextInspectionDate: r[5] as DateTime?,
        active: r[6] as bool,
        createdAt: r[7] as DateTime,
      );

  Map<String, Object?> _vehicleParams(Vehicle v) => {
        'id': v.id,
        'companyId': v.companyId,
        'name': v.name,
        'plate': v.licensePlate,
        'notes': v.notes,
        'inspection': TypedValue(Type.date, v.nextInspectionDate),
        'active': v.active,
        'createdAt': v.createdAt,
      };

  @override
  Future<List<Vehicle>> listVehicles(String companyId, {bool includeInactive = false}) async {
    final result = await _q(
      'SELECT $_vehicleColumns FROM vehicles WHERE company_id = @companyId AND (@all OR active) ORDER BY lower(name)',
      {'companyId': companyId, 'all': includeInactive},
    );
    return [for (final r in result) _toVehicle(r)];
  }

  @override
  Future<Vehicle?> findVehicle(String companyId, String id) async {
    final result = await _q('SELECT $_vehicleColumns FROM vehicles WHERE company_id = @companyId AND id = @id', {
      'companyId': companyId,
      'id': id,
    });
    return result.isEmpty ? null : _toVehicle(result.first);
  }

  @override
  Future<void> createVehicle(Vehicle vehicle) async {
    await _q(
      'INSERT INTO vehicles ($_vehicleColumns) VALUES (@id, @companyId, @name, @plate, @notes, @inspection, @active, @createdAt)',
      _vehicleParams(vehicle),
    );
  }

  @override
  Future<bool> updateVehicle(Vehicle vehicle) async {
    final result = await _q(
      'UPDATE vehicles SET name = @name, license_plate = @plate, notes = @notes, next_inspection_date = @inspection, '
      'active = @active WHERE company_id = @companyId AND id = @id',
      _vehicleParams(vehicle)..remove('createdAt'),
    );
    return result.affectedRows > 0;
  }

  static const _costColumns = 'id, company_id, vehicle_id, cost_date, amount_cents, category, description, '
      'principal_amount_cents, interest_amount_cents, project_id, created_by_user_id, created_at';

  VehicleCostEntry _toCost(ResultRow r) => VehicleCostEntry(
        id: r[0] as String,
        companyId: r[1] as String,
        vehicleId: r[2] as String,
        date: r[3] as DateTime,
        amountCents: r[4] as int,
        category: r[5] as String,
        description: r[6] as String?,
        principalAmountCents: r[7] as int?,
        interestAmountCents: r[8] as int?,
        projectId: r[9] as String?,
        createdByUserId: r[10] as String,
        createdAt: r[11] as DateTime,
      );

  @override
  Future<List<VehicleCostEntry>> listVehicleCosts(String companyId, {String? vehicleId, DateTime? from, DateTime? to}) async {
    final result = await _q(
      'SELECT $_costColumns FROM vehicle_costs WHERE company_id = @companyId '
      'AND (@vehicleId::text IS NULL OR vehicle_id = @vehicleId) '
      'AND (@from::date IS NULL OR cost_date >= @from) AND (@to::date IS NULL OR cost_date <= @to) '
      'ORDER BY cost_date DESC, created_at DESC',
      {
        'companyId': companyId,
        'vehicleId': vehicleId,
        'from': TypedValue(Type.date, from),
        'to': TypedValue(Type.date, to),
      },
    );
    return [for (final r in result) _toCost(r)];
  }

  @override
  Future<void> createVehicleCost(VehicleCostEntry e) async {
    await _q(
      'INSERT INTO vehicle_costs ($_costColumns) VALUES (@id, @companyId, @vehicleId, @date, @amount, @category, '
      '@description, @principal, @interest, @projectId, @createdBy, @createdAt)',
      {
        'id': e.id,
        'companyId': e.companyId,
        'vehicleId': e.vehicleId,
        'date': TypedValue(Type.date, e.date),
        'amount': e.amountCents,
        'category': e.category,
        'description': e.description,
        'principal': e.principalAmountCents,
        'interest': e.interestAmountCents,
        'projectId': e.projectId,
        'createdBy': e.createdByUserId,
        'createdAt': e.createdAt,
      },
    );
  }

  @override
  Future<bool> deleteVehicleCost(String companyId, String id) async {
    final result = await _q('DELETE FROM vehicle_costs WHERE company_id = @companyId AND id = @id', {
      'companyId': companyId,
      'id': id,
    });
    return result.affectedRows > 0;
  }
}
