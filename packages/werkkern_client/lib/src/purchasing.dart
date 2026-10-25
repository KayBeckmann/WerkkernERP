import 'api_client.dart';
import 'fleet.dart' show onlineDate;

/// Bestellwesen online (C5.2).
class OnlinePurchaseOrderItem {
  const OnlinePurchaseOrderItem({
    this.id,
    this.articleId,
    required this.description,
    required this.quantity,
    this.purchasePriceCents,
    this.receivedQuantity = '0',
  });
  factory OnlinePurchaseOrderItem.fromJson(Map<String, Object?> j) => OnlinePurchaseOrderItem(
        id: j['id'] as String?,
        articleId: j['articleId'] as String?,
        description: j['description'] as String,
        quantity: j['quantity'] as String,
        purchasePriceCents: j['purchasePriceCents'] as int?,
        receivedQuantity: j['receivedQuantity'] as String? ?? '0',
      );
  final String? id;
  final String? articleId;
  final String description;
  final String quantity;
  final int? purchasePriceCents;
  final String receivedQuantity;

  Map<String, Object?> toWriteJson() => {
        'articleId': articleId,
        'description': description,
        'quantity': quantity,
        'purchasePriceCents': purchasePriceCents,
      };
}

class OnlinePurchaseOrder {
  const OnlinePurchaseOrder({
    required this.id,
    required this.supplierId,
    this.supplierName,
    this.supplierAddress,
    required this.status,
    this.number,
    required this.issueDate,
    this.notes,
    this.projectId,
    this.expenseCategoryId,
    this.sourceOrderId,
    required this.version,
    this.items = const [],
    this.totalNetCents = 0,
  });
  factory OnlinePurchaseOrder.fromJson(Map<String, Object?> j) {
    final snapshot = j['supplierSnapshot'] as Map<String, Object?>?;
    return OnlinePurchaseOrder(
      id: j['id'] as String,
      supplierId: j['supplierId'] as String,
      supplierName: snapshot?['name'] as String? ?? j['supplierName'] as String?,
      supplierAddress: snapshot?['address'] as String?,
      status: j['status'] as String,
      number: j['number'] as String?,
      issueDate: DateTime.parse(j['issueDate'] as String),
      notes: j['notes'] as String?,
      projectId: j['projectId'] as String?,
      expenseCategoryId: j['expenseCategoryId'] as String?,
      sourceOrderId: j['sourceOrderId'] as String?,
      version: j['version'] as int,
      items: [for (final i in (j['items'] as List? ?? const [])) OnlinePurchaseOrderItem.fromJson(i as Map<String, Object?>)],
      totalNetCents: j['totalNetCents'] as int? ?? 0,
    );
  }
  final String id;
  final String supplierId;
  final String? supplierName;
  final String? supplierAddress;

  /// `draft`, `finalized`, `partiallyReceived`, `fullyReceived`.
  final String status;
  final String? number;
  final DateTime issueDate;
  final String? notes;
  final String? projectId;
  final String? expenseCategoryId;
  final String? sourceOrderId;
  final int version;
  final List<OnlinePurchaseOrderItem> items;
  final int totalNetCents;

  bool get isDraft => status == 'draft';
  bool get canReceive => status == 'finalized' || status == 'partiallyReceived';
}

typedef OnlinePurchaseSuggestion = ({
  String supplierId,
  String supplierName,
  List<OnlinePurchaseOrderItem> items,
  String? minimumOrderQuantity,
  String totalQuantity,
  bool meetsMinimumOrderQuantity,
});

Map<String, Object?> _map(Object? value) => value as Map<String, Object?>;

extension PurchasingApi on WerkkernApiClient {
  Future<List<OnlinePurchaseOrder>> purchaseOrders({String? status}) async {
    final j = _map(await request('GET', '/purchase-orders', query: {'status': ?status}));
    return [for (final o in j['purchaseOrders'] as List) OnlinePurchaseOrder.fromJson(o as Map<String, Object?>)];
  }

