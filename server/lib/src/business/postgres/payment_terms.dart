part of '../repository_postgres.dart';

mixin _PostgresPaymentTerms implements PaymentTermStore {
  Future<Result> _q(String sql, [Map<String, Object?> parameters = const {}]);

  PaymentTerm _toTerm(ResultRow r) => PaymentTerm(
        id: r[0] as String,
        companyId: r[1] as String,
        label: r[2] as String,
        netDays: r[3] as int,
        isDefault: r[4] as bool,
        sortOrder: r[5] as int,
      );

  @override
  Future<List<PaymentTerm>> listPaymentTerms(String companyId) async {
    final result = await _q(
      'SELECT id, company_id, label, net_days, is_default, sort_order FROM payment_terms '
      'WHERE company_id = @companyId ORDER BY sort_order, net_days',
      {'companyId': companyId},
    );
    return [for (final r in result) _toTerm(r)];
  }

  @override
  Future<void> savePaymentTerm(PaymentTerm t) async {
    await _q(
      'INSERT INTO payment_terms (id, company_id, label, net_days, is_default, sort_order) '
      'VALUES (@id, @companyId, @label, @days, @default, @sort) '
      'ON CONFLICT (id) DO UPDATE SET label = @label, net_days = @days, is_default = @default '
      'WHERE payment_terms.company_id = @companyId',
      {'id': t.id, 'companyId': t.companyId, 'label': t.label, 'days': t.netDays, 'default': t.isDefault, 'sort': t.sortOrder},
    );
  }

  @override
  Future<void> setDefaultPaymentTerm(String companyId, String id) async {
    await _q(
      'UPDATE payment_terms SET is_default = (id = @id) WHERE company_id = @companyId',
      {'companyId': companyId, 'id': id},
    );
  }

  @override
  Future<bool> deletePaymentTerm(String companyId, String id) async {
    final result = await _q(
      'DELETE FROM payment_terms WHERE company_id = @companyId AND id = @id',
      {'companyId': companyId, 'id': id},
    );
    if (result.affectedRows == 0) return false;
    await _q(
      'UPDATE customers SET payment_term_id = NULL WHERE company_id = @companyId AND payment_term_id = @id',
      {'companyId': companyId, 'id': id},
    );
    return true;
  }
}
