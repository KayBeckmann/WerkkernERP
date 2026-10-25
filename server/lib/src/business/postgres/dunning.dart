part of '../repository_postgres.dart';

mixin _PostgresDunning implements DunningStore {
  Future<Result> _q(String sql, [Map<String, Object?> parameters = const {}]);

  static const _noticeColumns = 'id, company_id, document_id, level, invoice_gross_cents, fee_cents, interest_cents, '
      'overdue_days, created_by_user_id, created_at, sent_at';

  DunningNotice _toNotice(ResultRow r) => DunningNotice(
        id: r[0] as String,
        companyId: r[1] as String,
        documentId: r[2] as String,
        level: r[3] as int,
        invoiceGrossCents: r[4] as int,
        feeCents: r[5] as int,
        interestCents: r[6] as int,
        overdueDays: r[7] as int,
        createdByUserId: r[8] as String,
        createdAt: r[9] as DateTime,
        sentAt: r[10] as DateTime?,
      );

  @override
  Future<List<DunningNotice>> listDunningNotices(String companyId, {String? documentId}) async {
    final result = await _q(
      'SELECT $_noticeColumns FROM dunning_notices WHERE company_id = @companyId '
      'AND (@documentId::text IS NULL OR document_id = @documentId) ORDER BY created_at DESC',
      {'companyId': companyId, 'documentId': documentId},
    );
    return [for (final r in result) _toNotice(r)];
  }

  @override
  Future<DunningNotice?> findDunningNotice(String companyId, String id) async {
    final result = await _q('SELECT $_noticeColumns FROM dunning_notices WHERE company_id = @companyId AND id = @id', {
      'companyId': companyId,
      'id': id,
    });
    return result.isEmpty ? null : _toNotice(result.first);
  }

  @override
  Future<void> createDunningNotice(DunningNotice n) async {
    await _q(
      'INSERT INTO dunning_notices ($_noticeColumns) VALUES (@id, @companyId, @documentId, @level, @gross, @fee, '
      '@interest, @days, @userId, @createdAt, NULL)',
      {
        'id': n.id,
        'companyId': n.companyId,
        'documentId': n.documentId,
        'level': n.level,
        'gross': n.invoiceGrossCents,
        'fee': n.feeCents,
        'interest': n.interestCents,
        'days': n.overdueDays,
        'userId': n.createdByUserId,
        'createdAt': n.createdAt,
      },
    );
  }

  @override
  Future<bool> markDunningNoticeSent(String companyId, String id, DateTime sentAt) async {
    final result = await _q('UPDATE dunning_notices SET sent_at = @sentAt WHERE company_id = @companyId AND id = @id', {
      'sentAt': sentAt,
      'companyId': companyId,
      'id': id,
    });
    return result.affectedRows > 0;
  }
}
