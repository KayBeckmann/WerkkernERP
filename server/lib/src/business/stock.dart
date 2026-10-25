/// Lagerbestand online (C5.1/C5.3): Bestandsbewegungen und Inventur.
/// Der Bestand eines Artikels ändert sich **ausschließlich** über eine
/// unveränderliche Bewegung (Kay: "Das muss alles dokumentiert werden").
library;

import 'package:decimal/decimal.dart';

import 'request_util.dart';

/// Wie offline `StockMovementType`.
const stockMovementTypes = {'documentBooking', 'purchaseOrderReceipt', 'inventoryCorrection', 'creditNoteReturn'};

class StockMovement {
  const StockMovement({
    required this.id,
    required this.companyId,
    required this.articleId,
    required this.type,
    required this.quantityDelta,
    required this.resultingQuantity,
    this.referenceLabel,
    this.note,
    this.documentId,
    required this.createdByUserId,
    required this.createdAt,
  });
  final String id;
  final String companyId;
  final String articleId;
  final String type;

  /// Dezimaltext, negativ = Abgang.
  final String quantityDelta;
  final String resultingQuantity;
  final String? referenceLabel;
  final String? note;
  final String? documentId;
  final String createdByUserId;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'articleId': articleId,
        'type': type,
        'quantityDelta': quantityDelta,
        'resultingQuantity': resultingQuantity,
        'referenceLabel': referenceLabel,
        'note': note,
        'documentId': documentId,
        'createdAt': createdAt.toIso8601String(),
      };
}

/// Bestandsänderung eines Artikels (vor der Buchung).
class StockDelta {
  const StockDelta(this.articleId, this.delta);
  final String articleId;
  final Decimal delta;
}

/// Kontext einer Buchung — landet in jeder erzeugten Bewegung.
class StockBookingContext {
  const StockBookingContext({
    required this.type,
    required this.userId,
    required this.now,
    this.referenceLabel,
    this.note,
    this.documentId,
  });
  final String type;
  final String userId;
  final DateTime now;
  final String? referenceLabel;
  final String? note;
  final String? documentId;
}

/// Wie das Finalisieren eines Dokuments den Bestand bewegt.
enum StockBookingMode {
  /// Auftrag/Rechnung/Lieferschein: Abgang der Artikelmengen.
  issue,

  /// Gutschrift: Rückbuchung (Zugang) der eigenen Artikelmengen.
  creditNoteReturn,
}

class InventoryCount {
  const InventoryCount({
    required this.id,
    required this.companyId,
    required this.label,
    required this.date,
    required this.status,
    this.completedAt,
    required this.createdAt,
  });
  final String id;
  final String companyId;
  final String label;
  final DateTime date;

  /// `draft` oder `completed` (danach unveränderlich).
  final String status;
  final DateTime? completedAt;
  final DateTime createdAt;

  bool get isDraft => status == 'draft';

  Map<String, Object?> toJson() => {
        'id': id,
        'label': label,
        'date': dateJson(date),
        'status': status,
        'completedAt': completedAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };
}

class InventoryCountItem {
  const InventoryCountItem({
    required this.id,
    required this.inventoryCountId,
    required this.articleId,
    required this.expectedQuantity,
    this.countedQuantity,
    this.countedAt,
  });
  final String id;
  final String inventoryCountId;
  final String articleId;

  /// Bestand beim Aufnehmen in den Lauf (Soll).
  final String expectedQuantity;
  final String? countedQuantity;
  final DateTime? countedAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'articleId': articleId,
        'expectedQuantity': expectedQuantity,
        'countedQuantity': countedQuantity,
        'countedAt': countedAt?.toIso8601String(),
      };
}

/// Summiert die Artikelmengen von Positionen je Artikel (Stunden und
/// Freitext ohne `articleId` zählen nicht).
Map<String, Decimal> articleQuantities(Iterable<({String? articleId, String quantity})> items) {
  final result = <String, Decimal>{};
  for (final item in items) {
    final id = item.articleId;
    if (id == null) continue;
    result[id] = (result[id] ?? Decimal.zero) + Decimal.parse(item.quantity);
  }
  return result;
}

abstract interface class StockStore {
  /// Bucht alle [deltas] atomar (Artikel gesperrt) und liefert die
  /// erzeugten Bewegungen. Deltas von 0 werden übersprungen.
  Future<List<StockMovement>> bookStock(String companyId, List<StockDelta> deltas, StockBookingContext context);

  Future<List<StockMovement>> listStockMovements(String companyId, {String? articleId, int limit = 200});

  Future<List<InventoryCount>> listInventoryCounts(String companyId);
  Future<InventoryCount?> findInventoryCount(String companyId, String id);
  Future<List<InventoryCountItem>> inventoryItems(String companyId, String countId);
  Future<void> createInventoryCount(InventoryCount count);

  /// Nimmt Artikel in einen Entwurf auf und friert den aktuellen Bestand
  /// als Soll ein; bereits enthaltene werden übersprungen. `false`, wenn
  /// der Lauf nicht (mehr) bearbeitbar ist.
  Future<bool> addInventoryArticles(String companyId, String countId, List<String> articleIds, {required String Function() newId});
  Future<bool> removeInventoryItem(String companyId, String countId, String itemId);

  /// Zählmenge setzen (`null` = noch nicht gezählt).
  Future<bool> setInventoryCounted(String companyId, String countId, String itemId, String? counted, DateTime now);

  /// Schließt den Lauf ab: jede gezählte Position mit Abweichung zum
  /// **aktuellen** Bestand bucht auf die gezählte Menge (Typ
  /// `inventoryCorrection`, Referenz = Bezeichnung). Danach unveränderlich.
  /// `null`, wenn nicht gefunden oder schon abgeschlossen.
  Future<List<StockMovement>?> completeInventoryCount(String companyId, String countId, {required String userId, required DateTime now});
}
