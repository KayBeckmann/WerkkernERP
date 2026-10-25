/// Bestellwesen online (C5.2): Bestellungen an Lieferanten mit Nummer
/// `B-JJxxx`, Wareneingang (auch Teillieferungen) mit Bestandsbuchung und
/// automatischem Beleg — gleiche Regeln wie offline.
library;

import 'package:decimal/decimal.dart';

import 'request_util.dart';

/// Zählerkreis der Bestellnummern (wie offline `purchaseOrderDocumentType`).
const purchaseOrderSequenceType = 'purchaseOrder';

class PurchaseOrder {
  const PurchaseOrder({
    required this.id,
    required this.companyId,
    required this.supplierId,
    required this.status,
    this.number,
    this.numberYear,
    required this.issueDate,
    this.notes,
    this.supplierSnapshotName,
    this.supplierSnapshotAddress,
    this.finalizedAt,
    this.sourceOrderId,
    this.projectId,
    this.expenseCategoryId,
    required this.createdByUserId,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
  });
  final String id;
  final String companyId;
  final String supplierId;

  /// `draft`, `finalized`, `partiallyReceived`, `fullyReceived`.
  final String status;
  final String? number;
  final int? numberYear;
  final DateTime issueDate;
  final String? notes;
  final String? supplierSnapshotName;
  final String? supplierSnapshotAddress;
  final DateTime? finalizedAt;

  /// Auftrag, aus dem die Bestellung erzeugt wurde (Nachvollziehbarkeit).
  final String? sourceOrderId;

  /// Wird an den Wareneingangs-Beleg weitergegeben (Projektkosten).
  final String? projectId;

  /// SKR03-Kategorie des Wareneingangs-Belegs.
  final String? expenseCategoryId;
  final String createdByUserId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;

  bool get isDraft => status == 'draft';
  bool get canReceive => status == 'finalized' || status == 'partiallyReceived';

  Map<String, Object?> toJson() => {
        'id': id,
        'supplierId': supplierId,
        'status': status,
        'number': number,
        'issueDate': dateJson(issueDate),
        'notes': notes,
        'supplierSnapshot': supplierSnapshotName == null ? null : {'name': supplierSnapshotName, 'address': supplierSnapshotAddress},
        'finalizedAt': finalizedAt?.toIso8601String(),
        'sourceOrderId': sourceOrderId,
        'projectId': projectId,
        'expenseCategoryId': expenseCategoryId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'version': version,
      };
}

class PurchaseOrderItem {
  const PurchaseOrderItem({
    required this.id,
    required this.purchaseOrderId,
    this.articleId,
    required this.description,
    required this.quantity,
    this.purchasePriceCents,
    this.receivedQuantity = '0',
    required this.sortOrder,
  });
  final String id;
  final String purchaseOrderId;
  final String? articleId;
  final String description;

  /// Dezimaltext.
  final String quantity;

  /// Netto-Einkaufspreis je Einheit (Richtwert, keine USt).
  final int? purchasePriceCents;
  final String receivedQuantity;
  final int sortOrder;

  Decimal get open => Decimal.parse(quantity) - Decimal.parse(receivedQuantity);

  Map<String, Object?> toJson() => {
        'id': id,
        'articleId': articleId,
        'description': description,
        'quantity': quantity,
        'purchasePriceCents': purchasePriceCents,
        'receivedQuantity': receivedQuantity,
      };
}

abstract interface class PurchasingStore {
  Future<List<PurchaseOrder>> listPurchaseOrders(String companyId, {String? status, String? sourceOrderId});
  Future<PurchaseOrder?> findPurchaseOrder(String companyId, String id);
  Future<List<PurchaseOrderItem>> purchaseOrderItems(String companyId, String id);
  Future<void> createPurchaseOrder(PurchaseOrder order, List<PurchaseOrderItem> items);

  /// Ersetzt Kopf + Positionen eines Entwurfs; [BusinessConflict] bei
  /// finalisierter Bestellung oder veralteter [expectedVersion].
  Future<PurchaseOrder?> updatePurchaseOrderDraft(
    PurchaseOrder order,
    List<PurchaseOrderItem> items, {
    required int expectedVersion,
  });
  Future<bool> deletePurchaseOrderDraft(String companyId, String id);

  /// Nummer im Firmen-/Jahreskreis, Lieferanten-Schnappschuss — atomar.
  Future<PurchaseOrder?> finalizePurchaseOrder(String companyId, String id, {required int expectedVersion, required DateTime now});

  /// Wareneingang (additiv je Positions-ID) in einer Transaktion:
  /// Eingangsmengen, Bestandsbewegungen der Artikel, **ein** Beleg über
  /// den Wert genau dieses Eingangs (ohne USt, wie offline), Status.
  /// [BusinessConflict] bei Überlieferung oder fremder Position.
  Future<PurchaseOrder?> receivePurchaseOrder(
    String companyId,
    String id, {
    required Map<String, Decimal> receipts,
    required String userId,
    required DateTime now,
  });
}
