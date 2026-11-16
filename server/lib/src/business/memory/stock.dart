part of '../repository_memory.dart';

mixin _InMemoryStock implements StockStore {
  List<Article> get _articles;
  final List<StockMovement> _stockMovements = [];
  final List<InventoryCount> _inventoryCounts = [];
  final List<InventoryCountItem> _inventoryItems = [];
  static const _stockUuid = Uuid();

  // C5.4: Lagerorte, Plätze, Platzbestände (articleId → binKey → Menge),
  // Standardplätze (articleId → binId).
  final List<StorageLocation> _storageLocations = [];
  final List<StorageBin> _storageBins = [];
  final Map<String, Map<String, Decimal>> _binStock = {};
  final Map<String, String> _defaultBin = {};

  Map<String, Decimal> _stocksOf(String articleId) => _binStock.putIfAbsent(articleId, () => {});

  /// Bucht die Teilbuchungen eines Deltas auf Plätze (siehe [StockDelta]).
  List<(String, Decimal)> _legsFor(StockDelta d) {
    final stocks = _stocksOf(d.articleId);
    final defaultBin = _defaultBin[d.articleId];
    if (d.delta > Decimal.zero) return [(d.binKey ?? defaultBin ?? unassignedBinKey, d.delta)];
    if (d.spread) {
      final preferred = d.binKey ?? suggestWithdrawalBin(stocks, defaultBin);
      return [for (final (bin, q) in planWithdrawal(stocks, -d.delta, preferred)) (bin, -q)];
    }
    return [(d.binKey ?? unassignedBinKey, d.delta)];
  }

  /// Ohne await zwischen Lesen und Schreiben — in Dart atomar wie die
  /// Zeilensperre in Postgres.
  List<StockMovement> _bookStockSync(String companyId, List<StockDelta> deltas, StockBookingContext context) {
    final movements = <StockMovement>[];
    for (final d in deltas) {
      if (d.delta == Decimal.zero) continue;
      final index = _articles.indexWhere((a) => a.companyId == companyId && a.id == d.articleId);
      if (index == -1) continue;
      for (final (binKey, delta) in _legsFor(d)) {
        final resulting = Decimal.parse(_articles[index].stockQuantity) + delta;
        _articles[index] = _articles[index].withStock(resulting.toString());
        final stocks = _stocksOf(d.articleId);
        stocks[binKey] = (stocks[binKey] ?? Decimal.zero) + delta;
        if (binKey == unassignedBinKey && stocks[binKey] == Decimal.zero) stocks.remove(binKey);
        final movement = StockMovement(
          id: _stockUuid.v4(),
          companyId: companyId,
          articleId: d.articleId,
          type: context.type,
          quantityDelta: delta.toString(),
          resultingQuantity: resulting.toString(),
          referenceLabel: context.referenceLabel,
          note: context.note,
          documentId: context.documentId,
          createdByUserId: context.userId,
          createdAt: context.now,
          binKey: binKey,
        );
        _stockMovements.add(movement);
        movements.add(movement);
      }
    }
    return movements;
  }

  @override
  Future<List<StorageLocation>> listStorageLocations(String companyId) async =>
      _storageLocations.where((l) => l.companyId == companyId).toList()
        ..sort((a, b) => a.sortOrder != b.sortOrder ? a.sortOrder.compareTo(b.sortOrder) : a.name.compareTo(b.name));

  @override
  Future<List<StorageBin>> listStorageBins(String companyId) async =>
      _storageBins.where((b) => b.companyId == companyId).toList()..sort(compareBinsInWalkOrder);

  @override
  Future<void> saveStorageLocation(StorageLocation location) async {
    _storageLocations
      ..removeWhere((l) => l.id == location.id)
      ..add(location);
  }

  @override
  Future<void> saveStorageBin(StorageBin bin) async {
    _storageBins
      ..removeWhere((b) => b.id == bin.id)
      ..add(bin);
  }

  bool _binHasStock(String binId) => _binStock.values.any((m) => (m[binId] ?? Decimal.zero) != Decimal.zero);

  void _releaseBin(String binId) {
    for (final m in _binStock.values) {
      m.remove(binId);
    }
    _defaultBin.removeWhere((_, v) => v == binId);
  }

  @override
  Future<bool> deleteStorageBin(String companyId, String id) async {
    if (!_storageBins.any((b) => b.companyId == companyId && b.id == id)) return true;
    if (_binHasStock(id)) return false;
    _releaseBin(id);
    _storageBins.removeWhere((b) => b.id == id);
    return true;
  }

  @override
  Future<bool> deleteStorageLocation(String companyId, String id) async {
    final bins = _storageBins.where((b) => b.companyId == companyId && b.locationId == id).toList();
    if (bins.any((b) => _binHasStock(b.id))) return false;
    for (final b in bins) {
      _releaseBin(b.id);
    }
    _storageBins.removeWhere((b) => b.companyId == companyId && b.locationId == id);
    _storageLocations.removeWhere((l) => l.companyId == companyId && l.id == id);
    return true;
  }

  @override
  Future<List<ArticleBinStock>> listBinStocks(String companyId, {String? articleId}) async => [
        for (final a in _articles.where((a) => a.companyId == companyId && (articleId == null || a.id == articleId)))
          for (final e in (_binStock[a.id] ?? const <String, Decimal>{}).entries)
            ArticleBinStock(articleId: a.id, binKey: e.key, quantity: e.value.toString()),
      ];

  @override
  Future<Map<String, String>> defaultBins(String companyId) async => {
        for (final a in _articles.where((a) => a.companyId == companyId))
          if (_defaultBin[a.id] != null) a.id: _defaultBin[a.id]!,
      };

  @override
  Future<void> setDefaultBin(String companyId, String articleId, String? binId) async {
    if (!_articles.any((a) => a.companyId == companyId && a.id == articleId)) return;
    if (binId == null) {
      _defaultBin.remove(articleId);
    } else {
      _defaultBin[articleId] = binId;
    }
  }

  @override
  Future<bool> addInventoryBinItems(
    String companyId,
    String countId,
    List<({String articleId, String binKey})> entries, {
    required String Function() newId,
  }) async {
    if (!_isDraftCount(companyId, countId)) return false;
    for (final e in entries) {
      if (_inventoryItems.any((i) => i.inventoryCountId == countId && i.articleId == e.articleId && i.binKey == e.binKey)) {
        continue;
      }
      if (!_articles.any((a) => a.companyId == companyId && a.id == e.articleId)) continue;
      _inventoryItems.add(InventoryCountItem(
        id: newId(),
        inventoryCountId: countId,
        articleId: e.articleId,
        expectedQuantity: (_binStock[e.articleId]?[e.binKey] ?? Decimal.zero).toString(),
        binKey: e.binKey,
      ));
    }
    return true;
  }

  @override
  Future<List<StockMovement>> bookStock(String companyId, List<StockDelta> deltas, StockBookingContext context) async =>
      _bookStockSync(companyId, deltas, context);

  @override
  Future<List<StockMovement>> listStockMovements(String companyId, {String? articleId, int limit = 200}) async =>
      (_stockMovements.where((m) => m.companyId == companyId && (articleId == null || m.articleId == articleId)).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt)))
          .take(limit)
          .toList();

  @override
  Future<List<InventoryCount>> listInventoryCounts(String companyId) async =>
      _inventoryCounts.where((c) => c.companyId == companyId).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<InventoryCount?> findInventoryCount(String companyId, String id) async =>
      _inventoryCounts.where((c) => c.companyId == companyId && c.id == id).firstOrNull;

  @override
  Future<List<InventoryCountItem>> inventoryItems(String companyId, String countId) async {
    if (await findInventoryCount(companyId, countId) == null) return const [];
    return _inventoryItems.where((i) => i.inventoryCountId == countId).toList();
  }

  @override
  Future<void> createInventoryCount(InventoryCount count) async => _inventoryCounts.add(count);

  bool _isDraftCount(String companyId, String countId) =>
      _inventoryCounts.any((c) => c.companyId == companyId && c.id == countId && c.isDraft);

  @override
  Future<bool> addInventoryArticles(String companyId, String countId, List<String> articleIds, {required String Function() newId}) async {
    if (!_isDraftCount(companyId, countId)) return false;
    for (final articleId in articleIds) {
      if (_inventoryItems.any((i) => i.inventoryCountId == countId && i.articleId == articleId && i.binKey == null)) continue;
      final article = _articles.where((a) => a.companyId == companyId && a.id == articleId).firstOrNull;
      if (article == null) continue;
      _inventoryItems.add(InventoryCountItem(
        id: newId(),
        inventoryCountId: countId,
        articleId: articleId,
        expectedQuantity: article.stockQuantity,
      ));
    }
    return true;
  }

  @override
  Future<bool> removeInventoryItem(String companyId, String countId, String itemId) async {
    if (!_isDraftCount(companyId, countId)) return false;
    final before = _inventoryItems.length;
    _inventoryItems.removeWhere((i) => i.inventoryCountId == countId && i.id == itemId);
    return _inventoryItems.length != before;
  }

  @override
  Future<bool> setInventoryCounted(String companyId, String countId, String itemId, String? counted, DateTime now) async {
    if (!_isDraftCount(companyId, countId)) return false;
    final index = _inventoryItems.indexWhere((i) => i.inventoryCountId == countId && i.id == itemId);
    if (index == -1) return false;
    final item = _inventoryItems[index];
    _inventoryItems[index] = InventoryCountItem(
      id: item.id,
      inventoryCountId: countId,
      articleId: item.articleId,
      expectedQuantity: item.expectedQuantity,
      countedQuantity: counted,
      countedAt: counted == null ? null : now,
      binKey: item.binKey,
    );
    return true;
  }

  @override
  Future<List<StockMovement>?> completeInventoryCount(String companyId, String countId, {required String userId, required DateTime now}) async {
    final index = _inventoryCounts.indexWhere((c) => c.companyId == companyId && c.id == countId && c.isDraft);
    if (index == -1) return null;
    final count = _inventoryCounts[index];
    final deltas = <StockDelta>[];
    for (final item in _inventoryItems.where((i) => i.inventoryCountId == countId && i.countedQuantity != null)) {
      final counted = Decimal.parse(item.countedQuantity!);
      if (item.binKey != null) {
        // C5.4: Platz auf die Zählung setzen.
        final current = _binStock[item.articleId]?[item.binKey!] ?? Decimal.zero;
        deltas.add(StockDelta(item.articleId, counted - current, binKey: item.binKey));
        continue;
      }
      final article = _articles.firstWhere((a) => a.id == item.articleId);
      deltas.add(StockDelta(item.articleId, counted - Decimal.parse(article.stockQuantity), spread: true));
    }
    final movements = _bookStockSync(
      companyId,
      deltas,
      StockBookingContext(type: 'inventoryCorrection', userId: userId, now: now, referenceLabel: count.label),
    );
    _inventoryCounts[index] = InventoryCount(
      id: count.id,
      companyId: companyId,
      label: count.label,
      date: count.date,
      status: 'completed',
      completedAt: now,
      createdAt: count.createdAt,
      locationId: count.locationId,
    );
    return movements;
  }
}
