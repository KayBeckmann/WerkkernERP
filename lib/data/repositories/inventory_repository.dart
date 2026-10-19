import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';
import '../database/tables.dart';

/// Inventur und das dauerhafte Bewegungsprotokoll (C5.3, Nachtrag
/// 2026-10-19: "Wir müssen auch Inventur vorsehen und ich möchte die
/// Mengen anpassen können. Das muss alles dokumentiert werden"). Eine
/// Inventur zählt beliebig viele Artikel in EINEM Durchgang (Kay-
/// Entscheidung auf Rückfrage: "Volle Inventur-Sitzung") und bucht beim
/// Abschließen alle tatsächlichen Abweichungen gemeinsam — jede davon
/// erzeugt eine unveränderliche [StockMovements]-Zeile.
class InventoryRepository {
  InventoryRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  Future<List<InventoryCount>> listForCompany(String companyId) =>
      (_db.select(_db.inventoryCounts)
            ..where((c) => c.companyId.equals(companyId))
            ..orderBy([(c) => OrderingTerm.desc(c.date)]))
          .get();

  Future<InventoryCount?> findById({required String companyId, required String id}) =>
      (_db.select(_db.inventoryCounts)
            ..where((c) => c.id.equals(id) & c.companyId.equals(companyId)))
          .getSingleOrNull();

  Future<List<InventoryCountItem>> itemsFor(String inventoryCountId) =>
      (_db.select(_db.inventoryCountItems)
            ..where((i) => i.inventoryCountId.equals(inventoryCountId)))
          .get();

  /// Legt einen neuen Inventur-Lauf an — leer, Status `draft`. Artikel
  /// werden danach über [addArticles] hinzugefügt.
  Future<InventoryCount> startCount({
    required String companyId,
    required String label,
    DateTime? date,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    await _db.into(_db.inventoryCounts).insert(
          InventoryCountsCompanion.insert(
            id: id,
            companyId: companyId,
            label: label,
            date: date ?? now,
            createdAt: now,
          ),
        );
    return (await findById(companyId: companyId, id: id))!;
  }

  /// Fügt Artikel zum Lauf hinzu — der aktuelle Lagerbestand wird dabei
  /// als [InventoryCountItems.expectedQuantity] eingefroren (Soll-Wert,
  /// siehe Klassendoc dort). Bereits enthaltene Artikel werden
  /// übersprungen statt doppelt eingefügt (der `uniqueKeys`-Constraint
  /// auf der Tabelle würde das ohnehin verhindern).
  Future<void> addArticles({
    required String companyId,
    required String inventoryCountId,
    required List<String> articleIds,
  }) async {
    final existing = await itemsFor(inventoryCountId);
    final existingArticleIds = existing.map((i) => i.articleId).toSet();
    for (final articleId in articleIds) {
      if (existingArticleIds.contains(articleId)) continue;
      final article =
          await (_db.select(_db.articles)..where((a) => a.id.equals(articleId))).getSingleOrNull();
      if (article == null || article.companyId != companyId) continue;
      await _db.into(_db.inventoryCountItems).insert(
            InventoryCountItemsCompanion.insert(
              id: _uuid.v4(),
              inventoryCountId: inventoryCountId,
              articleId: articleId,
              expectedQuantity: article.stockQuantity,
            ),
          );
    }
  }

  Future<void> removeItem({required String inventoryCountId, required String itemId}) =>
      (_db.delete(_db.inventoryCountItems)
            ..where((i) => i.id.equals(itemId) & i.inventoryCountId.equals(inventoryCountId)))
          .go();

  Future<void> setCountedQuantity({
    required String itemId,
    required double countedQuantity,
  }) =>
      (_db.update(_db.inventoryCountItems)..where((i) => i.id.equals(itemId))).write(
        InventoryCountItemsCompanion(
          countedQuantity: Value(countedQuantity),
          countedAt: Value(DateTime.now()),
        ),
      );

  /// Schließt den Lauf ab: jede Position mit eingetragener Zählmenge UND
  /// einer tatsächlichen Abweichung bucht den Lagerbestand auf die
  /// gezählte Menge (absolut) und erzeugt eine [StockMovements]-Zeile
  /// (Typ `inventoryCorrection`, Referenz = [InventoryCount.label]).
  /// Danach unveränderlich (F3-Prinzip). `null`, wenn der Lauf nicht
  /// existiert oder bereits abgeschlossen ist.
  Future<InventoryCount?> complete({required String companyId, required String id}) async {
    return _db.transaction(() async {
      final count = await findById(companyId: companyId, id: id);
      if (count == null || count.status != InventoryCountStatus.draft) return null;

      final items = await itemsFor(id);
      final now = DateTime.now();
      for (final item in items) {
        if (item.countedQuantity == null) continue;
        final delta = item.countedQuantity! - item.expectedQuantity;
        if (delta == 0) continue;

        await (_db.update(_db.articles)..where((a) => a.id.equals(item.articleId)))
            .write(ArticlesCompanion(stockQuantity: Value(item.countedQuantity!)));
        await _db.into(_db.stockMovements).insert(
              StockMovementsCompanion.insert(
                id: _uuid.v4(),
                companyId: companyId,
                articleId: item.articleId,
                type: StockMovementType.inventoryCorrection,
                quantityDelta: delta,
                resultingQuantity: item.countedQuantity!,
                referenceLabel: Value(count.label),
                createdAt: now,
              ),
            );
      }

      await (_db.update(_db.inventoryCounts)..where((c) => c.id.equals(id))).write(
        InventoryCountsCompanion(
          status: const Value(InventoryCountStatus.completed),
          completedAt: Value(now),
        ),
      );
      return findById(companyId: companyId, id: id);
    });
  }

  /// Bequemlichkeits-Methode für die bisherige Einzelartikel-
  /// Bestandskorrektur in `ArticleDetailScreen` — erzeugt, befüllt und
  /// schließt einen Inventur-Lauf mit genau EINEM Artikel in einem
  /// Aufruf, damit auch eine einzelne Korrektur immer dokumentiert
  /// bleibt (Kay: "Das muss alles dokumentiert werden"). [reason] ist
  /// hier bewusst **Pflicht** (anders als die alte, grundlose
  /// `ArticleRepository.setStock()`-UI) — er wird als [InventoryCount.
  /// label] und damit als Referenz der erzeugten [StockMovements]-Zeile
  /// gespeichert.
  Future<Article?> correctSingleArticleStock({
    required String companyId,
    required String articleId,
    required double newQuantity,
    required String reason,
  }) async {
    return _db.transaction(() async {
      final count = await startCount(companyId: companyId, label: reason);
      await addArticles(companyId: companyId, inventoryCountId: count.id, articleIds: [articleId]);
      final item = (await itemsFor(count.id)).singleOrNull;
      if (item == null) return null;
      await setCountedQuantity(itemId: item.id, countedQuantity: newQuantity);
      await complete(companyId: companyId, id: count.id);
      return (_db.select(_db.articles)..where((a) => a.id.equals(articleId))).getSingleOrNull();
    });
  }

  /// Bewegungsprotokoll eines einzelnen Artikels, neueste zuerst — für
  /// die "Bewegungen"-Ansicht in `ArticleDetailScreen`.
  Future<List<StockMovement>> movementsForArticle({
    required String companyId,
    required String articleId,
  }) =>
      (_db.select(_db.stockMovements)
            ..where((m) => m.companyId.equals(companyId) & m.articleId.equals(articleId))
            ..orderBy([(m) => OrderingTerm.desc(m.createdAt)]))
          .get();
}
