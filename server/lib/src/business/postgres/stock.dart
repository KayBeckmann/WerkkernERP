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
        Sql.named('SELECT stock_quantity, default_bin_id FROM articles WHERE company_id = @companyId AND id = @id FOR UPDATE'),
        parameters: {'companyId': companyId, 'id': d.articleId},
      );
      if (row.isEmpty) continue;
      var total = Decimal.parse(row.first[0] as String);
      final defaultBin = row.first[1] as String?;
      // C5.4: Platzbestände des Artikels (unter der Artikelsperre).
      final stocks = {
        for (final r in await s.execute(
          Sql.named('SELECT bin_key, quantity FROM article_bin_stock WHERE article_id = @id'),
          parameters: {'id': d.articleId},
        ))
          r[0] as String: Decimal.parse(r[1] as String),
      };
      final List<(String, Decimal)> legs;
      if (d.delta > Decimal.zero) {
        legs = [(d.binKey ?? defaultBin ?? unassignedBinKey, d.delta)];
      } else if (d.spread) {
        final preferred = d.binKey ?? suggestWithdrawalBin(stocks, defaultBin);
        legs = [for (final (bin, q) in planWithdrawal(stocks, -d.delta, preferred)) (bin, -q)];
      } else {
        legs = [(d.binKey ?? unassignedBinKey, d.delta)];
      }
      for (final (binKey, delta) in legs) {
        total += delta;
        final binQty = (stocks[binKey] ?? Decimal.zero) + delta;
        stocks[binKey] = binQty;
        if (binKey == unassignedBinKey && binQty == Decimal.zero) {
          await s.execute(
            Sql.named("DELETE FROM article_bin_stock WHERE article_id = @id AND bin_key = ''"),
            parameters: {'id': d.articleId},
          );
        } else {
          await s.execute(
            Sql.named(
              'INSERT INTO article_bin_stock (company_id, article_id, bin_key, quantity) VALUES (@companyId, @id, @bin, @q) '
              'ON CONFLICT (article_id, bin_key) DO UPDATE SET quantity = EXCLUDED.quantity',
            ),
            parameters: {'companyId': companyId, 'id': d.articleId, 'bin': binKey, 'q': binQty.toString()},
          );
        }
        final movement = StockMovement(
          id: _stockUuid.v4(),
          companyId: companyId,
          articleId: d.articleId,
          type: context.type,
          quantityDelta: delta.toString(),
          resultingQuantity: total.toString(),
          referenceLabel: context.referenceLabel,
          note: context.note,
          documentId: context.documentId,
          createdByUserId: context.userId,
          createdAt: context.now,
          binKey: binKey,
        );
        await s.execute(
          Sql.named(
            'INSERT INTO stock_movements (id, company_id, article_id, type, quantity_delta, resulting_quantity, '
            'reference_label, note, document_id, created_by_user_id, created_at, bin_key) VALUES (@id, @companyId, @articleId, '
            '@type, @delta, @resulting, @reference, @note, @documentId, @userId, @createdAt, @bin)',
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
            'bin': binKey,
          },
        );
        movements.add(movement);
      }
      await s.execute(
        Sql.named('UPDATE articles SET stock_quantity = @q WHERE company_id = @companyId AND id = @id'),
        parameters: {'q': total.toString(), 'companyId': companyId, 'id': d.articleId},
      );
    }
    return movements;
  }

  // ---- C5.4 Lagerorte und Plätze ---------------------------------------------

  @override
  Future<List<StorageLocation>> listStorageLocations(String companyId) async => [
        for (final r in await _q(
          'SELECT id, company_id, name, sort_order, created_at FROM storage_locations WHERE company_id = @companyId '
          'ORDER BY sort_order, name',
          {'companyId': companyId},
        ))
          StorageLocation(
            id: r[0] as String,
            companyId: r[1] as String,
            name: r[2] as String,
            sortOrder: r[3] as int,
            createdAt: r[4] as DateTime,
          ),
      ];

  @override
  Future<List<StorageBin>> listStorageBins(String companyId) async => [
        for (final r in await _q(
          'SELECT id, company_id, location_id, row_label, shelf, compartment, sort_order FROM storage_bins '
          'WHERE company_id = @companyId',
          {'companyId': companyId},
        ))
          StorageBin(
            id: r[0] as String,
            companyId: r[1] as String,
            locationId: r[2] as String,
            row: r[3] as String,
            shelf: r[4] as String,
            compartment: r[5] as String,
            sortOrder: r[6] as int,
          ),
      ]..sort(compareBinsInWalkOrder);

  @override
  Future<void> saveStorageLocation(StorageLocation location) async {
    await _q(
      'INSERT INTO storage_locations (id, company_id, name, sort_order, created_at) VALUES (@id, @companyId, @name, @sort, @createdAt) '
      'ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, sort_order = EXCLUDED.sort_order '
      'WHERE storage_locations.company_id = EXCLUDED.company_id',
      {
        'id': location.id,
        'companyId': location.companyId,
        'name': location.name,
        'sort': location.sortOrder,
        'createdAt': location.createdAt,
      },
    );
  }

  @override
  Future<void> saveStorageBin(StorageBin bin) async {
    await _q(
      'INSERT INTO storage_bins (id, company_id, location_id, row_label, shelf, compartment, sort_order) '
      'VALUES (@id, @companyId, @locationId, @row, @shelf, @compartment, @sort) '
      'ON CONFLICT (id) DO UPDATE SET location_id = EXCLUDED.location_id, row_label = EXCLUDED.row_label, '
      'shelf = EXCLUDED.shelf, compartment = EXCLUDED.compartment, sort_order = EXCLUDED.sort_order '
      'WHERE storage_bins.company_id = EXCLUDED.company_id',
      {
        'id': bin.id,
        'companyId': bin.companyId,
        'locationId': bin.locationId,
        'row': bin.row,
        'shelf': bin.shelf,
        'compartment': bin.compartment,
        'sort': bin.sortOrder,
      },
    );
  }

  Future<bool> _deleteBinsTx(TxSession s, String companyId, List<String> binIds) async {
    if (binIds.isEmpty) return true;
    final used = await s.execute(
      Sql.named("SELECT 1 FROM article_bin_stock WHERE company_id = @companyId AND bin_key = ANY(@ids) "
          "AND quantity::numeric <> 0 LIMIT 1"),
      parameters: {'companyId': companyId, 'ids': TypedValue(Type.textArray, binIds)},
    );
    if (used.isNotEmpty) return false;
    await s.execute(
      Sql.named('DELETE FROM article_bin_stock WHERE company_id = @companyId AND bin_key = ANY(@ids)'),
      parameters: {'companyId': companyId, 'ids': TypedValue(Type.textArray, binIds)},
    );
    await s.execute(
      Sql.named('UPDATE articles SET default_bin_id = NULL WHERE company_id = @companyId AND default_bin_id = ANY(@ids)'),
      parameters: {'companyId': companyId, 'ids': TypedValue(Type.textArray, binIds)},
    );
    await s.execute(
      Sql.named('DELETE FROM storage_bins WHERE company_id = @companyId AND id = ANY(@ids)'),
      parameters: {'companyId': companyId, 'ids': TypedValue(Type.textArray, binIds)},
    );
    return true;
  }

  @override
  Future<bool> deleteStorageBin(String companyId, String id) => _db.runTx((s) => _deleteBinsTx(s, companyId, [id]));

  @override
  Future<bool> deleteStorageLocation(String companyId, String id) => _db.runTx((s) async {
        final bins = await s.execute(
          Sql.named('SELECT id FROM storage_bins WHERE company_id = @companyId AND location_id = @id'),
          parameters: {'companyId': companyId, 'id': id},
        );
        if (!await _deleteBinsTx(s, companyId, [for (final r in bins) r[0] as String])) return false;
        await s.execute(
          Sql.named('DELETE FROM storage_locations WHERE company_id = @companyId AND id = @id'),
          parameters: {'companyId': companyId, 'id': id},
        );
        return true;
      });

  @override
  Future<List<ArticleBinStock>> listBinStocks(String companyId, {String? articleId}) async => [
        for (final r in await _q(
          'SELECT article_id, bin_key, quantity FROM article_bin_stock WHERE company_id = @companyId '
          'AND (@articleId::text IS NULL OR article_id = @articleId)',
          {'companyId': companyId, 'articleId': articleId},
        ))
          ArticleBinStock(articleId: r[0] as String, binKey: r[1] as String, quantity: r[2] as String),
      ];

  @override
  Future<Map<String, String>> defaultBins(String companyId) async => {
        for (final r in await _q(
          'SELECT id, default_bin_id FROM articles WHERE company_id = @companyId AND default_bin_id IS NOT NULL',
          {'companyId': companyId},
        ))
          r[0] as String: r[1] as String,
      };

  @override
  Future<void> setDefaultBin(String companyId, String articleId, String? binId) async {
    await _q('UPDATE articles SET default_bin_id = @bin WHERE company_id = @companyId AND id = @id', {
      'bin': binId,
      'companyId': companyId,
      'id': articleId,
    });
  }

  @override
  Future<bool> addInventoryBinItems(
    String companyId,
    String countId,
    List<({String articleId, String binKey})> entries, {
    required String Function() newId,
  }) =>
      _db.runTx((s) async {
        if (!await _isDraftCountTx(s, companyId, countId)) return false;
        for (final e in entries) {
          await s.execute(
            Sql.named(
              'INSERT INTO inventory_count_items (id, inventory_count_id, article_id, expected_quantity, bin_key) '
              "SELECT @id, @countId, a.id, coalesce((SELECT quantity FROM article_bin_stock b WHERE b.article_id = a.id "
              "AND b.bin_key = @bin), '0'), @bin FROM articles a WHERE a.company_id = @companyId AND a.id = @articleId "
              'ON CONFLICT DO NOTHING',
            ),
            parameters: {'id': newId(), 'countId': countId, 'companyId': companyId, 'articleId': e.articleId, 'bin': e.binKey},
          );
        }
        return true;
      });

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
        binKey: r.length > 11 ? r[11] as String? : null,
      );

  @override
  Future<List<StockMovement>> listStockMovements(String companyId, {String? articleId, int limit = 200}) async {
    final result = await _q(
      'SELECT id, company_id, article_id, type, quantity_delta, resulting_quantity, reference_label, note, document_id, '
      'created_by_user_id, created_at, bin_key FROM stock_movements WHERE company_id = @companyId '
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
        locationId: r[7] as String?,
      );

  static const _countColumns = 'id, company_id, label, count_date, status, completed_at, created_at, location_id';

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
      'SELECT i.id, i.inventory_count_id, i.article_id, i.expected_quantity, i.counted_quantity, i.counted_at, i.bin_key '
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
          binKey: r[6] as String?,
        ),
    ];
  }

  @override
  Future<void> createInventoryCount(InventoryCount count) async {
    await _q(
      'INSERT INTO inventory_counts ($_countColumns) VALUES (@id, @companyId, @label, @date, @status, NULL, @createdAt, @locationId)',
      {
        'id': count.id,
        'companyId': count.companyId,
        'label': count.label,
        'date': TypedValue(Type.date, count.date),
        'status': count.status,
        'createdAt': count.createdAt,
        'locationId': count.locationId,
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
              'AND NOT EXISTS (SELECT 1 FROM inventory_count_items x WHERE x.inventory_count_id = @countId '
              'AND x.article_id = @articleId AND x.bin_key IS NULL) ON CONFLICT DO NOTHING',
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
            'SELECT i.article_id, i.counted_quantity, a.stock_quantity, i.bin_key, '
            "coalesce((SELECT quantity FROM article_bin_stock b WHERE b.article_id = i.article_id AND b.bin_key = i.bin_key), '0') "
            'FROM inventory_count_items i '
            'JOIN articles a ON a.id = i.article_id WHERE i.inventory_count_id = @countId AND i.counted_quantity IS NOT NULL '
            'ORDER BY i.id FOR UPDATE OF a',
          ),
          parameters: {'countId': countId},
        );
        // C5.4: Platz-Positionen setzen den Platz auf die Zählung,
        // artikelweise Positionen den Gesamtbestand (Abgang verteilt).
        final deltas = [
          for (final r in items)
            if (r[3] != null)
              StockDelta(r[0] as String, Decimal.parse(r[1] as String) - Decimal.parse(r[4] as String), binKey: r[3] as String)
            else
              StockDelta(r[0] as String, Decimal.parse(r[1] as String) - Decimal.parse(r[2] as String), spread: true),
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
