import 'api_client.dart';
import 'fleet.dart' show onlineDate;
import 'models.dart';

/// Lager online (C5.1/C5.3).
class OnlineStockMovement {
  const OnlineStockMovement({
    required this.id,
    required this.articleId,
    this.articleName,
    required this.type,
    required this.quantityDelta,
    required this.resultingQuantity,
    this.referenceLabel,
    this.note,
    required this.createdAt,
    this.binKey,
  });
  factory OnlineStockMovement.fromJson(Map<String, Object?> j) => OnlineStockMovement(
        binKey: j['binKey'] as String?,
        id: j['id'] as String,
        articleId: j['articleId'] as String,
        articleName: j['articleName'] as String?,
        type: j['type'] as String,
        quantityDelta: j['quantityDelta'] as String,
        resultingQuantity: j['resultingQuantity'] as String,
        referenceLabel: j['referenceLabel'] as String?,
        note: j['note'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
  final String id;
  final String articleId;
  final String? articleName;
  final String type;
  final String quantityDelta;
  final String resultingQuantity;
  final String? referenceLabel;
  final String? note;
  final DateTime createdAt;
  final String? binKey;
}

class OnlineInventoryItem {
  const OnlineInventoryItem({
    required this.id,
    required this.articleId,
    this.articleName,
    this.unit,
    required this.expectedQuantity,
    this.countedQuantity,
    this.currentQuantity,
    this.binKey,
    this.binLabel,
  });
  factory OnlineInventoryItem.fromJson(Map<String, Object?> j) => OnlineInventoryItem(
        binKey: j['binKey'] as String?,
        binLabel: j['binLabel'] as String?,
        id: j['id'] as String,
        articleId: j['articleId'] as String,
        articleName: j['articleName'] as String?,
        unit: j['unit'] as String?,
        expectedQuantity: j['expectedQuantity'] as String,
        countedQuantity: j['countedQuantity'] as String?,
        currentQuantity: j['currentQuantity'] as String?,
      );
  final String id;
  final String articleId;
  final String? articleName;
  final String? unit;
  final String expectedQuantity;
  final String? countedQuantity;
  final String? currentQuantity;

  /// C5.4: `null` = ganzer Artikel, `''` = nicht zugeordnet, sonst Platz.
  final String? binKey;
  final String? binLabel;
}

class OnlineInventoryCount {
  const OnlineInventoryCount({
    required this.id,
    required this.label,
    required this.date,
    required this.status,
    this.items = const [],
    this.locationId,
    this.bins = const [],
  });
  factory OnlineInventoryCount.fromJson(Map<String, Object?> j) => OnlineInventoryCount(
        locationId: j['locationId'] as String?,
        bins: [for (final b in (j['bins'] as List? ?? const [])) OnlineStorageBin.fromJson(b as Map<String, Object?>)],
        id: j['id'] as String,
        label: j['label'] as String,
        date: DateTime.parse(j['date'] as String),
        status: j['status'] as String,
        items: [
          for (final i in (j['items'] as List? ?? const [])) OnlineInventoryItem.fromJson(i as Map<String, Object?>),
        ],
      );
  final String id;
  final String label;
  final DateTime date;
  final String status;
  final List<OnlineInventoryItem> items;

  /// C5.4: Inventur nach Lagerort; [bins] = Plätze in Laufreihenfolge.
  final String? locationId;
  final List<OnlineStorageBin> bins;
  bool get isDraft => status == 'draft';
}

typedef OnlineStockWarning = ({String articleName, String requested, String available});

/// C5.4 Platz in einem Lagerort (Reihe → Regal → Fach).
class OnlineStorageBin {
  const OnlineStorageBin({
    required this.id,
    required this.locationId,
    this.row = '',
    this.shelf = '',
    this.compartment = '',
    required this.label,
  });
  factory OnlineStorageBin.fromJson(Map<String, Object?> j) => OnlineStorageBin(
        id: j['id'] as String,
        locationId: j['locationId'] as String,
        row: j['row'] as String? ?? '',
        shelf: j['shelf'] as String? ?? '',
        compartment: j['compartment'] as String? ?? '',
        label: j['label'] as String,
      );
  final String id;
  final String locationId;
  final String row;
  final String shelf;
  final String compartment;
  final String label;
}

class OnlineStorageLocation {
  const OnlineStorageLocation({required this.id, required this.name, this.bins = const [], this.articleIds = const {}});
  factory OnlineStorageLocation.fromJson(Map<String, Object?> j) => OnlineStorageLocation(
        id: j['id'] as String,
        name: j['name'] as String,
        bins: [for (final b in (j['bins'] as List? ?? const [])) OnlineStorageBin.fromJson(b as Map<String, Object?>)],
        articleIds: {for (final a in (j['articleIds'] as List? ?? const [])) a as String},
      );
  final String id;
  final String name;
  final List<OnlineStorageBin> bins;

  /// Artikel mit Bestand oder Standardplatz hier (Filter der Artikelliste).
  final Set<String> articleIds;
}

/// Bestand eines Artikels an einem Platz (`binKey == ''` = nicht zugeordnet).
typedef OnlineBinStock = ({String binKey, String label, String quantity});

class OnlineArticleBinStock {
  const OnlineArticleBinStock({this.defaultBinId, required this.suggestedBinKey, required this.stocks});
  factory OnlineArticleBinStock.fromJson(Map<String, Object?> j) => OnlineArticleBinStock(
        defaultBinId: j['defaultBinId'] as String?,
        suggestedBinKey: j['suggestedBinKey'] as String? ?? '',
        stocks: [
          for (final s in (j['stocks'] as List? ?? const []))
            (
              binKey: (s as Map)['binKey'] as String,
              label: s['label'] as String? ?? '',
              quantity: s['quantity'] as String,
            ),
        ],
      );
  final String? defaultBinId;
  final String suggestedBinKey;
  final List<OnlineBinStock> stocks;
}

/// Entnahme-Vorschlag vor dem Finalisieren (C5.4).
typedef OnlineWithdrawal = ({String articleId, String articleName, String quantity, OnlineArticleBinStock binStock});

Map<String, Object?> _map(Object? value) => value as Map<String, Object?>;

extension StockApi on WerkkernApiClient {
  Future<List<OnlineStockMovement>> stockMovements({String? articleId}) async {
    final j = _map(await request('GET', '/stock/movements', query: {'articleId': ?articleId}));
    return [for (final m in j['movements'] as List) OnlineStockMovement.fromJson(m as Map<String, Object?>)];
  }

  /// Artikel unter Mindestbestand mit Fehlmenge.
  Future<List<({OnlineArticle article, String shortfall})>> lowStock() async {
    final j = _map(await request('GET', '/stock/low'));
    return [
      for (final a in j['articles'] as List)
        (article: OnlineArticle.fromJson(a as Map<String, Object?>), shortfall: a['shortfall'] as String),
    ];
  }

  Future<void> correctStock(String articleId, {required String countedQuantity, required String reason}) =>
      request('POST', '/articles/$articleId/stock-correction', body: {'countedQuantity': countedQuantity, 'reason': reason});

  Future<({bool booksStock, List<OnlineStockWarning> warnings, List<OnlineWithdrawal> withdrawals})> stockCheck(
    String documentId,
  ) async {
    final j = _map(await request('GET', '/documents/$documentId/stock-check'));
    return (
      booksStock: j['booksStock'] as bool,
      withdrawals: [
        for (final w in (j['withdrawals'] as List? ?? const []))
          (
            articleId: (w as Map)['articleId'] as String,
            articleName: w['articleName'] as String,
            quantity: w['quantity'] as String,
            binStock: OnlineArticleBinStock.fromJson(w.cast<String, Object?>()),
          ),
      ],
      warnings: [
        for (final w in j['warnings'] as List)
          (
            articleName: (w as Map)['articleName'] as String,
            requested: w['requested'] as String,
            available: w['available'] as String,
          ),
      ],
    );
  }

  Future<List<OnlineInventoryCount>> inventoryCounts() async {
    final j = _map(await request('GET', '/inventory-counts'));
    return [for (final c in j['inventoryCounts'] as List) OnlineInventoryCount.fromJson(c as Map<String, Object?>)];
  }

  Future<OnlineInventoryCount> inventoryCount(String id) async =>
      OnlineInventoryCount.fromJson(_map(await request('GET', '/inventory-counts/$id')));

  Future<OnlineInventoryCount> createInventoryCount(
    String label, {
    DateTime? date,
    bool allArticles = false,
    String? locationId,
  }) async =>
      OnlineInventoryCount.fromJson(_map(await request('POST', '/inventory-counts', body: {
        'label': label,
        if (date != null) 'date': onlineDate(date),
        'allArticles': allArticles,
        'locationId': ?locationId,
      })));

  /// C5.4: Fund an einem Platz während der Platz-Inventur.
  Future<OnlineInventoryCount> addInventoryFound(String countId, {required String articleId, required String binKey}) async =>
      OnlineInventoryCount.fromJson(_map(
        await request('POST', '/inventory-counts/$countId/found', body: {'articleId': articleId, 'binKey': binKey}),
      ));

  // ---- C5.4 Lagerorte und Plätze ---------------------------------------------

  Future<({List<OnlineStorageLocation> locations, Set<String> unassignedArticleIds})> storageLocations() async {
    final j = _map(await request('GET', '/storage-locations'));
    return (
      locations: [for (final l in j['locations'] as List) OnlineStorageLocation.fromJson(l as Map<String, Object?>)],
      unassignedArticleIds: {for (final a in (j['unassignedArticleIds'] as List? ?? const [])) a as String},
    );
  }

  Future<void> saveStorageLocation(String name, {String? id}) =>
      request(id == null ? 'POST' : 'PUT', id == null ? '/storage-locations' : '/storage-locations/$id', body: {'name': name});

  Future<void> deleteStorageLocation(String id) => request('DELETE', '/storage-locations/$id');

  Future<void> saveStorageBin({
    required String locationId,
    String? id,
    required String row,
    required String shelf,
    required String compartment,
  }) =>
      request(
        id == null ? 'POST' : 'PUT',
        id == null ? '/storage-locations/$locationId/bins' : '/storage-bins/$id',
        body: {'locationId': locationId, 'row': row, 'shelf': shelf, 'compartment': compartment},
      );

  Future<void> deleteStorageBin(String id) => request('DELETE', '/storage-bins/$id');

  Future<OnlineArticleBinStock> articleBinStock(String articleId) async =>
      OnlineArticleBinStock.fromJson(_map(await request('GET', '/articles/$articleId/bin-stock')));

  Future<OnlineArticleBinStock> setDefaultBin(String articleId, String? binId) async =>
      OnlineArticleBinStock.fromJson(_map(await request('PUT', '/articles/$articleId/default-bin', body: {'binId': binId})));

  Future<OnlineArticleBinStock> transferStock(
    String articleId, {
    required String fromBinKey,
    required String toBinKey,
    required String quantity,
  }) async =>
      OnlineArticleBinStock.fromJson(_map(await request('POST', '/articles/$articleId/stock-transfer', body: {
        'fromBinKey': fromBinKey,
        'toBinKey': toBinKey,
        'quantity': quantity,
      })));

  Future<OnlineInventoryCount> addInventoryArticles(String countId, List<String> articleIds) async =>
      OnlineInventoryCount.fromJson(
        _map(await request('POST', '/inventory-counts/$countId/articles', body: {'articleIds': articleIds})),
      );

  Future<OnlineInventoryCount> setInventoryCounted(String countId, String itemId, String? countedQuantity) async =>
      OnlineInventoryCount.fromJson(
        _map(await request('PUT', '/inventory-counts/$countId/items/$itemId', body: {'countedQuantity': countedQuantity})),
      );

  Future<void> removeInventoryItem(String countId, String itemId) =>
      request('DELETE', '/inventory-counts/$countId/items/$itemId');

  Future<OnlineInventoryCount> completeInventoryCount(String countId) async =>
      OnlineInventoryCount.fromJson(_map(await request('POST', '/inventory-counts/$countId/complete')));
}
