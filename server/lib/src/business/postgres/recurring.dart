part of '../repository_postgres.dart';

mixin _PostgresRecurring implements RecurringStore {
  Future<Result> _q(String sql, [Map<String, Object?> parameters = const {}]);
  SessionExecutor get _db;
  Future<void> _insertDocumentTx(TxSession s, Document d, List<DocumentItem> items);

  static const _templateColumns = 'id, company_id, customer_id, label, recurrence_interval, next_due_date, payment_terms, '
      'notes, project_id, active, created_by_user_id, created_at';
  static const _templateItemColumns = 'id, template_id, kind, article_id, description, quantity, unit_price_cents, '
      'vat_rate_percent, unit, discount_percent, group_label, sort_order';

  RecurringTemplate _toTemplate(ResultRow r) => RecurringTemplate(
        id: r[0] as String,
        companyId: r[1] as String,
        customerId: r[2] as String,
        label: r[3] as String,
        interval: r[4] as String,
        nextDueDate: r[5] as DateTime,
        paymentTerms: r[6] as String?,
        notes: r[7] as String?,
        projectId: r[8] as String?,
        active: r[9] as bool,
        createdByUserId: r[10] as String,
        createdAt: r[11] as DateTime,
      );

  Map<String, Object?> _templateParams(RecurringTemplate t) => {
        'id': t.id,
        'companyId': t.companyId,
        'customerId': t.customerId,
        'label': t.label,
        'interval': t.interval,
        'due': TypedValue(Type.date, t.nextDueDate),
        'terms': t.paymentTerms,
        'notes': t.notes,
        'projectId': t.projectId,
        'active': t.active,
        'createdBy': t.createdByUserId,
        'createdAt': t.createdAt,
      };

  Future<void> _insertTemplateItems(TxSession s, List<DocumentItem> items) async {
    for (final i in items) {
      await s.execute(
        Sql.named(
          'INSERT INTO recurring_template_items ($_templateItemColumns) VALUES (@id, @templateId, @kind, @articleId, '
          '@description, @quantity, @price, @vat, @unit, @discount, @groupLabel, @sortOrder)',
        ),
        parameters: {
          'id': i.id,
          'templateId': i.documentId,
          'kind': i.kind,
          'articleId': i.articleId,
          'description': i.description,
          'quantity': i.quantity,
          'price': i.unitPriceCents,
          'vat': i.vatRatePercent,
          'unit': i.unit,
          'discount': i.discountPercent,
          'groupLabel': i.groupLabel,
          'sortOrder': i.sortOrder,
        },
      );
    }
  }

  @override
  Future<List<RecurringTemplate>> listRecurringTemplates(String companyId, {bool includeInactive = false}) async {
    final result = await _q(
      'SELECT $_templateColumns FROM recurring_templates WHERE company_id = @companyId AND (@all OR active) '
      'ORDER BY next_due_date',
      {'companyId': companyId, 'all': includeInactive},
    );
    return [for (final r in result) _toTemplate(r)];
  }

  @override
  Future<RecurringTemplate?> findRecurringTemplate(String companyId, String id) async {
    final result = await _q(
      'SELECT $_templateColumns FROM recurring_templates WHERE company_id = @companyId AND id = @id',
      {'companyId': companyId, 'id': id},
    );
    return result.isEmpty ? null : _toTemplate(result.first);
  }

  @override
  Future<List<DocumentItem>> recurringTemplateItems(String companyId, String templateId) async {
    final result = await _q(
      'SELECT i.id, i.template_id, i.kind, i.article_id, i.description, i.quantity, i.unit_price_cents, i.vat_rate_percent, '
      'i.unit, i.discount_percent, i.group_label, i.sort_order FROM recurring_template_items i '
      'JOIN recurring_templates t ON t.id = i.template_id WHERE t.company_id = @companyId AND t.id = @id ORDER BY i.sort_order',
      {'companyId': companyId, 'id': templateId},
    );
    return [
      for (final r in result)
        DocumentItem(
          id: r[0] as String,
          documentId: r[1] as String,
          kind: r[2] as String,
          articleId: r[3] as String?,
          description: r[4] as String,
          quantity: r[5] as String,
          unitPriceCents: r[6] as int,
          vatRatePercent: (r[7] as num).toDouble(),
          unit: r[8] as String?,
          discountPercent: (r[9] as num).toDouble(),
          groupLabel: r[10] as String?,
          sortOrder: r[11] as int,
        ),
    ];
  }

  @override
  Future<void> createRecurringTemplate(RecurringTemplate template, List<DocumentItem> items) => _db.runTx((s) async {
        await s.execute(
          Sql.named(
            'INSERT INTO recurring_templates ($_templateColumns) VALUES (@id, @companyId, @customerId, @label, @interval, @due, '
            '@terms, @notes, @projectId, @active, @createdBy, @createdAt)',
          ),
          parameters: _templateParams(template),
        );
        await _insertTemplateItems(s, items);
      });

  @override
  Future<bool> updateRecurringTemplate(RecurringTemplate template, List<DocumentItem> items) => _db.runTx((s) async {
        final result = await s.execute(
          Sql.named(
            'UPDATE recurring_templates SET customer_id = @customerId, label = @label, recurrence_interval = @interval, '
            'next_due_date = @due, payment_terms = @terms, notes = @notes, project_id = @projectId, active = @active '
            'WHERE company_id = @companyId AND id = @id',
          ),
          parameters: _templateParams(template)
            ..remove('createdBy')
            ..remove('createdAt'),
        );
        if (result.affectedRows == 0) return false;
        await s.execute(Sql.named('DELETE FROM recurring_template_items WHERE template_id = @id'), parameters: {'id': template.id});
        await _insertTemplateItems(s, items);
        return true;
      });

  @override
  Future<bool> deleteRecurringTemplate(String companyId, String id) async {
    final result = await _q('DELETE FROM recurring_templates WHERE company_id = @companyId AND id = @id', {
      'companyId': companyId,
      'id': id,
    });
    return result.affectedRows > 0;
  }

  @override
  Future<List<RecurringTemplate>> listDueRecurringTemplatesForJob(DateTime day) async {
    final result = await _q(
      'SELECT $_templateColumns FROM recurring_templates WHERE active AND next_due_date <= @day ORDER BY company_id, next_due_date',
      {'day': TypedValue(Type.date, day)},
    );
    return [for (final r in result) _toTemplate(r)];
  }

  @override
  Future<bool> generateRecurringDraft(
    RecurringTemplate template, {
    required DateTime expectedDueDate,
    required DateTime nextDueDate,
    required Document draft,
    required List<DocumentItem> items,
  }) =>
      _db.runTx((s) async {
        final claimed = await s.execute(
          Sql.named(
            'UPDATE recurring_templates SET next_due_date = @next WHERE id = @id AND company_id = @companyId '
            'AND next_due_date = @expected',
          ),
          parameters: {
            'next': TypedValue(Type.date, nextDueDate),
            'id': template.id,
            'companyId': template.companyId,
            'expected': TypedValue(Type.date, expectedDueDate),
          },
        );
        if (claimed.affectedRows == 0) return false;
        await _insertDocumentTx(s, draft, items);
        return true;
      });
}
