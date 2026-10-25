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
  });
  factory OnlineStockMovement.fromJson(Map<String, Object?> j) => OnlineStockMovement(
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
  });
  factory OnlineInventoryItem.fromJson(Map<String, Object?> j) => OnlineInventoryItem(
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
}

class OnlineInventoryCount {
  const OnlineInventoryCount({
    required this.id,
    required this.label,
    required this.date,
    required this.status,
    this.items = const [],
  });
  factory OnlineInventoryCount.fromJson(Map<String, Object?> j) => OnlineInventoryCount(
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
  bool get isDraft => status == 'draft';
}

typedef OnlineStockWarning = ({String articleName, String requested, String available});

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

  Future<({bool booksStock, List<OnlineStockWarning> warnings})> stockCheck(String documentId) async {
    final j = _map(await request('GET', '/documents/$documentId/stock-check'));
    return (
      booksStock: j['booksStock'] as bool,
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

  Future<OnlineInventoryCount> createInventoryCount(String label, {DateTime? date, bool allArticles = false}) async =>
      OnlineInventoryCount.fromJson(_map(await request('POST', '/inventory-counts', body: {
        'label': label,
        if (date != null) 'date': onlineDate(date),
        'allArticles': allArticles,
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
