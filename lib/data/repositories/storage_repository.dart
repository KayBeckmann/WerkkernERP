import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';
import 'stock_ledger.dart';

/// Ein Platz darf nicht gelöscht werden, solange dort Bestand liegt.
class StorageBinInUseException implements Exception {
  const StorageBinInUseException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// C5.4-Nachtrag (Kay, 16.11.2026): Lagerorte (frei benannt) und Plätze
/// darin (Reihe → Regal → Fach). Bestände selbst bucht nur `StockLedger`.
class StorageRepository {
  StorageRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  Future<List<StorageLocation>> locations(String companyId) => (_db.select(_db.storageLocations)
        ..where((l) => l.companyId.equals(companyId))
        ..orderBy([(l) => OrderingTerm.asc(l.sortOrder), (l) => OrderingTerm.asc(l.name)]))
      .get();

  Future<List<StorageBin>> binsOf({required String companyId, required String locationId}) async {
    final bins = await (_db.select(_db.storageBins)
          ..where((b) => b.companyId.equals(companyId) & b.locationId.equals(locationId)))
        .get();
    return bins..sort(compareBinsInWalkOrder);
  }

  Future<StorageLocation> createLocation({required String companyId, required String name}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Lagerort braucht einen Namen.');
    final existing = await locations(companyId);
    final id = _uuid.v4();
    await _db.into(_db.storageLocations).insert(StorageLocationsCompanion.insert(
          id: id,
          companyId: companyId,
          name: trimmed,
          sortOrder: Value(existing.length),
          createdAt: DateTime.now(),
        ));
    return (await (_db.select(_db.storageLocations)..where((l) => l.id.equals(id))).getSingle());
  }

  Future<void> renameLocation({required String companyId, required String id, required String name}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Lagerort braucht einen Namen.');
    await (_db.update(_db.storageLocations)..where((l) => l.id.equals(id) & l.companyId.equals(companyId)))
        .write(StorageLocationsCompanion(name: Value(trimmed)));
  }

  /// Löscht einen Lagerort samt Plätzen — nur, wenn an keinem Platz
  /// Bestand liegt. Standardplätze von Artikeln werden gelöst.
  Future<void> deleteLocation({required String companyId, required String id}) async {
    await _db.transaction(() async {
      final bins = await binsOf(companyId: companyId, locationId: id);
      for (final bin in bins) {
        await _assertBinEmpty(bin);
      }
      for (final bin in bins) {
        await _releaseBin(companyId, bin.id);
      }
      await (_db.delete(_db.storageBins)..where((b) => b.locationId.equals(id) & b.companyId.equals(companyId))).go();
      await (_db.delete(_db.storageLocations)..where((l) => l.id.equals(id) & l.companyId.equals(companyId))).go();
    });
  }

  Future<StorageBin> saveBin({
    required String companyId,
    required String locationId,
    String? id,
    required String row,
    required String shelf,
    required String compartment,
    int? sortOrder,
  }) async {
    if (row.trim().isEmpty && shelf.trim().isEmpty && compartment.trim().isEmpty) {
      throw ArgumentError('Mindestens Reihe, Regal oder Fach angeben.');
    }
    final location = await (_db.select(_db.storageLocations)
          ..where((l) => l.id.equals(locationId) & l.companyId.equals(companyId)))
        .getSingleOrNull();
    if (location == null) throw ArgumentError('Lagerort unbekannt.');
    final binId = id ?? _uuid.v4();
    if (id == null) {
      await _db.into(_db.storageBins).insert(StorageBinsCompanion.insert(
            id: binId,
            companyId: companyId,
            locationId: locationId,
            row: Value(row.trim()),
            shelf: Value(shelf.trim()),
            compartment: Value(compartment.trim()),
            sortOrder: Value(sortOrder ?? 0),
          ));
    } else {
      await (_db.update(_db.storageBins)..where((b) => b.id.equals(id) & b.companyId.equals(companyId))).write(
        StorageBinsCompanion(
          locationId: Value(locationId),
          row: Value(row.trim()),
          shelf: Value(shelf.trim()),
          compartment: Value(compartment.trim()),
          sortOrder: sortOrder == null ? const Value.absent() : Value(sortOrder),
        ),
      );
    }
    return (await (_db.select(_db.storageBins)..where((b) => b.id.equals(binId))).getSingle());
  }

  Future<void> deleteBin({required String companyId, required String id}) async {
    await _db.transaction(() async {
      final bin = await (_db.select(_db.storageBins)..where((b) => b.id.equals(id) & b.companyId.equals(companyId)))
          .getSingleOrNull();
      if (bin == null) return;
      await _assertBinEmpty(bin);
      await _releaseBin(companyId, id);
      await (_db.delete(_db.storageBins)..where((b) => b.id.equals(id))).go();
    });
  }

  Future<void> _assertBinEmpty(StorageBin bin) async {
    final rows = await (_db.select(_db.articleBinStocks)..where((s) => s.binKey.equals(bin.id))).get();
    if (rows.any((r) => r.quantity != 0)) {
      throw StorageBinInUseException(
        'An ${storageBinLabel(bin)} liegt noch Bestand — erst umlagern oder per Inventur ausbuchen.',
      );
    }
  }

  Future<void> _releaseBin(String companyId, String binId) async {
    await (_db.delete(_db.articleBinStocks)..where((s) => s.binKey.equals(binId))).go();
    await (_db.update(_db.articles)..where((a) => a.companyId.equals(companyId) & a.defaultBinId.equals(binId)))
        .write(const ArticlesCompanion(defaultBinId: Value(null)));
  }

  Future<void> setDefaultBin({required String companyId, required String articleId, String? binId}) async {
    await (_db.update(_db.articles)..where((a) => a.id.equals(articleId) & a.companyId.equals(companyId)))
        .write(ArticlesCompanion(defaultBinId: Value(binId)));
  }

  /// Artikel-IDs mit Bestand oder Standardplatz in [locationId] — für
  /// den Filter der Artikelliste.
  Future<Set<String>> articleIdsAtLocation({required String companyId, required String locationId}) async {
    final bins = (await binsOf(companyId: companyId, locationId: locationId)).map((b) => b.id).toSet();
    if (bins.isEmpty) return {};
    final stocks = await (_db.select(_db.articleBinStocks)
          ..where((s) => s.companyId.equals(companyId) & s.binKey.isIn(bins) & s.quantity.isNotValue(0)))
        .get();
    final defaults = await (_db.select(_db.articles)
          ..where((a) => a.companyId.equals(companyId) & a.defaultBinId.isIn(bins)))
        .get();
    return {...stocks.map((s) => s.articleId), ...defaults.map((a) => a.id)};
  }

  /// Artikel mit Bestand „Platz noch nicht zugeordnet“ (Klärfälle).
  Future<Set<String>> articleIdsUnassigned(String companyId) async {
    final rows = await (_db.select(_db.articleBinStocks)
          ..where((s) => s.companyId.equals(companyId) & s.binKey.equals(unassignedBinKey) & s.quantity.isNotValue(0)))
        .get();
    return rows.map((r) => r.articleId).toSet();
  }
}
