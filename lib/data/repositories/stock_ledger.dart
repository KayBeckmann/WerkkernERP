import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';
import '../database/tables.dart';

/// Schlüssel für Bestand ohne Platz: „Platz noch nicht zugeordnet“.
const unassignedBinKey = '';

/// Anzeigetext eines Platzes: „Lager · Reihe 2 / Regal B / Fach 3“.
String storageBinLabel(StorageBin bin, {String? locationName}) {
  final parts = [
    if (bin.row.trim().isNotEmpty) 'Reihe ${bin.row.trim()}',
    if (bin.shelf.trim().isNotEmpty) 'Regal ${bin.shelf.trim()}',
    if (bin.compartment.trim().isNotEmpty) 'Fach ${bin.compartment.trim()}',
  ].join(' / ');
  final place = parts.isEmpty ? 'ohne Bezeichnung' : parts;
  return locationName == null ? place : '$locationName · $place';
}

/// Menge eines Artikels an einem Platz (für Anzeige und Vorschläge).
class BinStock {
  const BinStock({required this.binKey, required this.quantity, this.bin, this.locationName});
  final String binKey;
  final double quantity;
  final StorageBin? bin;
  final String? locationName;

  bool get isUnassigned => binKey == unassignedBinKey;
  String get label => bin == null ? 'Platz noch nicht zugeordnet' : storageBinLabel(bin!, locationName: locationName);
}

