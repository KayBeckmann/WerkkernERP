/// Lagerbestand online (C5.1/C5.3): Bestandsbewegungen und Inventur.
/// Der Bestand eines Artikels ändert sich **ausschließlich** über eine
/// unveränderliche Bewegung (Kay: "Das muss alles dokumentiert werden").
library;

import 'package:decimal/decimal.dart';

import 'request_util.dart';

/// Wie offline `StockMovementType`.
const stockMovementTypes = {'documentBooking', 'purchaseOrderReceipt', 'inventoryCorrection', 'creditNoteReturn', 'transfer'};

/// „Platz noch nicht zugeordnet“ (C5.4).
const unassignedBinKey = '';

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
    this.binKey,
  });

  /// C5.4: Platz der Bewegung (`''` = nicht zugeordnet, `null` = vor C5.4).
  final String? binKey;
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
        'binKey': binKey,
      };
}

/// Bestandsänderung eines Artikels (vor der Buchung).
///
/// C5.4: [binKey] = Platz. Zugang ohne Platz → Standardplatz, sonst
/// „nicht zugeordnet“. Abgang mit [spread] → [binKey] (oder der Vorschlag)
/// zuerst, dann weitere Plätze mit Bestand ([planWithdrawal]).
class StockDelta {
  const StockDelta(this.articleId, this.delta, {this.binKey, this.spread = false});
  final String articleId;
  final Decimal delta;
  final String? binKey;
  final bool spread;
}

/// Kay (16.11.2026): Vorschlag für die Entnahme — Platz mit dem größten
/// Bestand, sonst Standardplatz, sonst „nicht zugeordnet“.
String suggestWithdrawalBin(Map<String, Decimal> stocks, String? defaultBinId) {
  final candidates = stocks.entries.where((e) => e.key != unassignedBinKey && e.value > Decimal.zero).toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  if (candidates.isNotEmpty) return candidates.first.key;
  return defaultBinId ?? unassignedBinKey;
}

/// Verteilt eine Entnahme von [quantity] (> 0): zuerst [preferred], dann
/// nicht zugeordneter Bestand, dann größter Bestand. Rest auf [preferred]
/// (negativer Platzbestand = Klärfall). Wie offline `StockLedger.withdraw`.
List<(String, Decimal)> planWithdrawal(Map<String, Decimal> stocks, Decimal quantity, String preferred) {
  final order = <String>[
    preferred,
    if (preferred != unassignedBinKey) unassignedBinKey,
    ...(stocks.entries.where((e) => e.key != preferred && e.key != unassignedBinKey).toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .map((e) => e.key),
  ];
  var remaining = quantity;
  final plan = <String, Decimal>{};
  for (final key in order) {
    if (remaining <= Decimal.zero) break;
    final have = stocks[key] ?? Decimal.zero;
    if (have <= Decimal.zero) continue;
    final take = have < remaining ? have : remaining;
    plan[key] = (plan[key] ?? Decimal.zero) + take;
    remaining -= take;
  }
  if (remaining > Decimal.zero) plan[preferred] = (plan[preferred] ?? Decimal.zero) + remaining;
  return [for (final e in plan.entries) (e.key, e.value)];
}

/// Lagerort einer Firma (C5.4).
class StorageLocation {
  const StorageLocation({required this.id, required this.companyId, required this.name, this.sortOrder = 0, required this.createdAt});
  final String id;
  final String companyId;
  final String name;
  final int sortOrder;
  final DateTime createdAt;
}

/// Platz in einem Lagerort: Reihe → Regal → Fach.
class StorageBin {
  const StorageBin({
    required this.id,
    required this.companyId,
    required this.locationId,
    this.row = '',
    this.shelf = '',
    this.compartment = '',
    this.sortOrder = 0,
  });
  final String id;
  final String companyId;
  final String locationId;
  final String row;
  final String shelf;
  final String compartment;
  final int sortOrder;

  String get label {
    final parts = [
      if (row.trim().isNotEmpty) 'Reihe ${row.trim()}',
      if (shelf.trim().isNotEmpty) 'Regal ${shelf.trim()}',
      if (compartment.trim().isNotEmpty) 'Fach ${compartment.trim()}',
    ].join(' / ');
    return parts.isEmpty ? 'ohne Bezeichnung' : parts;
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'locationId': locationId,
        'row': row,
        'shelf': shelf,
        'compartment': compartment,
        'sortOrder': sortOrder,
        'label': label,
      };
}

/// Laufreihenfolge: Sortierung, dann Reihe → Regal → Fach (Zahlen numerisch).
int compareBinsInWalkOrder(StorageBin a, StorageBin b) {
  final bySort = a.sortOrder.compareTo(b.sortOrder);
  if (bySort != 0) return bySort;
  for (final (x, y) in [(a.row, b.row), (a.shelf, b.shelf), (a.compartment, b.compartment)]) {
    final nx = int.tryParse(x.trim());
    final ny = int.tryParse(y.trim());
    final c = nx != null && ny != null ? nx.compareTo(ny) : x.trim().toLowerCase().compareTo(y.trim().toLowerCase());
    if (c != 0) return c;
  }
  return 0;
}

/// Bestand eines Artikels an einem Platz.
class ArticleBinStock {
  const ArticleBinStock({required this.articleId, required this.binKey, required this.quantity});
  final String articleId;
  final String binKey;
  final String quantity;
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
    this.locationId,
  });

  /// C5.4: Inventur nach Lagerort (`null` = artikelweise).
  final String? locationId;
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
        'locationId': locationId,
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
    this.binKey,
  });

  /// C5.4: `null` = ganzer Artikel, `''` = nicht zugeordnet, sonst Platz.
  final String? binKey;
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
        'binKey': binKey,
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

  /// C5.4: Positionen je Artikel und Platz; Soll = aktueller Platzbestand.
  /// Vorhandene Kombinationen werden übersprungen. `false`, wenn der Lauf
  /// nicht (mehr) bearbeitbar ist.
  Future<bool> addInventoryBinItems(
    String companyId,
    String countId,
    List<({String articleId, String binKey})> entries, {
    required String Function() newId,
  });

  // ---- C5.4 Lagerorte und Plätze ---------------------------------------------
  Future<List<StorageLocation>> listStorageLocations(String companyId);
  Future<List<StorageBin>> listStorageBins(String companyId);
  Future<void> saveStorageLocation(StorageLocation location);
  Future<void> saveStorageBin(StorageBin bin);

  /// Löscht Platz bzw. Lagerort samt Plätzen; `false`, wenn dort noch
  /// Bestand liegt. Standardplätze werden gelöst.
  Future<bool> deleteStorageBin(String companyId, String id);
  Future<bool> deleteStorageLocation(String companyId, String id);

  /// Platzbestände (alle Artikel oder einer).
  Future<List<ArticleBinStock>> listBinStocks(String companyId, {String? articleId});
  Future<Map<String, String>> defaultBins(String companyId);
  Future<void> setDefaultBin(String companyId, String articleId, String? binId);

  /// Schließt den Lauf ab: jede gezählte Position mit Abweichung zum
  /// **aktuellen** Bestand bucht auf die gezählte Menge (Typ
  /// `inventoryCorrection`, Referenz = Bezeichnung). Danach unveränderlich.
  /// `null`, wenn nicht gefunden oder schon abgeschlossen.
  Future<List<StockMovement>?> completeInventoryCount(String companyId, String countId, {required String userId, required DateTime now});
}
