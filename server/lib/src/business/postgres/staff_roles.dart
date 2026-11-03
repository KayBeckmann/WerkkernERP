part of '../repository_postgres.dart';

mixin _PostgresStaffRoles implements StaffRoleStore {
  Future<Result> _q(String sql, [Map<String, Object?> parameters = const {}]);

  static const _roleColumns = 'id, company_id, name, hourly_cost_cents, created_at, hourly_billing_cents';

  StaffRole _toRole(ResultRow r) => StaffRole(
        id: r[0] as String,
        companyId: r[1] as String,
        name: r[2] as String,
        hourlyCostCents: r[3] as int,
        createdAt: r[4] as DateTime,
        hourlyBillingCents: r[5] as int,
      );

  @override
  Future<List<StaffRole>> listStaffRoles(String companyId) async {
    final result = await _q(
      'SELECT $_roleColumns FROM staff_roles WHERE company_id = @companyId ORDER BY lower(name)',
      {'companyId': companyId},
    );
    return [for (final r in result) _toRole(r)];
  }

  @override
  Future<StaffRole?> findStaffRole(String companyId, String id) async {
    final result = await _q(
      'SELECT $_roleColumns FROM staff_roles WHERE company_id = @companyId AND id = @id',
      {'companyId': companyId, 'id': id},
    );
    return result.isEmpty ? null : _toRole(result.first);
  }

  @override
  Future<void> createStaffRole(StaffRole r) async {
    await _q(
      'INSERT INTO staff_roles ($_roleColumns) VALUES (@id, @companyId, @name, @rate, @createdAt, @billing)',
      {
        'id': r.id,
        'companyId': r.companyId,
        'name': r.name,
        'rate': r.hourlyCostCents,
        'createdAt': r.createdAt,
        'billing': r.hourlyBillingCents,
      },
    );
  }

  @override
  Future<bool> updateStaffRole(StaffRole r) async {
    final result = await _q(
      'UPDATE staff_roles SET name = @name, hourly_cost_cents = @rate, hourly_billing_cents = @billing '
      'WHERE company_id = @companyId AND id = @id',
      {'id': r.id, 'companyId': r.companyId, 'name': r.name, 'rate': r.hourlyCostCents, 'billing': r.hourlyBillingCents},
    );
    return result.affectedRows > 0;
  }

  @override
  Future<bool> deleteStaffRole(String companyId, String id) async {
    final result = await _q('DELETE FROM staff_roles WHERE company_id = @companyId AND id = @id', {
      'companyId': companyId,
      'id': id,
    });
    return result.affectedRows > 0;
  }
}