/// C5.4-Nachtrag (Kay, 16.11.2026): **einzige** Stelle, die Lagerbestand
/// schreibt. Jede Buchung ändert in einem Zug Gesamtbestand
/// (`Articles.stockQuantity`), Platzbestand (`ArticleBinStocks`) und
/// schreibt die Bewegung — so laufen Summe und Plätze nie auseinander.
///
/// Muss innerhalb einer Transaktion des Aufrufers laufen, wenn mehrere
/// Buchungen zusammengehören (Drift verschachtelt Transaktionen).
class StockLedger {
  StockLedger(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  Future<double> _binQuantity(String articleId, String binKey) async {
    final row = await (_db.select(_db.articleBinStocks)
          ..where((s) => s.articleId.equals(articleId) & s.binKey.equals(binKey)))
        .getSingleOrNull();
    return row?.quantity ?? 0;
  }

  Future<void> _addToBin(String companyId, String articleId, String binKey, double delta) async {
    final current = await _binQuantity(articleId, binKey);
    final next = current + delta;
    if (next.abs() < 1e-9 && binKey == unassignedBinKey) {
      // Leere Klärfall-Zeilen nicht stehen lassen.
      await (_db.delete(_db.articleBinStocks)
            ..where((s) => s.articleId.equals(articleId) & s.binKey.equals(binKey)))
          .go();
      return;
    }
    await _db.into(_db.articleBinStocks).insertOnConflictUpdate(
          ArticleBinStocksCompanion.insert(
            companyId: companyId,
            articleId: articleId,
            binKey: binKey,
            quantity: Value(next.abs() < 1e-9 ? 0 : next),
          ),
        );
  }

  /// Bucht [delta] (negativ = Abgang) auf genau einen Platz [binKey]
  /// (`''` = nicht zugeordnet). Liefert den neuen Gesamtbestand oder
  /// `null`, wenn der Artikel nicht existiert.
  Future<double?> book({
    required String companyId,
    required String articleId,
    required double delta,
    required StockMovementType type,
    String binKey = unassignedBinKey,
    String? referenceLabel,
    String? note,
    DateTime? at,
  }) async {
    if (delta == 0) return null;
    final article = await (_db.select(_db.articles)
          ..where((a) => a.id.equals(articleId) & a.companyId.equals(companyId)))
        .getSingleOrNull();
    if (article == null) return null;
    final newTotal = article.stockQuantity + delta;
    await (_db.update(_db.articles)..where((a) => a.id.equals(articleId)))
        .write(ArticlesCompanion(stockQuantity: Value(newTotal)));
    await _addToBin(companyId, articleId, binKey, delta);
    await _db.into(_db.stockMovements).insert(
          StockMovementsCompanion.insert(
            id: _uuid.v4(),
            companyId: companyId,
            articleId: articleId,
            type: type,
            quantityDelta: delta,
            resultingQuantity: newTotal,
            referenceLabel: Value(referenceLabel),
            note: Value(note),
            createdAt: at ?? DateTime.now(),
            binKey: Value(binKey),
          ),
        );
    return newTotal;
  }

  /// Entnahme von [quantity] (> 0) mit bevorzugtem Platz [preferredBinKey]:
  /// zuerst dieser Platz, reicht er nicht, die übrigen Plätze mit Bestand
  /// (nicht zugeordneter Bestand zuerst, dann größter Bestand). Der Rest
  /// geht auf den bevorzugten Platz (negativer Bestand = Klärfall wie
  /// bisher beim Gesamtbestand). Je Platz eine Bewegung.
  Future<void> withdraw({
    required String companyId,
    required String articleId,
    required double quantity,
    required StockMovementType type,
    String? preferredBinKey,
    String? referenceLabel,
    String? note,
  }) async {
    if (quantity <= 0) return;
    final preferred = preferredBinKey ?? await suggestWithdrawalBin(companyId: companyId, articleId: articleId);
    final stocks = await _rawStocks(articleId);
    final order = <String>[
      preferred,
      if (preferred != unassignedBinKey) unassignedBinKey,
      ...(stocks.where((s) => s.binKey != preferred && s.binKey != unassignedBinKey).toList()
            ..sort((a, b) => b.quantity.compareTo(a.quantity)))
          .map((s) => s.binKey),
    ];
    final available = {for (final s in stocks) s.binKey: s.quantity};
    var remaining = quantity;
    final plan = <String, double>{};
    for (final key in order) {
      if (remaining <= 0) break;
      final have = available[key] ?? 0;
      if (have <= 0) continue;
      final take = have < remaining ? have : remaining;
      plan[key] = (plan[key] ?? 0) + take;
      remaining -= take;
    }
    if (remaining > 1e-9) plan[preferred] = (plan[preferred] ?? 0) + remaining;
    for (final entry in plan.entries) {
      await book(
        companyId: companyId,
        articleId: articleId,
        delta: -entry.value,
        type: type,
        binKey: entry.key,
        referenceLabel: referenceLabel,
        note: note,
      );
    }
  }

  /// Zugang ohne ausdrücklichen Platz: Standardplatz des Artikels, sonst
  /// „nicht zugeordnet“.
  Future<String> defaultReceiptBin({required String companyId, required String articleId}) async {
    final article = await (_db.select(_db.articles)..where((a) => a.id.equals(articleId))).getSingleOrNull();
    final binId = article?.defaultBinId;
    if (binId == null) return unassignedBinKey;
    final bin = await (_db.select(_db.storageBins)
          ..where((b) => b.id.equals(binId) & b.companyId.equals(companyId)))
        .getSingleOrNull();
    return bin == null ? unassignedBinKey : bin.id;
  }

  /// Kay (16.11.2026): „Bei Entnahme auch einen Lagerplatz vorschlagen,
  /// wenn einer hinterlegt ist.“ Vorschlag: Platz mit dem größten
  /// Bestand; ohne Platzbestand der Standardplatz; sonst „nicht
  /// zugeordnet“.
  Future<String> suggestWithdrawalBin({required String companyId, required String articleId}) async {
    final stocks = (await _rawStocks(articleId)).where((s) => s.binKey != unassignedBinKey && s.quantity > 0).toList()
      ..sort((a, b) => b.quantity.compareTo(a.quantity));
    if (stocks.isNotEmpty) return stocks.first.binKey;
    return defaultReceiptBin(companyId: companyId, articleId: articleId);
  }

  /// Umlagerung von [quantity] zwischen zwei Plätzen — Gesamtbestand
  /// bleibt gleich, zwei Bewegungen vom Typ `transfer`.
  Future<void> transfer({
    required String companyId,
    required String articleId,
    required String fromBinKey,
    required String toBinKey,
    required double quantity,
    String? note,
  }) async {
    if (quantity <= 0 || fromBinKey == toBinKey) return;
    await _db.transaction(() async {
      await book(
        companyId: companyId,
        articleId: articleId,
        delta: -quantity,
        type: StockMovementType.transfer,
        binKey: fromBinKey,
        referenceLabel: 'Umlagerung',
        note: note,
      );
      await book(
        companyId: companyId,
        articleId: articleId,
        delta: quantity,
        type: StockMovementType.transfer,
        binKey: toBinKey,
        referenceLabel: 'Umlagerung',
        note: note,
      );
    });
  }

  Future<List<ArticleBinStock>> _rawStocks(String articleId) =>
      (_db.select(_db.articleBinStocks)..where((s) => s.articleId.equals(articleId))).get();

  /// Platzbestände eines Artikels mit Bezeichnung, sortiert nach Lagerort
  /// und Laufreihenfolge; „nicht zugeordnet“ zuletzt. Leere Plätze
  /// werden weggelassen, außer dem Standardplatz.
  Future<List<BinStock>> stocksFor({required String companyId, required String articleId}) async {
    final rows = await _rawStocks(articleId);
    final bins = await binsWithLocation(companyId);
    final article = await (_db.select(_db.articles)..where((a) => a.id.equals(articleId))).getSingleOrNull();
    final result = <BinStock>[];
    for (final entry in bins) {
      final qty = rows.where((r) => r.binKey == entry.bin.id).firstOrNull?.quantity;
      if ((qty == null || qty == 0) && article?.defaultBinId != entry.bin.id) continue;
      result.add(BinStock(binKey: entry.bin.id, quantity: qty ?? 0, bin: entry.bin, locationName: entry.location.name));
    }
    final unassigned = rows.where((r) => r.binKey == unassignedBinKey).firstOrNull;
    if (unassigned != null && unassigned.quantity != 0) {
      result.add(BinStock(binKey: unassignedBinKey, quantity: unassigned.quantity));
    }
    return result;
  }

  /// Alle Plätze der Firma mit Lagerort, in Laufreihenfolge (Lagerort,
  /// dann Platz-Sortierung, dann Reihe → Regal → Fach).
  Future<List<({StorageLocation location, StorageBin bin})>> binsWithLocation(String companyId) async {
    final locations = await (_db.select(_db.storageLocations)
          ..where((l) => l.companyId.equals(companyId))
          ..orderBy([(l) => OrderingTerm.asc(l.sortOrder), (l) => OrderingTerm.asc(l.name)]))
        .get();
    final bins = await (_db.select(_db.storageBins)..where((b) => b.companyId.equals(companyId))).get();
    final result = <({StorageLocation location, StorageBin bin})>[];
    for (final location in locations) {
      final own = bins.where((b) => b.locationId == location.id).toList()..sort(compareBinsInWalkOrder);
      for (final bin in own) {
        result.add((location: location, bin: bin));
      }
    }
    return result;
  }
}

/// Laufreihenfolge der Inventur: explizite Sortierung, dann Reihe →
/// Regal → Fach (Zahlen numerisch, sonst alphabetisch).
int compareBinsInWalkOrder(StorageBin a, StorageBin b) {
  final bySort = a.sortOrder.compareTo(b.sortOrder);
  if (bySort != 0) return bySort;
  for (final (x, y) in [(a.row, b.row), (a.shelf, b.shelf), (a.compartment, b.compartment)]) {
    final c = _naturalCompare(x, y);
    if (c != 0) return c;
  }
  return 0;
}

int _naturalCompare(String a, String b) {
  final na = int.tryParse(a.trim());
  final nb = int.tryParse(b.trim());
  if (na != null && nb != null) return na.compareTo(nb);
  return a.trim().toLowerCase().compareTo(b.trim().toLowerCase());
}
