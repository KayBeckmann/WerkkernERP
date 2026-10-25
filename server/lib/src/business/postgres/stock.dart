part of '../repository_postgres.dart';

mixin _PostgresStock implements StockStore {
  Future<Result> _q(String sql, [Map<String, Object?> parameters = const {}]);
  SessionExecutor get _db;
  static const _stockUuid = Uuid();

  /// Bucht innerhalb einer bestehenden Transaktion — Artikel werden per
  /// `FOR UPDATE` gesperrt, die Rechnung läuft exakt in [Decimal].
  Future<List<StockMovement>> _bookStockTx(
    TxSession s,
    String companyId,
    List<StockDelta> deltas,
    StockBookingContext context,
  ) async {
    final movements = <StockMovement>[];
    for (final d in deltas) {
      if (d.delta == Decimal.zero) continue;
      final row = await s.execute(
        Sql.named('SELECT stock_quantity FROM articles WHERE company_id = @companyId AND id = @id FOR UPDATE'),
        parameters: {'companyId': companyId, 'id': d.articleId},
      );
      if (row.isEmpty) continue;
      final resulting = Decimal.parse(row.first[0] as String) + d.delta;
      await s.execute(
        Sql.named('UPDATE articles SET stock_quantity = @q WHERE company_id = @companyId AND id = @id'),
        parameters: {'q': resulting.toString(), 'companyId': companyId, 'id': d.articleId},
      );
      final movement = StockMovement(
        id: _stockUuid.v4(),
        companyId: companyId,
        articleId: d.articleId,
        type: context.type,
        quantityDelta: d.delta.toString(),
        resultingQuantity: resulting.toString(),
        referenceLabel: context.referenceLabel,
        note: context.note,
        documentId: context.documentId,
        createdByUserId: context.userId,
        createdAt: context.now,
      );
      await s.execute(
        Sql.named(
          'INSERT INTO stock_movements (id, company_id, article_id, type, quantity_delta, resulting_quantity, '
          'reference_label, note, document_id, created_by_user_id, created_at) VALUES (@id, @companyId, @articleId, '
          '@type, @delta, @resulting, @reference, @note, @documentId, @userId, @createdAt)',
        ),
        parameters: {
          'id': movement.id,
          'companyId': companyId,
          'articleId': movement.articleId,
          'type': movement.type,
          'delta': movement.quantityDelta,
          'resulting': movement.resultingQuantity,
          'reference': movement.referenceLabel,
          'note': movement.note,
          'documentId': movement.documentId,
          'userId': movement.createdByUserId,
          'createdAt': movement.createdAt,
        },
      );
      movements.add(movement);
    }
    return movements;
  }

  @override
  Future<List<StockMovement>> bookStock(String companyId, List<StockDelta> deltas, StockBookingContext context) =>
      _db.runTx((s) => _bookStockTx(s, companyId, deltas, context));

  StockMovement _toMovement(ResultRow r) => StockMovement(
        id: r[0] as String,
        companyId: r[1] as String,
        articleId: r[2] as String,
        type: r[3] as String,
        quantityDelta: r[4] as String,
        resultingQuantity: r[5] as String,
        referenceLabel: r[6] as String?,
        note: r[7] as String?,
        documentId: r[8] as String?,
        createdByUserId: r[9] as String,
        createdAt: r[10] as DateTime,
      );

  @override
  Future<List<StockMovement>> listStockMovements(String companyId, {String? articleId, int limit = 200}) async {
    final result = await _q(
      'SELECT id, company_id, article_id, type, quantity_delta, resulting_quantity, reference_label, note, document_id, '
      'created_by_user_id, created_at FROM stock_movements WHERE company_id = @companyId '
      'AND (@articleId::text IS NULL OR article_id = @articleId) ORDER BY created_at DESC, id LIMIT @limit',
      {'companyId': companyId, 'articleId': articleId, 'limit': limit},
    );
    return [for (final r in result) _toMovement(r)];
  }

  InventoryCount _toCount(ResultRow r) => InventoryCount(
        id: r[0] as String,
        companyId: r[1] as String,
        label: r[2] as String,
        date: r[3] as DateTime,
        status: r[4] as String,
        completedAt: r[5] as DateTime?,
        createdAt: r[6] as DateTime,
      );

  static const _countColumns = 'id, company_id, label, count_date, status, completed_at, created_at';

  @override
  Future<List<InventoryCount>> listInventoryCounts(String companyId) async {
    final result = await _q(
      'SELECT $_countColumns FROM inventory_counts WHERE company_id = @companyId ORDER BY created_at DESC',
      {'companyId': companyId},
    );
    return [for (final r in result) _toCount(r)];
  }

  @override
  Future<InventoryCount?> findInventoryCount(String companyId, String id) async {
    final result = await _q('SELECT $_countColumns FROM inventory_counts WHERE company_id = @companyId AND id = @id', {
      'companyId': companyId,
      'id': id,
    });
    return result.isEmpty ? null : _toCount(result.first);
  }

  @override
  Future<List<InventoryCountItem>> inventoryItems(String companyId, String countId) async {
    final result = await _q(
      'SELECT i.id, i.inventory_count_id, i.article_id, i.expected_quantity, i.counted_quantity, i.counted_at '
      'FROM inventory_count_items i JOIN inventory_counts c ON c.id = i.inventory_count_id '
      'WHERE c.company_id = @companyId AND c.id = @countId ORDER BY i.id',
      {'companyId': companyId, 'countId': countId},
    );
    return [
      for (final r in result)
        InventoryCountItem(
          id: r[0] as String,
          inventoryCountId: r[1] as String,
          articleId: r[2] as String,
          expectedQuantity: r[3] as String,
          countedQuantity: r[4] as String?,
          countedAt: r[5] as DateTime?,
        ),
    ];
  }

  @override
  Future<void> createInventoryCount(InventoryCount count) async {
    await _q(
      'INSERT INTO inventory_counts ($_countColumns) VALUES (@id, @companyId, @label, @date, @status, NULL, @createdAt)',
      {
        'id': count.id,
        'companyId': count.companyId,
        'label': count.label,
        'date': TypedValue(Type.date, count.date),
        'status': count.status,
        'createdAt': count.createdAt,
      },
    );
  }

  Future<bool> _isDraftCountTx(TxSession s, String companyId, String countId) async {
    final row = await s.execute(
      Sql.named("SELECT 1 FROM inventory_counts WHERE company_id = @companyId AND id = @id AND status = 'draft' FOR UPDATE"),
      parameters: {'companyId': companyId, 'id': countId},
    );
    return row.isNotEmpty;
  }

  @override
  Future<bool> addInventoryArticles(String companyId, String countId, List<String> articleIds, {required String Function() newId}) =>
      _db.runTx((s) async {
        if (!await _isDraftCountTx(s, companyId, countId)) return false;
        for (final articleId in articleIds) {
          await s.execute(
            Sql.named(
              'INSERT INTO inventory_count_items (id, inventory_count_id, article_id, expected_quantity) '
              'SELECT @id, @countId, a.id, a.stock_quantity FROM articles a WHERE a.company_id = @companyId AND a.id = @articleId '
              'ON CONFLICT (inventory_count_id, article_id) DO NOTHING',
            ),
            parameters: {'id': newId(), 'countId': countId, 'companyId': companyId, 'articleId': articleId},
          );
        }
        return true;
      });

  @override
  Future<bool> removeInventoryItem(String companyId, String countId, String itemId) => _db.runTx((s) async {
        if (!await _isDraftCountTx(s, companyId, countId)) return false;
        final result = await s.execute(
          Sql.named('DELETE FROM inventory_count_items WHERE inventory_count_id = @countId AND id = @id'),
          parameters: {'countId': countId, 'id': itemId},
        );
        return result.affectedRows > 0;
      });

  @override
  Future<bool> setInventoryCounted(String companyId, String countId, String itemId, String? counted, DateTime now) =>
      _db.runTx((s) async {
        if (!await _isDraftCountTx(s, companyId, countId)) return false;
        final result = await s.execute(
          Sql.named(
            'UPDATE inventory_count_items SET counted_quantity = @counted, counted_at = @at '
            'WHERE inventory_count_id = @countId AND id = @id',
          ),
          parameters: {'counted': counted, 'at': counted == null ? null : now, 'countId': countId, 'id': itemId},
        );
        return result.affectedRows > 0;
      });

  @override
  Future<List<StockMovement>?> completeInventoryCount(String companyId, String countId, {required String userId, required DateTime now}) =>
      _db.runTx((s) async {
        final count = await s.execute(
          Sql.named(
            "SELECT label FROM inventory_counts WHERE company_id = @companyId AND id = @id AND status = 'draft' FOR UPDATE",
          ),
          parameters: {'companyId': companyId, 'id': countId},
        );
        if (count.isEmpty) return null;
        final items = await s.execute(
          Sql.named(
            'SELECT i.article_id, i.counted_quantity, a.stock_quantity FROM inventory_count_items i '
            'JOIN articles a ON a.id = i.article_id WHERE i.inventory_count_id = @countId AND i.counted_quantity IS NOT NULL '
            'ORDER BY i.id FOR UPDATE OF a',
          ),
          parameters: {'countId': countId},
        );
        final deltas = [
          for (final r in items) StockDelta(r[0] as String, Decimal.parse(r[1] as String) - Decimal.parse(r[2] as String)),
        ];
        final movements = await _bookStockTx(
          s,
          companyId,
          deltas,
          StockBookingContext(type: 'inventoryCorrection', userId: userId, now: now, referenceLabel: count.first[0] as String),
        );
        await s.execute(
          Sql.named("UPDATE inventory_counts SET status = 'completed', completed_at = @now WHERE id = @id"),
          parameters: {'now': now, 'id': countId},
        );
        return movements;
      });
}
