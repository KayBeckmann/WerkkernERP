part of '../repository_postgres.dart';

mixin _PostgresPurchasing implements PurchasingStore {
  Future<Result> _q(String sql, [Map<String, Object?> parameters = const {}]);
  SessionExecutor get _db;
  Future<List<StockMovement>> _bookStockTx(TxSession s, String companyId, List<StockDelta> deltas, StockBookingContext context);
  static const _purchaseUuid = Uuid();

  static const _poColumns = 'id, company_id, supplier_id, status, number, number_year, issue_date, notes, '
      'supplier_snapshot_name, supplier_snapshot_address, finalized_at, source_order_id, project_id, '
      'expense_category_id, created_by_user_id, created_at, updated_at, version';

  PurchaseOrder _toPo(ResultRow r) => PurchaseOrder(
        id: r[0] as String,
        companyId: r[1] as String,
        supplierId: r[2] as String,
        status: r[3] as String,
        number: r[4] as String?,
        numberYear: r[5] as int?,
        issueDate: r[6] as DateTime,
        notes: r[7] as String?,
        supplierSnapshotName: r[8] as String?,
        supplierSnapshotAddress: r[9] as String?,
        finalizedAt: r[10] as DateTime?,
        sourceOrderId: r[11] as String?,
        projectId: r[12] as String?,
        expenseCategoryId: r[13] as String?,
        createdByUserId: r[14] as String,
        createdAt: r[15] as DateTime,
        updatedAt: r[16] as DateTime,
        version: r[17] as int,
      );

  PurchaseOrderItem _toPoItem(ResultRow r) => PurchaseOrderItem(
        id: r[0] as String,
        purchaseOrderId: r[1] as String,
        articleId: r[2] as String?,
        description: r[3] as String,
        quantity: r[4] as String,
        purchasePriceCents: r[5] as int?,
        receivedQuantity: r[6] as String,
        sortOrder: r[7] as int,
      );

  static const _poItemColumns = 'id, purchase_order_id, article_id, description, quantity, purchase_price_cents, '
      'received_quantity, sort_order';

  @override
  Future<List<PurchaseOrder>> listPurchaseOrders(String companyId, {String? status, String? sourceOrderId}) async {
    final result = await _q(
      'SELECT $_poColumns FROM purchase_orders WHERE company_id = @companyId '
      'AND (@status::text IS NULL OR status = @status) AND (@source::text IS NULL OR source_order_id = @source) '
      'ORDER BY created_at DESC',
      {'companyId': companyId, 'status': status, 'source': sourceOrderId},
    );
    return [for (final r in result) _toPo(r)];
  }

  @override
  Future<PurchaseOrder?> findPurchaseOrder(String companyId, String id) async {
    final result = await _q('SELECT $_poColumns FROM purchase_orders WHERE company_id = @companyId AND id = @id', {
      'companyId': companyId,
      'id': id,
    });
    return result.isEmpty ? null : _toPo(result.first);
  }

  @override
  Future<List<PurchaseOrderItem>> purchaseOrderItems(String companyId, String id) async {
    final result = await _q(
      'SELECT i.${_poItemColumns.replaceAll(', ', ', i.')} FROM purchase_order_items i '
      'JOIN purchase_orders o ON o.id = i.purchase_order_id WHERE o.company_id = @companyId AND o.id = @id '
      'ORDER BY i.sort_order',
      {'companyId': companyId, 'id': id},
    );
    return [for (final r in result) _toPoItem(r)];
  }

  Future<void> _insertPoItems(TxSession s, List<PurchaseOrderItem> items) async {
    for (final i in items) {
      await s.execute(
        Sql.named(
          'INSERT INTO purchase_order_items ($_poItemColumns) VALUES (@id, @poId, @articleId, @description, @quantity, '
          '@price, @received, @sortOrder)',
        ),
        parameters: {
          'id': i.id,
          'poId': i.purchaseOrderId,
          'articleId': i.articleId,
          'description': i.description,
          'quantity': i.quantity,
          'price': i.purchasePriceCents,
          'received': i.receivedQuantity,
          'sortOrder': i.sortOrder,
        },
      );
    }
  }

  @override
  Future<void> createPurchaseOrder(PurchaseOrder o, List<PurchaseOrderItem> items) => _db.runTx((s) async {
        await s.execute(
          Sql.named(
            'INSERT INTO purchase_orders ($_poColumns) VALUES (@id, @companyId, @supplierId, @status, NULL, NULL, @issueDate, '
            '@notes, NULL, NULL, NULL, @source, @projectId, @categoryId, @createdBy, @createdAt, @updatedAt, @version)',
          ),
          parameters: {
            'id': o.id,
            'companyId': o.companyId,
            'supplierId': o.supplierId,
            'status': o.status,
            'issueDate': TypedValue(Type.date, o.issueDate),
            'notes': o.notes,
            'source': o.sourceOrderId,
            'projectId': o.projectId,
            'categoryId': o.expenseCategoryId,
            'createdBy': o.createdByUserId,
            'createdAt': o.createdAt,
            'updatedAt': o.updatedAt,
            'version': o.version,
          },
        );
        await _insertPoItems(s, items);
      });

  Future<ResultRow?> _lockPoDraft(TxSession s, String companyId, String id, int expectedVersion) async {
    final result = await s.execute(
      Sql.named('SELECT status, version, supplier_id FROM purchase_orders WHERE company_id = @companyId AND id = @id FOR UPDATE'),
      parameters: {'companyId': companyId, 'id': id},
    );
    if (result.isEmpty) return null;
    final row = result.first;
    if (row[0] != 'draft') throw const BusinessConflict('Bestellung ist finalisiert und unveränderlich.');
    if (row[1] != expectedVersion) {
      throw BusinessConflict('Bestellung wurde zwischenzeitlich geändert (Version ${row[1]}, erwartet $expectedVersion).');
    }
    return row;
  }

  @override
  Future<PurchaseOrder?> updatePurchaseOrderDraft(PurchaseOrder o, List<PurchaseOrderItem> items, {required int expectedVersion}) async {
    final ok = await _db.runTx((s) async {
      if (await _lockPoDraft(s, o.companyId, o.id, expectedVersion) == null) return false;
      await s.execute(
        Sql.named(
          'UPDATE purchase_orders SET supplier_id = @supplierId, issue_date = @issueDate, notes = @notes, '
          'project_id = @projectId, expense_category_id = @categoryId, updated_at = @updatedAt, version = version + 1 '
          'WHERE id = @id',
        ),
        parameters: {
          'id': o.id,
          'supplierId': o.supplierId,
          'issueDate': TypedValue(Type.date, o.issueDate),
          'notes': o.notes,
          'projectId': o.projectId,
          'categoryId': o.expenseCategoryId,
          'updatedAt': o.updatedAt,
        },
      );
      await s.execute(Sql.named('DELETE FROM purchase_order_items WHERE purchase_order_id = @id'), parameters: {'id': o.id});
      await _insertPoItems(s, items);
      return true;
    });
    return ok ? findPurchaseOrder(o.companyId, o.id) : null;
  }

  @override
  Future<bool> deletePurchaseOrderDraft(String companyId, String id) async {
    final existing = await findPurchaseOrder(companyId, id);
    if (existing == null) return false;
    if (!existing.isDraft) throw const BusinessConflict('Nur Entwürfe können gelöscht werden.');
    final result = await _q("DELETE FROM purchase_orders WHERE company_id = @companyId AND id = @id AND status = 'draft'", {
      'companyId': companyId,
      'id': id,
    });
    return result.affectedRows > 0;
  }

  @override
  Future<PurchaseOrder?> finalizePurchaseOrder(String companyId, String id, {required int expectedVersion, required DateTime now}) async {
    final ok = await _db.runTx((s) async {
      if (await _lockPoDraft(s, companyId, id, expectedVersion) == null) return false;
      final count = await s.execute(
        Sql.named('SELECT count(*) FROM purchase_order_items WHERE purchase_order_id = @id'),
        parameters: {'id': id},
      );
      if ((count.first[0] as int) == 0) {
        throw const BusinessConflict('Eine Bestellung ohne Positionen kann nicht finalisiert werden.');
      }
      final sequence = await s.execute(
        Sql.named(
          'INSERT INTO number_sequences (company_id, document_type, year, last_number) VALUES (@companyId, @type, @year, 1) '
          'ON CONFLICT (company_id, document_type, year) DO UPDATE SET last_number = number_sequences.last_number + 1 '
          'RETURNING last_number',
        ),
        parameters: {'companyId': companyId, 'type': purchaseOrderSequenceType, 'year': now.year},
      );
      await s.execute(
        Sql.named(
          "UPDATE purchase_orders o SET status = 'finalized', number = @number, number_year = @year, finalized_at = @now, "
          'updated_at = @now, version = o.version + 1, supplier_snapshot_name = s.name, supplier_snapshot_address = s.address '
          'FROM suppliers s WHERE s.id = o.supplier_id AND o.id = @id',
        ),
        parameters: {
          'number': formatNumberWithPrefix(prefix: 'B', year: now.year, number: sequence.first.first as int),
          'year': now.year,
          'now': now,
          'id': id,
        },
      );
      return true;
    });
    return ok ? findPurchaseOrder(companyId, id) : null;
  }

  @override
  Future<PurchaseOrder?> receivePurchaseOrder(
    String companyId,
    String id, {
    required Map<String, Decimal> receipts,
    required String userId,
    required DateTime now,
  }) async {
    final ok = await _db.runTx((s) async {
      final head = await s.execute(
        Sql.named(
          'SELECT status, number, project_id, expense_category_id FROM purchase_orders '
          'WHERE company_id = @companyId AND id = @id FOR UPDATE',
        ),
        parameters: {'companyId': companyId, 'id': id},
      );
      if (head.isEmpty) return false;
      final status = head.first[0] as String;
      final number = head.first[1] as String?;
      if (status != 'finalized' && status != 'partiallyReceived') {
        throw const BusinessConflict('Wareneingang nur zu einer finalisierten, offenen Bestellung.');
      }
      final items = {
        for (final r in await s.execute(
          Sql.named('SELECT $_poItemColumns FROM purchase_order_items WHERE purchase_order_id = @id FOR UPDATE'),
          parameters: {'id': id},
        ))
          r[0] as String: _toPoItem(r),
      };
      for (final entry in receipts.entries) {
        final item = items[entry.key];
        if (item == null) throw BusinessConflict('Position ${entry.key} gehört nicht zu dieser Bestellung.');
        if (entry.value > item.open) {
          throw BusinessConflict('Wareneingang für "${item.description}" übersteigt die offene Menge (${item.open}).');
        }
      }
      var valueCents = 0;
      final deltas = <StockDelta>[];
      for (final entry in receipts.entries) {
        if (entry.value <= Decimal.zero) continue;
        final item = items[entry.key]!;
        final received = (Decimal.parse(item.receivedQuantity) + entry.value).toString();
        await s.execute(
          Sql.named('UPDATE purchase_order_items SET received_quantity = @received WHERE id = @id'),
          parameters: {'received': received, 'id': item.id},
        );
        items[item.id] = PurchaseOrderItem(
          id: item.id,
          purchaseOrderId: id,
          articleId: item.articleId,
          description: item.description,
          quantity: item.quantity,
          purchasePriceCents: item.purchasePriceCents,
          receivedQuantity: received,
          sortOrder: item.sortOrder,
        );
        if (item.purchasePriceCents != null) {
          valueCents += Money.fromCents(item.purchasePriceCents!).multiplyByQuantity(entry.value).cents;
        }
        if (item.articleId != null) deltas.add(StockDelta(item.articleId!, entry.value));
      }
      await _bookStockTx(
        s,
        companyId,
        deltas,
        StockBookingContext(type: 'purchaseOrderReceipt', userId: userId, now: now, referenceLabel: number),
      );
      if (valueCents > 0) {
        await s.execute(
          Sql.named(
            'INSERT INTO expenses (id, company_id, expense_date, description, amount_gross_cents, vat_rate_percent, '
            'category_id, supplier_reference, project_id, purchase_order_id, created_by_user_id, created_at, updated_at) '
            'VALUES (@id, @companyId, @date, @description, @amount, 0, @categoryId, @number, @projectId, @poId, @userId, @now, @now)',
          ),
          parameters: {
            'id': _purchaseUuid.v4(),
            'companyId': companyId,
            'date': TypedValue(Type.date, DateTime.utc(now.year, now.month, now.day)),
            'description': 'Wareneingang zu Bestellung ${number ?? id}',
            'amount': valueCents,
            'categoryId': head.first[3] as String?,
            'number': number,
            'projectId': head.first[2] as String?,
            'poId': id,
            'userId': userId,
            'now': now,
          },
        );
      }
      final all = items.values.every((i) => i.open <= Decimal.zero);
      final any = items.values.any((i) => Decimal.parse(i.receivedQuantity) > Decimal.zero);
      await s.execute(
        Sql.named('UPDATE purchase_orders SET status = @status, updated_at = @now, version = version + 1 WHERE id = @id'),
        parameters: {'status': all ? 'fullyReceived' : (any ? 'partiallyReceived' : status), 'now': now, 'id': id},
      );
      return true;
    });
    return ok ? findPurchaseOrder(companyId, id) : null;
  }
}
