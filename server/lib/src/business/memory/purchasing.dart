part of '../repository_memory.dart';

mixin _InMemoryPurchasing implements PurchasingStore {
  Map<String, int> get _sequences;
  List<Supplier> get _suppliers;
  List<Expense> get _expenses;
  List<StockMovement> _bookStockSync(String companyId, List<StockDelta> deltas, StockBookingContext context);

  final List<PurchaseOrder> _purchaseOrders = [];

  final List<PurchaseOrderItem> _purchaseOrderItems = [];
  static const _purchaseUuid = Uuid();

  PurchaseOrder _copy(PurchaseOrder o, {String? status, String? number, int? numberYear, String? snapshotName, String? snapshotAddress, DateTime? finalizedAt, required DateTime updatedAt}) =>
      PurchaseOrder(
        id: o.id,
        companyId: o.companyId,
        supplierId: o.supplierId,
        status: status ?? o.status,
        number: number ?? o.number,
        numberYear: numberYear ?? o.numberYear,
        issueDate: o.issueDate,
        notes: o.notes,
        supplierSnapshotName: snapshotName ?? o.supplierSnapshotName,
        supplierSnapshotAddress: snapshotAddress ?? o.supplierSnapshotAddress,
        finalizedAt: finalizedAt ?? o.finalizedAt,
        sourceOrderId: o.sourceOrderId,
        projectId: o.projectId,
        expenseCategoryId: o.expenseCategoryId,
        createdByUserId: o.createdByUserId,
        createdAt: o.createdAt,
        updatedAt: updatedAt,
        version: o.version + 1,
      );

  @override
  Future<List<PurchaseOrder>> listPurchaseOrders(String companyId, {String? status, String? sourceOrderId}) async =>
      _purchaseOrders
          .where((o) =>
              o.companyId == companyId &&
              (status == null || o.status == status) &&
              (sourceOrderId == null || o.sourceOrderId == sourceOrderId))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<PurchaseOrder?> findPurchaseOrder(String companyId, String id) async =>
      _purchaseOrders.where((o) => o.companyId == companyId && o.id == id).firstOrNull;

  @override
  Future<List<PurchaseOrderItem>> purchaseOrderItems(String companyId, String id) async {
    if (await findPurchaseOrder(companyId, id) == null) return const [];
    return _purchaseOrderItems.where((i) => i.purchaseOrderId == id).toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  @override
  Future<void> createPurchaseOrder(PurchaseOrder order, List<PurchaseOrderItem> items) async {
    _purchaseOrders.add(order);
    _purchaseOrderItems.addAll(items);
  }

  int _draftIndex(String companyId, String id, int expectedVersion) {
    final index = _purchaseOrders.indexWhere((o) => o.companyId == companyId && o.id == id);
    if (index == -1) return -1;
    final existing = _purchaseOrders[index];
    if (!existing.isDraft) throw const BusinessConflict('Bestellung ist finalisiert und unveränderlich.');
    if (existing.version != expectedVersion) {
      throw BusinessConflict('Bestellung wurde zwischenzeitlich geändert (Version ${existing.version}, erwartet $expectedVersion).');
    }
    return index;
  }

  @override
  Future<PurchaseOrder?> updatePurchaseOrderDraft(PurchaseOrder order, List<PurchaseOrderItem> items, {required int expectedVersion}) async {
    final index = _draftIndex(order.companyId, order.id, expectedVersion);
    if (index == -1) return null;
    final updated = PurchaseOrder(
      id: order.id,
      companyId: order.companyId,
      supplierId: order.supplierId,
      status: 'draft',
      issueDate: order.issueDate,
      notes: order.notes,
      sourceOrderId: _purchaseOrders[index].sourceOrderId,
      projectId: order.projectId,
      expenseCategoryId: order.expenseCategoryId,
      createdByUserId: _purchaseOrders[index].createdByUserId,
      createdAt: _purchaseOrders[index].createdAt,
      updatedAt: order.updatedAt,
      version: expectedVersion + 1,
    );
    _purchaseOrders[index] = updated;
    _purchaseOrderItems.removeWhere((i) => i.purchaseOrderId == order.id);
    _purchaseOrderItems.addAll(items);
    return updated;
  }

  @override
  Future<bool> deletePurchaseOrderDraft(String companyId, String id) async {
    final existing = await findPurchaseOrder(companyId, id);
    if (existing == null) return false;
    if (!existing.isDraft) throw const BusinessConflict('Nur Entwürfe können gelöscht werden.');
    _purchaseOrders.removeWhere((o) => o.id == id);
    _purchaseOrderItems.removeWhere((i) => i.purchaseOrderId == id);
    return true;
  }

  @override
  Future<PurchaseOrder?> finalizePurchaseOrder(String companyId, String id, {required int expectedVersion, required DateTime now}) async {
    final index = _draftIndex(companyId, id, expectedVersion);
    if (index == -1) return null;
    final order = _purchaseOrders[index];
    if (!_purchaseOrderItems.any((i) => i.purchaseOrderId == id)) {
      throw const BusinessConflict('Eine Bestellung ohne Positionen kann nicht finalisiert werden.');
    }
    final supplier = _suppliers.firstWhere((s) => s.id == order.supplierId);
    final key = '$companyId|$purchaseOrderSequenceType|${now.year}';
    final number = (_sequences[key] ?? 0) + 1;
    _sequences[key] = number;
    final finalized = _copy(
      order,
      status: 'finalized',
      number: formatNumberWithPrefix(prefix: 'B', year: now.year, number: number),
      numberYear: now.year,
      snapshotName: supplier.name,
      snapshotAddress: supplier.address,
      finalizedAt: now,
      updatedAt: now,
    );
    _purchaseOrders[index] = finalized;
    return finalized;
  }

  @override
  Future<PurchaseOrder?> receivePurchaseOrder(
    String companyId,
    String id, {
    required Map<String, Decimal> receipts,
    required String userId,
    required DateTime now,
  }) async {
    final index = _purchaseOrders.indexWhere((o) => o.companyId == companyId && o.id == id);
    if (index == -1) return null;
    final order = _purchaseOrders[index];
    if (!order.canReceive) throw const BusinessConflict('Wareneingang nur zu einer finalisierten, offenen Bestellung.');
    final items = {for (final i in _purchaseOrderItems.where((i) => i.purchaseOrderId == id)) i.id: i};
    // Erst alles prüfen, dann schreiben — ein Fehler lässt nichts halb gebucht.
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
      final updated = PurchaseOrderItem(
        id: item.id,
        purchaseOrderId: id,
        articleId: item.articleId,
        description: item.description,
        quantity: item.quantity,
        purchasePriceCents: item.purchasePriceCents,
        receivedQuantity: (Decimal.parse(item.receivedQuantity) + entry.value).toString(),
        sortOrder: item.sortOrder,
      );
      _purchaseOrderItems[_purchaseOrderItems.indexWhere((i) => i.id == item.id)] = updated;
      items[item.id] = updated;
      if (item.purchasePriceCents != null) {
        valueCents += Money.fromCents(item.purchasePriceCents!).multiplyByQuantity(entry.value).cents;
      }
      if (item.articleId != null) deltas.add(StockDelta(item.articleId!, entry.value));
    }
    _bookStockSync(
      companyId,
      deltas,
      StockBookingContext(type: 'purchaseOrderReceipt', userId: userId, now: now, referenceLabel: order.number),
    );
    if (valueCents > 0) {
      _expenses.add(Expense(
        id: _purchaseUuid.v4(),
        companyId: companyId,
        date: DateTime.utc(now.year, now.month, now.day),
        description: 'Wareneingang zu Bestellung ${order.number ?? order.id}',
        amountGrossCents: valueCents,
        vatRatePercent: 0,
        categoryId: order.expenseCategoryId,
        supplierReference: order.number,
        projectId: order.projectId,
        purchaseOrderId: id,
        createdByUserId: userId,
        createdAt: now,
        updatedAt: now,
      ));
    }
    final all = items.values.every((i) => i.open <= Decimal.zero);
    final any = items.values.any((i) => Decimal.parse(i.receivedQuantity) > Decimal.zero);
    final updated = _copy(order, status: all ? 'fullyReceived' : (any ? 'partiallyReceived' : order.status), updatedAt: now);
    _purchaseOrders[index] = updated;
    return updated;
  }
}
