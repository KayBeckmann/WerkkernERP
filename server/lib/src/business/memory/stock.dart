part of '../repository_memory.dart';

mixin _InMemoryStock implements StockStore {
  List<Article> get _articles;
  final List<StockMovement> _stockMovements = [];
  final List<InventoryCount> _inventoryCounts = [];
  final List<InventoryCountItem> _inventoryItems = [];
  static const _stockUuid = Uuid();

  /// Ohne await zwischen Lesen und Schreiben — in Dart atomar wie die
  /// Zeilensperre in Postgres.
  List<StockMovement> _bookStockSync(String companyId, List<StockDelta> deltas, StockBookingContext context) {
    final movements = <StockMovement>[];
    for (final d in deltas) {
      if (d.delta == Decimal.zero) continue;
      final index = _articles.indexWhere((a) => a.companyId == companyId && a.id == d.articleId);
      if (index == -1) continue;
      final resulting = Decimal.parse(_articles[index].stockQuantity) + d.delta;
      _articles[index] = _articles[index].withStock(resulting.toString());
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
      _stockMovements.add(movement);
      movements.add(movement);
    }
    return movements;
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
      if (_inventoryItems.any((i) => i.inventoryCountId == countId && i.articleId == articleId)) continue;
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
      final article = _articles.firstWhere((a) => a.id == item.articleId);
      deltas.add(StockDelta(item.articleId, Decimal.parse(item.countedQuantity!) - Decimal.parse(article.stockQuantity)));
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
    );
    return movements;
  }
}