  Future<OnlinePurchaseOrder> purchaseOrder(String id) async =>
      OnlinePurchaseOrder.fromJson(_map(await request('GET', '/purchase-orders/$id')));

  Future<OnlinePurchaseOrder> createPurchaseOrder({
    required String supplierId,
    DateTime? issueDate,
    String? notes,
    String? projectId,
    String? expenseCategoryId,
    List<OnlinePurchaseOrderItem> items = const [],
  }) async =>
      OnlinePurchaseOrder.fromJson(_map(await request('POST', '/purchase-orders', body: {
        'supplierId': supplierId,
        if (issueDate != null) 'issueDate': onlineDate(issueDate),
        'notes': notes,
        'projectId': projectId,
        'expenseCategoryId': expenseCategoryId,
        'items': [for (final i in items) i.toWriteJson()],
      })));

  Future<OnlinePurchaseOrder> updatePurchaseOrder(
    OnlinePurchaseOrder order, {
    required List<OnlinePurchaseOrderItem> items,
    String? supplierId,
    String? notes,
    String? projectId,
    String? expenseCategoryId,
  }) async =>
      OnlinePurchaseOrder.fromJson(_map(await request('PUT', '/purchase-orders/${order.id}', body: {
        'version': order.version,
        'supplierId': supplierId ?? order.supplierId,
        'issueDate': onlineDate(order.issueDate),
        'notes': notes,
        'projectId': projectId,
        'expenseCategoryId': expenseCategoryId,
        'items': [for (final i in items) i.toWriteJson()],
      })));

  Future<void> deletePurchaseOrder(String id) => request('DELETE', '/purchase-orders/$id');

  Future<OnlinePurchaseOrder> finalizePurchaseOrder(OnlinePurchaseOrder order) async => OnlinePurchaseOrder.fromJson(
        _map(await request('POST', '/purchase-orders/${order.id}/finalize', body: {'version': order.version})),
      );

  Future<OnlinePurchaseOrder> receivePurchaseOrder(String id, Map<String, String> receipts) async =>
      OnlinePurchaseOrder.fromJson(_map(await request('POST', '/purchase-orders/$id/receive', body: {'receipts': receipts})));

  /// `mode`: `oneSupplier` (mit [supplierId]) oder `cheapest`.
  Future<({List<String> ids, List<String> unassignable})> purchaseOrdersFromDocument(
    String documentId, {
    required String mode,
    String? supplierId,
  }) async {
    final j = _map(await request('POST', '/documents/$documentId/purchase-orders', body: {'mode': mode, 'supplierId': supplierId}));
    return (
      ids: (j['purchaseOrderIds'] as List).cast<String>(),
      unassignable: [for (final u in (j['unassignable'] as List).cast<Map<String, Object?>>()) u['articleName'] as String],
    );
  }

  Future<({List<OnlinePurchaseSuggestion> suggestions, List<String> unassignable})> purchaseSuggestions() async {
    final j = _map(await request('GET', '/purchase-orders/suggestions'));
    return (
      suggestions: [
        for (final s in (j['suggestions'] as List).cast<Map<String, Object?>>())
          (
            supplierId: s['supplierId'] as String,
            supplierName: s['supplierName'] as String,
            items: [for (final i in s['items'] as List) OnlinePurchaseOrderItem.fromJson(i as Map<String, Object?>)],
            minimumOrderQuantity: s['minimumOrderQuantity'] as String?,
            totalQuantity: s['totalQuantity'] as String,
            meetsMinimumOrderQuantity: s['meetsMinimumOrderQuantity'] as bool,
          ),
      ],
      unassignable: [for (final u in (j['unassignable'] as List).cast<Map<String, Object?>>()) u['articleName'] as String],
    );
  }

  Future<OnlinePurchaseOrder> purchaseOrderFromSuggestion(String supplierId) async =>
      OnlinePurchaseOrder.fromJson(_map(await request('POST', '/purchase-orders/from-suggestion', body: {'supplierId': supplierId})));
}
