part of '../repository_memory.dart';

mixin _InMemorySuppliers implements SupplierStore {
  List<Article> get _articles;
  List<DocumentItem> get _items;
  List<StockMovement> get _stockMovements;
  List<InventoryCountItem> get _inventoryItems;
  Map<String, Map<String, Decimal>> get _binStock;
  Map<String, String> get _defaultBin;
  List<PurchaseOrder> get _purchaseOrders;
  final List<Supplier> _suppliers = [];
  final List<ArticleGroup> _articleGroups = [];
  final Map<String, ({String companyId, ArticleSupplierPrice price})> _prices = {};

  String _priceKey(String articleId, String supplierId) => '$articleId|$supplierId';

  bool _contains(String text, String? query) =>
      query == null || query.isEmpty || text.toLowerCase().contains(query.toLowerCase());

  /// Artikelverweise wie Postgres `ON DELETE SET NULL` lösen.
  void _detachArticles(String companyId, {String? groupId, String? supplierId}) {
    for (var i = 0; i < _articles.length; i++) {
      final a = _articles[i];
      if (a.companyId != companyId) continue;
      if ((groupId != null && a.articleGroupId == groupId) || (supplierId != null && a.defaultSupplierId == supplierId)) {
        _articles[i] = a.withReferences(
          articleGroupId: a.articleGroupId == groupId ? null : a.articleGroupId,
          defaultSupplierId: a.defaultSupplierId == supplierId ? null : a.defaultSupplierId,
        );
      }
    }
  }

  @override
  Future<List<Supplier>> listSuppliers(String companyId, {String? query}) async =>
      _suppliers.where((s) => s.companyId == companyId && _contains(s.name, query)).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  @override
  Future<Supplier?> findSupplier(String companyId, String id) async =>
      _suppliers.where((s) => s.companyId == companyId && s.id == id).firstOrNull;

  @override
  Future<void> createSupplier(Supplier supplier) async => _suppliers.add(supplier);

  @override
  Future<bool> updateSupplier(Supplier supplier) async {
    final index = _suppliers.indexWhere((s) => s.companyId == supplier.companyId && s.id == supplier.id);
    if (index == -1) return false;
    _suppliers[index] = supplier;
    return true;
  }

  @override
  Future<bool> deleteSupplier(String companyId, String id) async {
    // Wie Postgres `ON DELETE RESTRICT` auf Bestellungen.
    if (_purchaseOrders.any((o) => o.companyId == companyId && o.supplierId == id)) {
      throw const BusinessConflict('Lieferant hat Bestellungen und kann nicht gelöscht werden.');
    }
    final before = _suppliers.length;
    _suppliers.removeWhere((s) => s.companyId == companyId && s.id == id);
    if (_suppliers.length == before) return false;
    _prices.removeWhere((_, v) => v.companyId == companyId && v.price.supplierId == id);
    _detachArticles(companyId, supplierId: id);
    return true;
  }

  @override
  Future<List<ArticleGroup>> listArticleGroups(String companyId) async =>
      _articleGroups.where((g) => g.companyId == companyId).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  @override
  Future<ArticleGroup?> findArticleGroup(String companyId, String id) async =>
      _articleGroups.where((g) => g.companyId == companyId && g.id == id).firstOrNull;

  @override
  Future<void> createArticleGroup(ArticleGroup group) async => _articleGroups.add(group);

  @override
  Future<bool> updateArticleGroup(ArticleGroup group) async {
    final index = _articleGroups.indexWhere((g) => g.companyId == group.companyId && g.id == group.id);
    if (index == -1) return false;
    _articleGroups[index] = group;
    return true;
  }

  @override
  Future<int?> articleGroupImpact(String companyId, String id) async =>
      _articleGroups.any((g) => g.companyId == companyId && g.id == id)
          ? _articles.where((a) => a.companyId == companyId && a.articleGroupId == id).length : null;

  @override
  Future<bool> deleteArticleGroup(String companyId, String id, {required bool deleteArticles, required int expectedCount}) async {
    final count = await articleGroupImpact(companyId, id);
    if (count == null) return false;
    if (count != expectedCount) throw const BusinessConflict('Artikelanzahl geändert. Bitte erneut prüfen.');
    if (deleteArticles) {
      // Historische Lagerbuchungen haben im Postgres-Schema RESTRICT.
      // Der In-Memory-Store darf solche Artikel ebenfalls nicht entfernen.
      if (_articles.any((a) => a.companyId == companyId && a.articleGroupId == id &&
          (_stockMovements.any((m) => m.articleId == a.id) ||
              _inventoryItems.any((i) => i.articleId == a.id)))) {
        throw const BusinessConflict('Artikel haben Lagerhistorie und können nicht gelöscht werden.');
      }
      if (_articles.any((a) => a.companyId == companyId && a.articleGroupId == id &&
          Decimal.parse(a.stockQuantity) != Decimal.zero)) {
        throw const BusinessConflict('Artikel haben Bestand und können nicht gelöscht werden.');
      }
      final ids = _articles.where((a) => a.companyId == companyId && a.articleGroupId == id).map((a) => a.id).toSet();
      // Postgres article FK is SET NULL; preserve all issued line snapshots.
      for (var i = 0; i < _items.length; i++) {
        final line = _items[i];
        if (ids.contains(line.articleId)) {
          _items[i] = DocumentItem(id: line.id, documentId: line.documentId, kind: line.kind,
              description: line.description, quantity: line.quantity, unitPriceCents: line.unitPriceCents,
              vatRatePercent: line.vatRatePercent, unit: line.unit, discountPercent: line.discountPercent,
              groupLabel: line.groupLabel, staffRoleId: line.staffRoleId, sortOrder: line.sortOrder);
        }
      }
      _articles.removeWhere((a) => ids.contains(a.id));
      _prices.removeWhere((_, v) => v.companyId == companyId && ids.contains(v.price.articleId));
      for (final articleId in ids) {
        _binStock.remove(articleId);
        _defaultBin.remove(articleId);
      }
    } else {
      _detachArticles(companyId, groupId: id);
    }
    _articleGroups.removeWhere((g) => g.companyId == companyId && g.id == id);
    return true;
  }

  @override
  Future<List<ArticleSupplierPrice>> listArticlePrices(String companyId, {String? articleId}) async => [
        for (final v in _prices.values)
          if (v.companyId == companyId && (articleId == null || v.price.articleId == articleId)) v.price,
      ];

  @override
  Future<void> setArticlePrice(String companyId, ArticleSupplierPrice price) async =>
      _prices[_priceKey(price.articleId, price.supplierId)] = (companyId: companyId, price: price);

  @override
  Future<bool> removeArticlePrice(String companyId, String articleId, String supplierId) async {
    final key = _priceKey(articleId, supplierId);
    if (_prices[key]?.companyId != companyId) return false;
    return _prices.remove(key) != null;
  }
}
